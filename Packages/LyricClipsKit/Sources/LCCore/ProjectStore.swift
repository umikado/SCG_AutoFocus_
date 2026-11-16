import Foundation
import Crypto

/// Serial access to one app-owned Projects directory. Use one instance per root.
/// Rejects symbolic links; callers must not mutate the directory behind the store.
public actor ProjectStore {
    private let root: URL
    private let beforePublish: @Sendable (URL) throws -> Void

    /// Creates a store under Application Support, or a trusted caller-supplied root.
    public init(root: URL? = nil) throws {
        self.root = try Self.prepareRoot(root)
        self.beforePublish = { _ in }
    }

    // Fault injection at the stage/publication boundary, for interrupted-write tests.
    init(root: URL, beforePublish: @escaping @Sendable (URL) throws -> Void) throws {
        self.root = try Self.prepareRoot(root)
        self.beforePublish = beforePublish
    }

    /// Copies an authorized source file while hashing the exact copied bytes.
    /// Duration/sample rate must come from the Apple audio decoder, not file size.
    public func importAudio(
        from source: URL, projectID: UUID, duration: Double, sampleRate: Double,
        hasEmbeddedArtwork: Bool = false
    ) throws -> AudioSource {
        _ = try AudioSource(relativePath: "audio.bin", contentSHA256: String(repeating: "0", count: 64),
                            duration: duration, sampleRate: sampleRate, originalFilename: source.lastPathComponent)
        try Self.requireRegularFile(source)
        // This explicitly authorized external source may live under an OS directory alias.
        // Its final component must be a regular file; stored project paths reject all links.
        let canonicalSource = source.resolvingSymlinksInPath().standardizedFileURL
        let directory = try projectDirectory(projectID, create: true)
        let suffix = source.pathExtension.lowercased()
        let ext = !suffix.isEmpty && suffix.count <= 10 && suffix.utf8.allSatisfy {
            (48...57).contains($0) || (97...122).contains($0)
        } ? suffix : "bin"
        let filename = "audio-\(UUID().uuidString).\(ext)"
        let destination = try checked("\(projectID.uuidString)/\(filename)")
        let temporary = directory.appendingPathComponent(".audio-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else {
            throw LCError.invalidValue("audio.create")
        }
        let input = try FileHandle(forReadingFrom: canonicalSource)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: temporary)
        defer { try? output.close() }
        var hash = SHA256()
        var byteCount = 0
        while let bytes = try input.read(upToCount: 1_048_576), !bytes.isEmpty {
            try Task.checkCancellation()
            hash.update(data: bytes)
            try output.write(contentsOf: bytes)
            byteCount += bytes.count
        }
        try require(byteCount > 0, "audio.empty")
        try output.synchronize()
        try output.close()
        try Task.checkCancellation()
        _ = try checked("\(projectID.uuidString)/\(filename)")
        try FileManager.default.moveItem(at: temporary, to: destination)
        return try AudioSource(relativePath: filename, contentSHA256: Self.hex(hash.finalize()),
                               duration: duration, sampleRate: sampleRate, originalFilename: source.lastPathComponent,
                               hasEmbeddedArtwork: hasEmbeddedArtwork)
    }

    /// Publishes project.json atomically. A partial staging file is never a recovery source.
    public func save(_ project: Project) throws {
        let directory = try projectDirectory(project.id)
        try validateResources(project)
        let target = try checked("\(project.id.uuidString)/project.json")
        if FileManager.default.fileExists(atPath: target.path) { try Self.requireRegularFile(target) }
        let data = try ProjectMigrator.encode(project)
        let staged = directory.appendingPathComponent(".project-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: staged) }
        try data.write(to: staged, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: staged)
        try handle.synchronize()
        try handle.close()
        try beforePublish(staged)
        try Task.checkCancellation()
        _ = try checked("\(project.id.uuidString)/project.json")
        // Foundation performs same-directory temporary-file publication via atomic replacement.
        // Keep the explicit staging boundary for failure injection; JSON is small, unlike audio.
        try data.write(to: target, options: .atomic)
    }

    /// Loads only the committed JSON, verifies identity, paths, and imported audio bytes.
    public func load(_ id: UUID) throws -> Project {
        let url = try checked("\(id.uuidString)/project.json")
        try Self.requireRegularFile(url)
        let project = try ProjectMigrator.decode(Data(contentsOf: url))
        try require(project.id == id, "project.id")
        try validateResources(project)
        return project
    }

    /// Lists committed project IDs. Imports without committed metadata remain unpublished.
    public func list() throws -> [UUID] {
        try validateRoot()
        var result: [UUID] = []
        for entry in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: entry.lastPathComponent) else { continue }
            _ = try projectDirectory(id)
            let metadata = try checked("\(id.uuidString)/project.json")
            if FileManager.default.fileExists(atPath: metadata.path) {
                _ = try load(id)
                result.append(id)
            }
        }
        return result.sorted { $0.uuidString < $1.uuidString }
    }

    /// Resolves a validated imported audio file for the Apple playback/decoder layer.
    public func audioURL(for id: UUID) throws -> URL {
        let project = try load(id)
        return try checked("\(id.uuidString)/\(project.audio.relativePath)")
    }

    /// Deletes one project, rejecting links anywhere in its directory tree.
    public func delete(_ id: UUID) throws {
        let directory = try projectDirectory(id)
        try auditTree(directory)
        try FileManager.default.removeItem(at: directory)
    }

    private static func prepareRoot(_ requested: URL?) throws -> URL {
        let manager = FileManager.default
        let location: URL
        if let requested {
            try require(requested.isFileURL, "root")
            location = requested.standardizedFileURL
        } else {
            location = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
                .appendingPathComponent("SCGLyricClips/Projects", isDirectory: true)
        }
        if let attrs = try attributes(location) {
            try require(attrs[.type] as? FileAttributeType == .typeDirectory, "root.symlink")
        } else {
            try manager.createDirectory(at: location, withIntermediateDirectories: true)
        }
        // Canonicalize trusted OS aliases (e.g. /var -> /private/var on Apple platforms).
        let canonical = location.resolvingSymlinksInPath().standardizedFileURL
        try excludeFromBackup(canonical)
        return canonical
    }

    private func validateRoot() throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: root.path)
        try require(attrs[.type] as? FileAttributeType == .typeDirectory
                    && root.resolvingSymlinksInPath().standardizedFileURL.path == root.path, "root.symlink")
    }

    private func projectDirectory(_ id: UUID, create: Bool = false) throws -> URL {
        let directory = try checked(id.uuidString)
        if let attrs = try Self.attributes(directory) {
            try require(attrs[.type] as? FileAttributeType == .typeDirectory, "project.directory")
        } else if create {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        } else {
            throw LCError.invalidValue("project.missing")
        }
        try Self.excludeFromBackup(directory)
        return directory
    }

    private func checked(_ relative: String) throws -> URL {
        try relativePath(relative)
        try validateRoot()
        let candidate = root.appendingPathComponent(relative).standardizedFileURL
        try require(candidate.pathComponents.starts(with: root.pathComponents)
                    && candidate.pathComponents.count > root.pathComponents.count, "path.containment")
        var current = root
        let components = relative.split(separator: "/")
        for (index, component) in components.enumerated() {
            current.appendPathComponent(String(component))
            if let attrs = try Self.attributes(current) {
                let type = attrs[.type] as? FileAttributeType
                try require(type != .typeSymbolicLink, "path.symlink")
                if index < components.count - 1 { try require(type == .typeDirectory, "path.parent") }
            }
        }
        return candidate
    }

    private func validateResources(_ project: Project) throws {
        let file = try checked("\(project.id.uuidString)/\(project.audio.relativePath)")
        try Self.requireRegularFile(file)
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var hash = SHA256()
        while let bytes = try input.read(upToCount: 1_048_576), !bytes.isEmpty {
            try Task.checkCancellation()
            hash.update(data: bytes)
        }
        try require(Self.hex(hash.finalize()) == project.audio.contentSHA256.lowercased(), "audio.hash")
        if let background = project.templateOverrides?.customBackgroundRelativePath {
            try Self.requireRegularFile(checked("\(project.id.uuidString)/\(background)"))
        }
    }

    private func auditTree(_ directory: URL) throws {
        for child in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let attrs = try FileManager.default.attributesOfItem(atPath: child.path)
            let type = attrs[.type] as? FileAttributeType
            try require(type != .typeSymbolicLink, "path.symlink")
            if type == .typeDirectory { try auditTree(child) }
        }
    }

    private static func attributes(_ url: URL) throws -> [FileAttributeKey: Any]? {
        do { return try FileManager.default.attributesOfItem(atPath: url.path) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        }
    }

    private static func requireRegularFile(_ url: URL) throws {
        try require(url.isFileURL, "file.url")
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        try require(attrs[.type] as? FileAttributeType == .typeRegular, "file.type")
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func excludeFromBackup(_ url: URL) throws {
        #if !os(Linux)
        var value = url
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try value.setResourceValues(resources)
        #endif
    }
}

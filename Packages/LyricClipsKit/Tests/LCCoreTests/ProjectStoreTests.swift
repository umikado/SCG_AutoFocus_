import Foundation
import XCTest
@testable import LCCore

@MainActor
final class ProjectStoreTests: XCTestCase {
    private func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func project(_ audio: AudioSource, id: UUID, title: String = "Synthetic") throws -> Project {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "project-v1", withExtension: "json", subdirectory: "Fixtures"))
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        object["id"] = id.uuidString
        object["title"] = title
        object["audio"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(audio))
        return try ProjectMigrator.decode(JSONSerialization.data(withJSONObject: object))
    }

    private func importFixture(_ store: ProjectStore, root: URL, id: UUID) async throws -> AudioSource {
        let source = root.appendingPathComponent("source.wav")
        try Data("abc".utf8).write(to: source)
        return try await store.importAudio(from: source, projectID: id, duration: 60, sampleRate: 44100)
    }

    func testImportCRUDAndHash() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try ProjectStore(root: dir.appendingPathComponent("Projects"))
        let id = UUID()
        let audio = try await importFixture(store, root: dir, id: id)
        XCTAssertEqual(audio.contentSHA256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let pending = try await store.list(); XCTAssertTrue(pending.isEmpty)
        let first = try project(audio, id: id)
        try await store.save(first)
        let loaded = try await store.load(id); XCTAssertEqual(first, loaded)
        let second = try project(audio, id: id, title: "Updated")
        try await store.save(second)
        let reopened = try ProjectStore(root: dir.appendingPathComponent("Projects"))
        let updated = try await reopened.load(id); XCTAssertEqual(updated.title, "Updated")
        let ids = try await reopened.list(); XCTAssertEqual(ids, [id])
        let audioURL = try await reopened.audioURL(for: id)
        XCTAssertEqual(try Data(contentsOf: audioURL), Data("abc".utf8))
        try await reopened.delete(id)
        let empty = try await reopened.list(); XCTAssertEqual(empty, [])
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("source.wav")), Data("abc".utf8))
    }

    func testInterruptedPublicationKeepsOldProject() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let root = dir.appendingPathComponent("Projects")
        let store = try ProjectStore(root: root); let id = UUID()
        let audio = try await importFixture(store, root: dir, id: id)
        let first = try project(audio, id: id); try await store.save(first)
        let failing = try ProjectStore(root: root, beforePublish: { _ in throw LCError.invalidValue("injected-interruption") })
        do { try await failing.save(project(audio, id: id, title: "Interrupted")); XCTFail("Expected injected failure") } catch {}
        // A process killed after staging can leave an incomplete file; it must never be promoted on reopen.
        let orphan = root.appendingPathComponent(id.uuidString).appendingPathComponent(".project-crash.tmp")
        try Data("{partial".utf8).write(to: orphan)
        let reopened = try ProjectStore(root: root)
        let loaded = try await reopened.load(id); XCTAssertEqual(loaded, first)
        try await reopened.save(project(audio, id: id, title: "Recovered"))
        let recovered = try await reopened.load(id); XCTAssertEqual(recovered.title, "Recovered")
    }

    func testRejectsSymlinkedRootAndProjectDirectory() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let outside = dir.appendingPathComponent("Outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertThrowsError(try ProjectStore(root: link))
        let root = dir.appendingPathComponent("Projects"); let store = try ProjectStore(root: root)
        let id = UUID(); let projectLink = root.appendingPathComponent(id.uuidString)
        try FileManager.default.createSymbolicLink(at: projectLink, withDestinationURL: outside)
        do { _ = try await store.load(id); XCTFail("Followed directory symlink") } catch {}
        do { try await store.delete(id); XCTFail("Deleted through directory symlink") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testRejectsAudioAndJSONSymlinksAndCorruptAudio() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let root = dir.appendingPathComponent("Projects"); let store = try ProjectStore(root: root); let id = UUID()
        let audio = try await importFixture(store, root: dir, id: id)
        let value = try project(audio, id: id); try await store.save(value)
        let file = root.appendingPathComponent(id.uuidString).appendingPathComponent(audio.relativePath)
        try Data("changed".utf8).write(to: file)
        do { _ = try await store.load(id); XCTFail("Accepted hash mismatch") } catch {}
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: dir.appendingPathComponent("source.wav"))
        do { _ = try await store.audioURL(for: id); XCTFail("Followed audio symlink") } catch {}
        let json = root.appendingPathComponent(id.uuidString).appendingPathComponent("project.json")
        let outside = dir.appendingPathComponent("outside.json"); try ProjectMigrator.encode(value).write(to: outside)
        try FileManager.default.removeItem(at: json)
        try FileManager.default.createSymbolicLink(at: json, withDestinationURL: outside)
        do { try await store.save(value); XCTFail("Replaced symlinked metadata") } catch {}
        XCTAssertEqual(try Data(contentsOf: outside), try ProjectMigrator.encode(value))
    }

    func testRejectsNestedSymlinkAndMetadataIDMismatch() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let root = dir.appendingPathComponent("Projects"); let store = try ProjectStore(root: root); let id = UUID()
        let audio = try await importFixture(store, root: dir, id: id)
        let value = try project(audio, id: id); try await store.save(value)
        let folder = root.appendingPathComponent(id.uuidString)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("nested"), withDestinationURL: dir)
        let linked = try AudioSource(relativePath: "nested/source.wav", contentSHA256: audio.contentSHA256, duration: 60, sampleRate: 44100, originalFilename: "source.wav")
        do { try await store.save(project(linked, id: id)); XCTFail("Followed intermediate symlink") } catch {}
        try ProjectMigrator.encode(project(audio, id: UUID())).write(to: folder.appendingPathComponent("project.json"))
        do { _ = try await store.load(id); XCTFail("Accepted mismatched ID") } catch {}
    }

    func testAuthorizedSourceViaParentAlias() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let real = dir.appendingPathComponent("Real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try Data("abc".utf8).write(to: real.appendingPathComponent("source.wav"))
        let alias = dir.appendingPathComponent("Alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let store = try ProjectStore(root: dir.appendingPathComponent("Projects"))
        let audio = try await store.importAudio(from: alias.appendingPathComponent("source.wav"), projectID: UUID(), duration: 60, sampleRate: 44100)
        XCTAssertEqual(audio.contentSHA256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testShortImportAndExternalSourceSymlinkFailWithoutPublication() async throws {
        let dir = try workspace(); defer { try? FileManager.default.removeItem(at: dir) }
        let root = dir.appendingPathComponent("Projects"); let store = try ProjectStore(root: root)
        let source = dir.appendingPathComponent("source.wav"); try Data("abc".utf8).write(to: source)
        do { _ = try await store.importAudio(from: source, projectID: UUID(), duration: 14.9, sampleRate: 44100); XCTFail("Accepted short audio") } catch {}
        let link = dir.appendingPathComponent("source-link.wav")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        do { _ = try await store.importAudio(from: link, projectID: UUID(), duration: 60, sampleRate: 44100); XCTFail("Followed external symlink") } catch {}
        let ids = try await store.list(); XCTAssertTrue(ids.isEmpty)
    }
}

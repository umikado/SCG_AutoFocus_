import Foundation

/// Schema-aware JSON entry point. No historical schemas exist yet.
public enum ProjectMigrator {
    private struct Envelope: Decodable { let schemaVersion: Int }

    /// Rejects unsupported versions before decoding the complete validated graph.
    public static func decode(_ data: Data) throws -> Project {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let version = try decoder.decode(Envelope.self, from: data).schemaVersion
        guard version == Project.schemaVersion else { throw LCError.unsupportedSchema(version) }
        return try decoder.decode(Project.self, from: data)
    }

    /// Writes deterministic sorted-key JSON with the specification's ISO-8601 dates.
    public static func encode(_ project: Project) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(project)
    }
}

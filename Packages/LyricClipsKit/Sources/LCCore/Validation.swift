import Foundation

/// Stable validation failures for pure core models.
public enum LCError: Error, Equatable, Sendable, LocalizedError {
    /// A field violates the schema contract.
    case invalidValue(String)
    /// No migration is defined for the supplied schema.
    case unsupportedSchema(Int)

    /// Machine-readable error code; UI localization can use this key.
    public var code: String {
        switch self {
        case .invalidValue: "invalidValue"
        case .unsupportedSchema: "unsupportedSchema"
        }
    }

    /// Diagnostic description, independent of product UI localization.
    public var errorDescription: String? {
        switch self {
        case .invalidValue(let field): "Invalid value for \(field)."
        case .unsupportedSchema(let version): "Unsupported project schema: \(version)."
        }
    }
}

func require(_ condition: Bool, _ field: String) throws {
    guard condition else { throw LCError.invalidValue(field) }
}

func seconds(_ value: Double, _ field: String) throws {
    try require(value.isFinite && value >= 0, field)
}

func probability(_ value: Double, _ field: String) throws {
    try require(value.isFinite && (0...1).contains(value), field)
}

// Lexical validation only. ProjectStore must separately enforce filesystem containment.
func relativePath(_ value: String) throws {
    let parts = value.split(separator: "/", omittingEmptySubsequences: false)
    try require(!value.isEmpty && !value.contains("\\") && !value.contains(":")
        && !value.contains("\0") && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }, "relativePath")
}

func characterOffsets(in text: String) -> Set<Int> {
    var result: Set<Int> = [0]
    var offset = 0
    for character in text {
        offset += String(character).utf16.count
        result.insert(offset)
    }
    return result
}

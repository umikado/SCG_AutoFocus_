import Foundation

/// TimeRange value, validated on construction and decoding.
public struct TimeRange: Codable, Hashable, Sendable {
    /// Finite nonnegative original-song seconds.
    public let start: Double
    /// Exclusive end, strictly after start.
    public let end: Double

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        start: Double,
        end: Double
    ) throws {
        try seconds(start, "start")
        try seconds(end, "end")
        try require(end > start, "end")
        self.start = start
        self.end = end
    }

    private enum CodingKeys: String, CodingKey {
        case start, end
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            start: container.decode(Double.self, forKey: .start),
            end: container.decode(Double.self, forKey: .end)
        )
    }

    /// Duration in seconds.
    public var duration: Double { end - start }
}

import Foundation

/// Segment value, validated on construction and decoding.
public struct Segment: Codable, Hashable, Sendable {
    /// Selected original-song interval, 15–60 seconds.
    public let range: TimeRange
    /// Analysis padding, from zero through five seconds.
    public let padding: Double

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        range: TimeRange,
        padding: Double = 1.0
    ) throws {
        try require((15...60).contains(range.duration), "segment.duration")
        try require(padding.isFinite && (0...5).contains(padding), "padding")
        self.range = range
        self.padding = padding
    }

    private enum CodingKeys: String, CodingKey {
        case range, padding
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            range: container.decode(TimeRange.self, forKey: .range),
            padding: container.decode(Double.self, forKey: .padding)
        )
    }

    /// Actual beginning of the decoded analysis interval.
    public var decodedStart: Double { max(0, range.start - padding) }

    /// Clamps analysis padding to a validated audio duration.
    public func decodedEnd(audioDuration: Double) throws -> Double {
        try seconds(audioDuration, "audioDuration")
        try require(audioDuration >= range.end, "segment.range")
        return min(audioDuration, range.end + padding)
    }
}

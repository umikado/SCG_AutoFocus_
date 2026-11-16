import Foundation

/// WordTiming value, validated on construction and decoding.
public struct WordTiming: Codable, Hashable, Sendable {
    /// Word text.
    public let text: String
    /// Nonempty UTF-16 range within the parent lyric line.
    public let range: Range<Int>
    /// Absolute original-song start seconds.
    public let start: Double
    /// Exclusive absolute end seconds.
    public let end: Double
    /// Optional reading used in alignment.
    public let reading: String?

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        text: String,
        range: Range<Int>,
        start: Double,
        end: Double,
        reading: String? = nil
    ) throws {
        _ = try TimeRange(start: start, end: end)
        try require(range.lowerBound >= 0 && !range.isEmpty, "word.range")
        self.text = text
        self.range = range
        self.start = start
        self.end = end
        self.reading = reading
    }

    private enum CodingKeys: String, CodingKey {
        case text, range, start, end, reading
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            text: container.decode(String.self, forKey: .text),
            range: container.decode(Range<Int>.self, forKey: .range),
            start: container.decode(Double.self, forKey: .start),
            end: container.decode(Double.self, forKey: .end),
            reading: container.decodeIfPresent(String.self, forKey: .reading)
        )
    }
}

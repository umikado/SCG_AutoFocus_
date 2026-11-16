import Foundation

/// LyricLine value, validated on construction and decoding.
public struct LyricLine: Codable, Hashable, Sendable, Identifiable {
    /// Persistent line identity.
    public let id: UUID
    /// Nonnegative original lyric order.
    public let index: Int
    /// Paragraph index preserving original blank-line breaks.
    public let paragraphIndex: Int
    /// Current editable display text.
    public let text: String
    /// Reserved optional translated text.
    public let translation: String?
    /// Optional finite absolute start seconds.
    public let start: Double?
    /// Optional finite absolute end seconds.
    public let end: Double?
    /// Heuristic score in 0...1, not a probability.
    public let confidence: Double
    /// Origin of this timing.
    public let source: TimingSource
    /// Word timings with ranges into this line text.
    public let words: [WordTiming]
    /// Whether this line belongs to the selected candidate.
    public let isInSegment: Bool

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        id: UUID = UUID(),
        index: Int,
        paragraphIndex: Int,
        text: String,
        translation: String? = nil,
        start: Double? = nil,
        end: Double? = nil,
        confidence: Double = 0,
        source: TimingSource = .auto,
        words: [WordTiming] = [],
        isInSegment: Bool = false
    ) throws {
        try require(index >= 0 && paragraphIndex >= 0, "line.index")
        if let start { try seconds(start, "line.start") }
        if let end { try seconds(end, "line.end") }
        if let start, let end { _ = try TimeRange(start: start, end: end) }
        try probability(confidence, "confidence")
        if source == .manual || source == .tapSync { try require(confidence == 1, "locked.confidence") }
        let boundaries = characterOffsets(in: text)
        for word in words {
            try require(boundaries.contains(word.range.lowerBound) && boundaries.contains(word.range.upperBound), "word.range")
        }
        self.id = id
        self.index = index
        self.paragraphIndex = paragraphIndex
        self.text = text
        self.translation = translation
        self.start = start
        self.end = end
        self.confidence = confidence
        self.source = source
        self.words = words
        self.isInSegment = isInSegment
    }

    private enum CodingKeys: String, CodingKey {
        case id, index, paragraphIndex, text, translation, start, end, confidence, source, words, isInSegment
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            index: container.decode(Int.self, forKey: .index),
            paragraphIndex: container.decode(Int.self, forKey: .paragraphIndex),
            text: container.decode(String.self, forKey: .text),
            translation: container.decodeIfPresent(String.self, forKey: .translation),
            start: container.decodeIfPresent(Double.self, forKey: .start),
            end: container.decodeIfPresent(Double.self, forKey: .end),
            confidence: container.decode(Double.self, forKey: .confidence),
            source: container.decode(TimingSource.self, forKey: .source),
            words: container.decode([WordTiming].self, forKey: .words),
            isInSegment: container.decode(Bool.self, forKey: .isInSegment)
        )
    }

    /// Manual and tap timings are hard anchors during realignment.
    public var isLocked: Bool { source == .manual || source == .tapSync }
}

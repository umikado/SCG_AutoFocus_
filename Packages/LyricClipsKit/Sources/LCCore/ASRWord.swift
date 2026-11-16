import Foundation

/// ASRWord value, validated on construction and decoding.
public struct ASRWord: Codable, Hashable, Sendable {
    /// Reassembled Unicode word text.
    public let text: String
    /// Absolute seconds, with decodedStart already applied once.
    public let start: Double
    /// Exclusive absolute end seconds.
    public let end: Double
    /// Finite model score in 0...1.
    public let prob: Float
    /// Whether the end was inferred from point timestamps.
    public let isEndEstimated: Bool

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        text: String,
        start: Double,
        end: Double,
        prob: Float,
        isEndEstimated: Bool
    ) throws {
        _ = try TimeRange(start: start, end: end)
        try probability(Double(prob), "prob")
        self.text = text
        self.start = start
        self.end = end
        self.prob = prob
        self.isEndEstimated = isEndEstimated
    }

    private enum CodingKeys: String, CodingKey {
        case text, start, end, prob, isEndEstimated
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            text: container.decode(String.self, forKey: .text),
            start: container.decode(Double.self, forKey: .start),
            end: container.decode(Double.self, forKey: .end),
            prob: container.decode(Float.self, forKey: .prob),
            isEndEstimated: container.decode(Bool.self, forKey: .isEndEstimated)
        )
    }
}

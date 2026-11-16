import Foundation

/// ExportSettings value, validated on construction and decoding.
public struct ExportSettings: Codable, Hashable, Sendable {
    /// Supported export video codecs.
    public enum Codec: String, Codable, Hashable, Sendable {
        /// H.264 default.
        case h264
        /// Optional HEVC.
        case hevc
    }

    /// Requested codec.
    public let codec: Codec
    /// Supported frame rate: 30 or 60.
    public let fps: Int
    /// Optional end card, off by default.
    public let includeEndCard: Bool
    /// Use clip-relative LRC timestamps.
    public let lrcRelativeToSegment: Bool

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        codec: Codec = .h264,
        fps: Int = 30,
        includeEndCard: Bool = false,
        lrcRelativeToSegment: Bool = true
    ) throws {
        try require(fps == 30 || fps == 60, "fps")
        self.codec = codec
        self.fps = fps
        self.includeEndCard = includeEndCard
        self.lrcRelativeToSegment = lrcRelativeToSegment
    }

    private enum CodingKeys: String, CodingKey {
        case codec, fps, includeEndCard, lrcRelativeToSegment
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            codec: container.decode(Codec.self, forKey: .codec),
            fps: container.decode(Int.self, forKey: .fps),
            includeEndCard: container.decode(Bool.self, forKey: .includeEndCard),
            lrcRelativeToSegment: container.decode(Bool.self, forKey: .lrcRelativeToSegment)
        )
    }
}

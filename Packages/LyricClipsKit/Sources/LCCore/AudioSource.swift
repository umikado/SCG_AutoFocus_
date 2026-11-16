import Foundation

/// AudioSource value, validated on construction and decoding.
public struct AudioSource: Codable, Hashable, Sendable {
    /// Sandbox-relative audio path; no traversal components.
    public let relativePath: String
    /// 64 hexadecimal digits identifying imported bytes.
    public let contentSHA256: String
    /// Positive finite audio duration in seconds.
    public let duration: Double
    /// Positive finite source sample rate in Hz.
    public let sampleRate: Double
    /// Original name for local display only.
    public let originalFilename: String
    /// Whether import found embedded cover artwork.
    public let hasEmbeddedArtwork: Bool

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        relativePath: String,
        contentSHA256: String,
        duration: Double,
        sampleRate: Double,
        originalFilename: String,
        hasEmbeddedArtwork: Bool = false
    ) throws {
        try LCCore.relativePath(relativePath)
        try require(contentSHA256.utf8.count == 64 && contentSHA256.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }, "contentSHA256")
        try require(duration.isFinite && duration > 0, "audio.duration")
        try require(sampleRate.isFinite && sampleRate > 0, "sampleRate")
        self.relativePath = relativePath
        self.contentSHA256 = contentSHA256
        self.duration = duration
        self.sampleRate = sampleRate
        self.originalFilename = originalFilename
        self.hasEmbeddedArtwork = hasEmbeddedArtwork
    }

    private enum CodingKeys: String, CodingKey {
        case relativePath, contentSHA256, duration, sampleRate, originalFilename, hasEmbeddedArtwork
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            relativePath: container.decode(String.self, forKey: .relativePath),
            contentSHA256: container.decode(String.self, forKey: .contentSHA256),
            duration: container.decode(Double.self, forKey: .duration),
            sampleRate: container.decode(Double.self, forKey: .sampleRate),
            originalFilename: container.decode(String.self, forKey: .originalFilename),
            hasEmbeddedArtwork: container.decode(Bool.self, forKey: .hasEmbeddedArtwork)
        )
    }
}

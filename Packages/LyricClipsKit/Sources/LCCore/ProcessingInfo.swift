import Foundation

/// ProcessingInfo value, validated on construction and decoding.
public struct ProcessingInfo: Codable, Hashable, Sendable {
    /// Separation engine used.
    public let separationEngineID: String
    /// Transcription engine used.
    public let transcriptionEngineID: String
    /// Whisper model identifier.
    public let whisperModelID: String
    /// Actual backend observation, not requested configuration.
    public let usedCoreMLEncoder: Bool
    /// Whether usable DTW was observed.
    public let usedDTWTimestamps: Bool
    /// Finite nonnegative elapsed processing seconds.
    public let durationSeconds: Double
    /// Heuristic alignment score in 0...1.
    public let overallConfidence: Double

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        separationEngineID: String,
        transcriptionEngineID: String,
        whisperModelID: String,
        usedCoreMLEncoder: Bool,
        usedDTWTimestamps: Bool,
        durationSeconds: Double,
        overallConfidence: Double
    ) throws {
        try seconds(durationSeconds, "durationSeconds")
        try probability(overallConfidence, "overallConfidence")
        self.separationEngineID = separationEngineID
        self.transcriptionEngineID = transcriptionEngineID
        self.whisperModelID = whisperModelID
        self.usedCoreMLEncoder = usedCoreMLEncoder
        self.usedDTWTimestamps = usedDTWTimestamps
        self.durationSeconds = durationSeconds
        self.overallConfidence = overallConfidence
    }

    private enum CodingKeys: String, CodingKey {
        case separationEngineID, transcriptionEngineID, whisperModelID, usedCoreMLEncoder, usedDTWTimestamps, durationSeconds, overallConfidence
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            separationEngineID: container.decode(String.self, forKey: .separationEngineID),
            transcriptionEngineID: container.decode(String.self, forKey: .transcriptionEngineID),
            whisperModelID: container.decode(String.self, forKey: .whisperModelID),
            usedCoreMLEncoder: container.decode(Bool.self, forKey: .usedCoreMLEncoder),
            usedDTWTimestamps: container.decode(Bool.self, forKey: .usedDTWTimestamps),
            durationSeconds: container.decode(Double.self, forKey: .durationSeconds),
            overallConfidence: container.decode(Double.self, forKey: .overallConfidence)
        )
    }
}

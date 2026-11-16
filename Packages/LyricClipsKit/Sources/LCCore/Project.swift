import Foundation

/// Project value, validated on construction and decoding.
public struct Project: Codable, Hashable, Sendable, Identifiable {
    /// Persistent schema version, currently 1.
    public let schemaVersion: Int
    /// Persistent project identity.
    public let id: UUID
    /// Creation time, serialized as ISO-8601.
    public let createdAt: Date
    /// Last edit time.
    public let updatedAt: Date
    /// Local project title.
    public let title: String
    /// Optional local artist label.
    public let artist: String?
    /// Imported audio metadata.
    public let audio: AudioSource
    /// Display/reading language.
    public let language: LyricLanguage
    /// Actual recognition language, explicit for mixed lyrics.
    public let primaryASRLanguage: ASRLanguage
    /// Original lyrics including blank lines.
    public let rawLyrics: String
    /// Current editable lyric snapshots.
    public let lines: [LyricLine]
    /// Selected interval within audio duration.
    public let segment: Segment
    /// Selected template identifier.
    public let templateID: String
    /// Optional persisted user styling choices.
    public let templateOverrides: TemplateOverrides?
    /// Persisted export choices.
    public let exportSettings: ExportSettings
    /// Optional observed processing summary.
    public let processing: ProcessingInfo?

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        schemaVersion: Int = Project.schemaVersion,
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        title: String,
        artist: String? = nil,
        audio: AudioSource,
        language: LyricLanguage,
        primaryASRLanguage: ASRLanguage,
        rawLyrics: String,
        lines: [LyricLine],
        segment: Segment,
        templateID: String,
        templateOverrides: TemplateOverrides? = nil,
        exportSettings: ExportSettings,
        processing: ProcessingInfo? = nil
    ) throws {
        guard schemaVersion == Self.schemaVersion else { throw LCError.unsupportedSchema(schemaVersion) }
        try require(createdAt.timeIntervalSince1970.isFinite && updatedAt.timeIntervalSince1970.isFinite && updatedAt >= createdAt, "project.dates")
        try require(segment.range.end <= audio.duration, "segment.range")
        let expected: ASRLanguage?
        switch language {
        case .zhHans, .zhHant: expected = .zh
        case .ja: expected = .ja
        case .en: expected = .en
        case .mixed: expected = nil
        }
        if let expected { try require(primaryASRLanguage == expected, "primaryASRLanguage") }
        try require(Set(lines.map(\.id)).count == lines.count, "line.id")
        try require(zip(lines, lines.dropFirst()).allSatisfy { $0.index < $1.index }, "line.index")
        try require(zip(lines, lines.dropFirst()).allSatisfy {
            $0.paragraphIndex <= $1.paragraphIndex
        }, "line.paragraphIndex")
        for line in lines {
            if let start = line.start { try require(start <= audio.duration, "line.start") }
            if let end = line.end { try require(end <= audio.duration, "line.end") }
            try require(line.words.allSatisfy { $0.end <= audio.duration }, "word.end")
        }
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.artist = artist
        self.audio = audio
        self.language = language
        self.primaryASRLanguage = primaryASRLanguage
        self.rawLyrics = rawLyrics
        self.lines = lines
        self.segment = segment
        self.templateID = templateID
        self.templateOverrides = templateOverrides
        self.exportSettings = exportSettings
        self.processing = processing
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, createdAt, updatedAt, title, artist, audio, language, primaryASRLanguage, rawLyrics, lines, segment, templateID, templateOverrides, exportSettings, processing
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(UUID.self, forKey: .id),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            updatedAt: container.decode(Date.self, forKey: .updatedAt),
            title: container.decode(String.self, forKey: .title),
            artist: container.decodeIfPresent(String.self, forKey: .artist),
            audio: container.decode(AudioSource.self, forKey: .audio),
            language: container.decode(LyricLanguage.self, forKey: .language),
            primaryASRLanguage: container.decode(ASRLanguage.self, forKey: .primaryASRLanguage),
            rawLyrics: container.decode(String.self, forKey: .rawLyrics),
            lines: container.decode([LyricLine].self, forKey: .lines),
            segment: container.decode(Segment.self, forKey: .segment),
            templateID: container.decode(String.self, forKey: .templateID),
            templateOverrides: container.decodeIfPresent(TemplateOverrides.self, forKey: .templateOverrides),
            exportSettings: container.decode(ExportSettings.self, forKey: .exportSettings),
            processing: container.decodeIfPresent(ProcessingInfo.self, forKey: .processing)
        )
    }

    /// The only on-disk schema supported by this initial release.
    public static let schemaVersion = 1
}

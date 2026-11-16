/// Product lyric language, including a user-directed mixed mode.
public enum LyricLanguage: String, Codable, Hashable, Sendable {
    /// Simplified Chinese display text.
    case zhHans = "zh-Hans"
    /// Traditional Chinese display text.
    case zhHant = "zh-Hant"
    /// Japanese display text.
    case ja
    /// English display text.
    case en
    /// Multiple languages; primary ASR language is stored separately.
    case mixed
}

/// Actual model language; defined in Core to avoid an Apple dependency cycle.
public enum ASRLanguage: String, Codable, Hashable, Sendable {
    /// Chinese, independent of display script.
    case zh
    /// Japanese recognition.
    case ja
    /// English recognition.
    case en
}

/// Provenance of the current line timing.
public enum TimingSource: String, Codable, Hashable, Sendable {
    /// Automatic alignment.
    case auto
    /// Bounded interpolation between anchors.
    case interpolated
    /// Manual timing, protected against realignment.
    case manual
    /// Tap timing, protected against realignment.
    case tapSync
}

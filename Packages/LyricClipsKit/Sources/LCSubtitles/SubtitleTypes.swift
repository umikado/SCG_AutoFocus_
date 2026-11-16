import Foundation
import LCCore

/// One timed subtitle in seconds. SRT text may contain nonempty multiple lines.
public struct SubtitleCue: Hashable, Sendable {
    /// Inclusive cue start in the caller's time basis.
    public let start: Double
    /// Exclusive cue end in the same time basis.
    public let end: Double
    /// Unstyled Unicode text.
    public let text: String

    /// Rejects nonfinite, negative or empty time ranges.
    public init(start: Double, end: Double, text: String) throws {
        _ = try TimeRange(start: start, end: end)
        self.start = start
        self.end = end
        self.text = text
    }
}

/// One LRC event; an empty text is a clear-screen marker, not an omitted line.
public struct LRCEntry: Hashable, Sendable {
    /// Nonnegative normalized seconds after any input offset has been applied.
    public let time: Double
    /// Single-line lyric text, or empty for clear-screen.
    public let text: String

    /// Constructs a representable LRC event.
    public init(time: Double, text: String) throws {
        try check(time.isFinite && time >= 0, "lrc.time")
        try check(!text.contains("\n") && !text.contains("\r"), "lrc.text")
        self.time = time
        self.text = text
    }
}

/// Normalized LRC metadata/events. Input offsets are consumed, not retained as metadata.
public struct LRCDocument: Equatable, Sendable {
    /// Plain metadata tags such as ti/ar/by, without offset.
    public let metadata: [String: String]
    /// Events; codecs stably sort equal timestamps without discarding clear-screen events.
    public let entries: [LRCEntry]

    /// Creates a document; metadata syntax is validated when encoding.
    public init(metadata: [String: String] = [:], entries: [LRCEntry]) {
        self.metadata = metadata
        self.entries = entries
    }
}

/// Output LRC timestamp precision. App exports use centiseconds.
public enum LRCPrecision: Sendable {
    /// Two fractional digits.
    case centiseconds
    /// Three fractional digits, useful for lossless normalization of parsed millisecond LRC.
    case milliseconds

    var scale: Int { self == .centiseconds ? 100 : 1000 }
}

func check(_ condition: Bool, _ field: String) throws {
    if !condition { throw LCError.invalidValue(field) }
}

func normalizedNewlines(_ text: String) -> String {
    var result = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    if result.first == "\u{FEFF}" { result.removeFirst() }
    return result
}

func decimal(_ value: Double) -> Decimal {
    Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX"))!
}

// Decimal rounding makes documented decimal ties such as 59.995 seconds deterministic.
func ticks(_ value: Double, scale: Int, floor: Bool = false) throws -> Int {
    try check(value.isFinite && value >= 0, "timestamp")
    guard var number = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) else {
        throw LCError.invalidValue("timestamp.overflow")
    }
    number *= Decimal(scale)
    var rounded = Decimal()
    NSDecimalRound(&rounded, &number, 0, floor ? .down : .plain)
    let result = NSDecimalNumber(decimal: rounded)
    try check(result.doubleValue.isFinite && result.doubleValue >= 0 && result.doubleValue < Double(Int.max), "timestamp.overflow")
    return result.intValue
}

func difference(_ a: Double, _ b: Double) -> Double {
    NSDecimalNumber(decimal: decimal(a) - decimal(b)).doubleValue
}

func padded(_ value: Int, _ length: Int) -> String {
    let text = String(value)
    return String(repeating: "0", count: max(0, length - text.count)) + text
}

func unsigned(_ text: String) -> Int? {
    guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
    return Int(text)
}

func sortedCues(_ cues: [SubtitleCue]) -> [SubtitleCue] {
    cues.enumerated().sorted { a, b in
        a.element.start == b.element.start ? a.offset < b.offset : a.element.start < b.element.start
    }.map(\.element)
}

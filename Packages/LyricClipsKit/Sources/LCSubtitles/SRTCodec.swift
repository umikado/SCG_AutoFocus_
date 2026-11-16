import Foundation
import LCCore

/// Strict UTF-8 text SRT codec, supporting BOM, LF/CRLF and multiline cues.
public enum SRTCodec {
    /// Parses positive cue numbers and millisecond HH:MM:SS,mmm timestamps.
    public static func decode(_ text: String) throws -> [SubtitleCue] {
        let lines = normalizedNewlines(text).components(separatedBy: "\n")
        var blocks: [[String]] = []
        var current: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { blocks.append(current); current = [] }
            } else { current.append(line) }
        }
        if !current.isEmpty { blocks.append(current) }
        return try blocks.map { block in
            try check(block.count >= 3, "srt.block")
            let index = unsigned(block[0].trimmingCharacters(in: .whitespaces))
            try check((index ?? 0) > 0, "srt.index")
            let times = block[1].components(separatedBy: "-->")
            try check(times.count == 2, "srt.timing")
            return try SubtitleCue(start: parseTime(times[0]), end: parseTime(times[1]),
                                   text: block.dropFirst(2).joined(separator: "\n"))
        }
    }

    /// Encodes sorted cues with consecutive numbering and LF. Rejects sub-ms empty ranges.
    public static func encode(_ cues: [SubtitleCue]) throws -> String {
        try sortedCues(cues).enumerated().map { index, cue in
            let start = try ticks(cue.start, scale: 1000)
            let end = try ticks(cue.end, scale: 1000)
            try check(end > start, "srt.quantizedRange")
            let text = normalizedNewlines(cue.text)
            try check(!text.components(separatedBy: "\n").contains {
                $0.trimmingCharacters(in: .whitespaces).isEmpty
            }, "srt.text")
            return "\(index + 1)\n\(format(start)) --> \(format(end))\n\(text)\n\n"
        }.joined()
    }

    private static func parseTime(_ text: String) throws -> Double {
        let parts = text.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
        try check(parts.count == 3, "srt.timestamp")
        let seconds = parts[2].components(separatedBy: ",")
        guard parts[0].count >= 2, parts[1].count == 2, seconds.count == 2,
              seconds[0].count == 2, seconds[1].count == 3,
              let h = unsigned(parts[0]), let m = unsigned(parts[1]), m < 60,
              let s = unsigned(seconds[0]), s < 60, let ms = unsigned(seconds[1]) else {
            throw LCError.invalidValue("srt.timestamp")
        }
        return NSDecimalNumber(decimal: Decimal(h) * 3600 + Decimal(m) * 60 + Decimal(s) + Decimal(ms) / 1000).doubleValue
    }

    private static func format(_ ms: Int) -> String {
        "\(padded(ms / 3_600_000, 2)):\(padded(ms / 60_000 % 60, 2)):\(padded(ms / 1000 % 60, 2)),\(padded(ms % 1000, 3))"
    }
}

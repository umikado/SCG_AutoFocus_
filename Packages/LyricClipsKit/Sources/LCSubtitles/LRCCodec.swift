import Foundation
import LCCore

/// LRC codec with metadata, multi-time tags, empty events and global offset normalization.
public enum LRCCodec {
    /// A positive offset delays lyrics; negative adjusted times clamp to zero.
    /// The last offset tag applies to the whole document, even when placed after lyrics.
    public static func decode(_ text: String) throws -> LRCDocument {
        var metadata: [String: String] = [:]
        var raw: [(Double, String)] = []
        var offset = 0
        for original in normalizedNewlines(text).components(separatedBy: "\n") {
            if original.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            var line = original
            try check(line.first == "[", "lrc.line")
            guard let closing = line.firstIndex(of: "]") else { throw LCError.invalidValue("lrc.tag") }
            let firstTag = String(line[line.index(after: line.startIndex)..<closing])
            if parseTime(firstTag) == nil {
                let pair = firstTag.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                try check(pair.count == 2 && line.index(after: closing) == line.endIndex, "lrc.metadata")
                let key = String(pair[0]).lowercased()
                try validateKey(key)
                let value = String(pair[1])
                if key == "offset" {
                    guard let parsed = Int(value) else { throw LCError.invalidValue("lrc.offset") }
                    offset = parsed
                } else { metadata[key] = value }
                continue
            }
            var times: [Double] = []
            while line.first == "[", let end = line.firstIndex(of: "]") {
                let tag = String(line[line.index(after: line.startIndex)..<end])
                guard let time = parseTime(tag) else { break }
                times.append(time)
                line = String(line[line.index(after: end)...])
            }
            for time in times { raw.append((time, line)) }
        }
        let entries = try raw.map { time, text in
            let adjusted = NSDecimalNumber(decimal: decimal(time) + Decimal(offset) / 1000).doubleValue
            return try LRCEntry(time: max(0, adjusted), text: text)
        }
        return LRCDocument(metadata: metadata, entries: stableSort(entries))
    }

    /// Emits normalized metadata and sorted events without an offset tag; output has LF and no BOM.
    public static func encode(_ document: LRCDocument, precision: LRCPrecision = .centiseconds) throws -> String {
        let preferred = ["ti", "ar", "by"]
        let keys = preferred.filter { document.metadata[$0] != nil }
            + document.metadata.keys.filter { !preferred.contains($0) }.sorted()
        var output = ""
        for key in keys {
            try validateKey(key)
            try check(key != "offset", "lrc.offsetAlreadyNormalized")
            let value = document.metadata[key]!
            try check(!value.contains("]") && !value.contains("\n") && !value.contains("\r"), "lrc.metadata")
            output += "[\(key):\(value)]\n"
        }
        let scale = precision.scale
        for entry in stableSort(document.entries) {
            if entry.text.first == "[", let closing = entry.text.firstIndex(of: "]") {
                let prefix = String(entry.text[entry.text.index(after: entry.text.startIndex)..<closing])
                // LRC has no escape for a literal leading time tag: reject rather than add an event.
                try check(parseTime(prefix) == nil, "lrc.ambiguousText")
            }
            let time = try ticks(entry.time, scale: scale)
            output += "[\(padded(time / (60 * scale), 2)):\(padded(time / scale % 60, 2)).\(padded(time % scale, scale == 100 ? 2 : 3))]\(entry.text)\n"
        }
        return output
    }

    private static func validateKey(_ key: String) throws {
        try check(!key.isEmpty && key.utf8.allSatisfy { (97...122).contains($0) }, "lrc.metadataKey")
    }

    private static func parseTime(_ text: String) -> Double? {
        let parts = text.components(separatedBy: ":")
        guard parts.count == 2, parts[0].count >= 2, let m = unsigned(parts[0]) else { return nil }
        let seconds = parts[1].components(separatedBy: ".")
        guard (1...2).contains(seconds.count), seconds[0].count == 2,
              let s = unsigned(seconds[0]), s < 60 else { return nil }
        var fraction: Decimal = 0
        if seconds.count == 2 {
            guard [2, 3].contains(seconds[1].count), let f = unsigned(seconds[1]) else { return nil }
            fraction = Decimal(f) / (seconds[1].count == 2 ? 100 : 1000)
        }
        return NSDecimalNumber(decimal: Decimal(m) * 60 + Decimal(s) + fraction).doubleValue
    }

    private static func stableSort(_ entries: [LRCEntry]) -> [LRCEntry] {
        entries.enumerated().sorted { a, b in
            a.element.time == b.element.time ? a.offset < b.offset : a.element.time < b.element.time
        }.map(\.element)
    }
}

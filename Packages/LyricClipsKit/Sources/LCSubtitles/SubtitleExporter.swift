import Foundation
import LCCore

/// Clip-aware subtitle export: intersect, translate, then quantize.
public enum SubtitleExporter {
    /// Exports clip-relative SRT, dropping unrepresentable fragments and bounding every cue.
    public static func srt(lines: [LyricLine], segment: Segment) throws -> String {
        let cues = try clipped(lines: lines, segment: segment)
        // Floor the real duration so no millisecond endpoint extends beyond the physical clip.
        let limit = try ticks(segment.range.duration, scale: 1000, floor: true)
        let starts = try cues.map { try ticks(difference($0.start, segment.range.start), scale: 1000) }
        var result: [SubtitleCue] = []
        for (index, cue) in cues.enumerated() {
            let start = starts[index]
            guard start < limit else { continue }
            let upper = min(limit, index + 1 < starts.count ? starts[index + 1] : limit)
            var end = min(try ticks(difference(cue.end, segment.range.start), scale: 1000), upper)
            if end == start && start + 1 <= upper { end = start + 1 }
            guard end > start else { continue }
            result.append(try SubtitleCue(start: Double(start) / 1000, end: Double(end) / 1000, text: cue.text))
        }
        return try SRTCodec.encode(result)
    }

    /// Exports centisecond LRC with gap/tail clear-screen markers and optional original-song times.
    public static func lrc(
        lines: [LyricLine], segment: Segment, title: String, artist: String? = nil,
        relativeToSegment: Bool = true
    ) throws -> String {
        let cues = try clipped(lines: lines, segment: segment)
        let offset = relativeToSegment ? segment.range.start : 0
        let limit = try ticks(difference(segment.range.end, offset), scale: 100, floor: true)
        var visible: [(cue: SubtitleCue, start: Int, end: Int)] = []
        for cue in cues {
            let start = try ticks(difference(cue.start, offset), scale: 100)
            let end = min(try ticks(difference(cue.end, offset), scale: 100), limit)
            guard start < limit && end > start else { continue }
            // At a shared output timestamp the last lyric wins; the parser still preserves duplicates.
            if visible.last?.start == start { visible.removeLast() }
            visible.append((cue, start, end))
        }
        var entries: [LRCEntry] = []
        for (index, item) in visible.enumerated() {
            let (cue, start, rawEnd) = item
            let next = index + 1 < visible.count ? visible[index + 1].start : limit
            let end = min(rawEnd, next)
            entries.append(try LRCEntry(time: Double(start) / 100, text: cue.text))
            let gap = index + 1 < visible.count ? difference(visible[index + 1].cue.start, cue.end) > 0.10 : cue.end < segment.range.end
            if gap && end < next {
                entries.append(try LRCEntry(time: Double(end) / 100, text: ""))
            }
        }
        var metadata = ["ti": title, "by": "SCG LyricClips"]
        if let artist { metadata["ar"] = artist }
        return try LRCCodec.encode(LRCDocument(metadata: metadata, entries: entries), precision: .centiseconds)
    }

    // Resolve absent ends before intersection. Outside/untimed/empty/invalid fallback lines are skipped.
    private static func clipped(lines: [LyricLine], segment: Segment) throws -> [SubtitleCue] {
        let timed = lines.enumerated().filter {
            $0.element.start != nil && !$0.element.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.sorted { a, b in
            a.element.start == b.element.start ? a.offset < b.offset : a.element.start! < b.element.start!
        }.map(\.element)
        var cues: [SubtitleCue] = []
        for (index, line) in timed.enumerated() {
            let start = line.start!
            let next = index + 1 < timed.count ? timed[index + 1].start! - 0.05 : segment.range.end
            let rawEnd = line.end ?? min(next, start + 5, segment.range.end)
            let lower = max(start, segment.range.start)
            let upper = min(rawEnd, segment.range.end)
            if upper > lower { cues.append(try SubtitleCue(start: lower, end: upper, text: line.text)) }
        }
        return cues
    }
}

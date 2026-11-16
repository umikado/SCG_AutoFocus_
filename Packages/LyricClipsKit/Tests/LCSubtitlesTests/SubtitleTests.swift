import Foundation
import XCTest
import LCCore
@testable import LCSubtitles

final class SubtitleTests: XCTestCase {
    private func line(_ index: Int, _ start: Double?, _ end: Double?, _ text: String = "Original") throws -> LyricLine {
        try LyricLine(index: index, paragraphIndex: 0, text: text, start: start, end: end)
    }
    private func segment(_ start: Double = 0, _ duration: Double = 15) throws -> Segment {
        try Segment(range: TimeRange(start: start, end: start + duration))
    }
    private func golden(_ name: String, ext: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testSRTGoldenClipsBeforeTranslation() throws {
        let lines = try [line(0, 29.8, 31, "Original dawn"), line(1, 32, 34, "原创の lyric"), line(2, 61, 62)]
        let output = try SubtitleExporter.srt(lines: lines, segment: segment(30, 30))
        XCTAssertEqual(output, try golden("clip", ext: "srt"))
        let cues = try SRTCodec.decode(output)
        XCTAssertEqual(cues.map(\.start), [0, 2])
        XCTAssertEqual(cues.map(\.end), [1, 4])
    }

    func testClipsRightBoundaryAndOmitsUntimedOrOutside() throws {
        let lines = try [line(0, 1, 2), line(1, nil, nil), line(2, 44, 47), line(3, 46, 47)]
        let cues = try SRTCodec.decode(SubtitleExporter.srt(lines: lines, segment: segment(30)))
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues.first?.start, 14)
        XCTAssertEqual(cues.first?.end, 15)
    }

    func testSRTDropsUnrepresentableFinalSliver() throws {
        XCTAssertEqual(try SubtitleExporter.srt(lines: [line(0, 14.9996, 15)], segment: segment()), "")
        let cues = try SRTCodec.decode(SubtitleExporter.srt(lines: [line(0, 1.0001, 1.0002)], segment: segment()))
        XCTAssertEqual(cues.first?.start, 1)
        XCTAssertEqual(cues.first?.end, 1.001)
    }

    func testSRTExpansionCannotCrossNextCueOrClip() throws {
        let lines = try [line(0, 1.0001, 1.0002, "Discard"), line(1, 1.0003, 2, "Keep")]
        let cues = try SRTCodec.decode(SubtitleExporter.srt(lines: lines, segment: segment()))
        XCTAssertEqual(cues.map(\.text), ["Keep"])
        XCTAssertEqual(cues.first?.start, 1)
        let overlapping = try [line(0, 0, 3), line(1, 2, 4)]
        let clipped = try SRTCodec.decode(SubtitleExporter.srt(lines: overlapping, segment: segment()))
        XCTAssertEqual(clipped[0].end, clipped[1].start)
    }

    func testSRTQuantizationInvariantSweep() throws {
        for offset in [0.0, 0.0001, 0.00049, 0.0005, 0.0009] {
            let selection = try segment(30, 15 + offset)
            let lines = try [line(0, 30, 30.0002), line(1, 31.0001, 31.0002), line(2, 31.0003, 32), line(3, selection.range.end - 0.0001, selection.range.end)]
            let cues = try SRTCodec.decode(SubtitleExporter.srt(lines: lines, segment: selection))
            for cue in cues {
                XCTAssertGreaterThan(cue.end, cue.start)
                XCTAssertGreaterThanOrEqual(cue.start, 0)
                XCTAssertLessThanOrEqual(cue.end, selection.range.duration)
            }
            for (a, b) in zip(cues, cues.dropFirst()) { XCTAssertLessThanOrEqual(a.end, b.start) }
        }
    }

    func testMissingEndsAndVeryCloseNextStart() throws {
        let lines = try [line(0, 1, nil), line(1, 3, nil), line(2, 14, nil)]
        let cues = try SRTCodec.decode(SubtitleExporter.srt(lines: lines, segment: segment()))
        XCTAssertEqual(cues.map(\.end), [2.95, 8, 15])
        let tooClose = try [line(0, 1, nil), line(1, 1.01, 2)]
        let result = try SRTCodec.decode(SubtitleExporter.srt(lines: tooClose, segment: segment()))
        XCTAssertEqual(result.count, 1)
    }

    func testSRTMinuteHourCarryAndCRLFMultiline() throws {
        let cues = try [SubtitleCue(start: 59.9996, end: 61, text: "First\nSecond"), SubtitleCue(start: 3600, end: 3601, text: "Long")]
        let output = try SRTCodec.encode(cues)
        XCTAssertTrue(output.contains("00:01:00,000 --> 00:01:01,000"))
        XCTAssertTrue(output.contains("01:00:00,000 --> 01:00:01,000"))
        let parsed = try SRTCodec.decode("\u{FEFF}" + output.replacingOccurrences(of: "\n", with: "\r\n"))
        XCTAssertEqual(parsed[0].text, "First\nSecond")
        XCTAssertEqual(try SRTCodec.encode(parsed), output)
    }

    func testSRTRejectsMalformedInputAndNonfiniteTimes() throws {
        for input in ["1\n00:00:01,000 --> 00:00:00,000\nx", "1\n00:60:00,000 --> 00:61:00,000\nx", "1\n00:00:00,000 --> 00:00:01,000", "bad", "1\n-1:00:00,000 --> 00:00:01,000\nx"] {
            XCTAssertThrowsError(try SRTCodec.decode(input))
        }
        XCTAssertThrowsError(try SubtitleCue(start: .nan, end: 1, text: "x"))
        XCTAssertThrowsError(try SRTCodec.encode([SubtitleCue(start: 1e100, end: 2e100, text: "x")]))
        XCTAssertThrowsError(try SRTCodec.encode([SubtitleCue(start: 1, end: 2, text: "a\n\nb")]))
    }

    func testLRCGoldenIncludesGapAndTailClear() throws {
        let lines = try [line(0, 29.8, 31, "Original dawn"), line(1, 32, 34, "原创の lyric")]
        let output = try SubtitleExporter.lrc(lines: lines, segment: segment(30, 30), title: "Synthetic", artist: "SCG")
        XCTAssertEqual(output, try golden("clip", ext: "lrc"))
        let parsed = try LRCCodec.decode(output)
        XCTAssertEqual(parsed.entries.map(\.time), [0, 1, 2, 4])
        XCTAssertEqual(parsed.entries.map(\.text), ["Original dawn", "", "原创の lyric", ""])
    }

    func testLRCMultiTagsOffsetAndMilliseconds() throws {
        let document = try LRCCodec.decode("\u{FEFF}[ti:Original]\r\n[00:01.123][00:02.45]Echo\r\n[00:03.000]\r\n[offset:+500]\r\n")
        XCTAssertEqual(document.metadata["ti"], "Original")
        XCTAssertEqual(document.entries.map(\.time), [1.623, 2.95, 3.5])
        XCTAssertEqual(document.entries.map(\.text), ["Echo", "Echo", ""])
        let encoded = try LRCCodec.encode(document, precision: .milliseconds)
        XCTAssertFalse(encoded.contains("offset:"))
        XCTAssertEqual(try LRCCodec.decode(encoded), document)
        let negative = try LRCCodec.decode("[offset:-1500]\n[00:01.00]Start\n[00:02.00]Next")
        XCTAssertEqual(negative.entries.map(\.time), [0, 0.5])
    }

    func testLRCCentisecondCarryAndAbsoluteMode() throws {
        let document = LRCDocument(entries: try [LRCEntry(time: 59.995, text: "Carry"), LRCEntry(time: 3600, text: "Hour")])
        let output = try LRCCodec.encode(document, precision: .centiseconds)
        XCTAssertTrue(output.contains("[01:00.00]Carry"))
        XCTAssertTrue(output.contains("[60:00.00]Hour"))
        let absolute = try SubtitleExporter.lrc(lines: [line(0, 3599.8, 3601)], segment: segment(3600), title: "Original", relativeToSegment: false)
        XCTAssertTrue(absolute.contains("[60:00.00]Original"))
        XCTAssertFalse(absolute.contains("[59:59"))
    }

    func testLRCDoesNotClearOnAdjacentOrRoundedNextStart() throws {
        let output = try SubtitleExporter.lrc(lines: [line(0, 1, 2), line(1, 2, 3)], segment: segment(), title: "Original")
        let entries = try LRCCodec.decode(output).entries
        XCTAssertFalse(entries.contains { $0.time == 2 && $0.text.isEmpty })
        XCTAssertEqual(entries.filter { $0.text.isEmpty }.map(\.time), [3])
    }

    func testLRCRejectsMalformedTagsAndMetadataInjection() throws {
        for input in ["[00:60.00]bad", "[offset:nan]\n[00:01.00]x", "[00:01.1234]bad", "[00:01.00", "un-timed text"] {
            XCTAssertThrowsError(try LRCCodec.decode(input))
        }
        XCTAssertThrowsError(try LRCEntry(time: .infinity, text: "x"))
        XCTAssertThrowsError(try LRCCodec.encode(LRCDocument(metadata: ["ti": "bad]\n[00:01.00]inject"], entries: [])))
        XCTAssertThrowsError(try LRCEntry(time: 1, text: "a\nb"))
    }

    func testLRCDroppedFragmentDoesNotSuppressTailClear() throws {
        for end in [2.0, 10.0] {
            let lines = try [line(0, 1, end, "Visible"), line(1, 2.0001, 2.0002, "Too short")]
            let output = try SubtitleExporter.lrc(lines: lines, segment: segment(), title: "Original")
            let entries = try LRCCodec.decode(output).entries
            XCTAssertEqual(entries.map(\.text), ["Visible", ""])
            XCTAssertEqual(entries.map(\.time), [1, end])
        }
    }

    func testLRCLiteralTimestampPrefixCannotBecomeExtraEvent() throws {
        let document = LRCDocument(entries: [try LRCEntry(time: 1, text: "[00:02.00]literal")])
        XCTAssertThrowsError(try LRCCodec.encode(document))
        let ordinary = LRCDocument(entries: [try LRCEntry(time: 1, text: "[Chorus] Original")])
        XCTAssertEqual(try LRCCodec.decode(LRCCodec.encode(ordinary)), ordinary)
    }

    func testEmptyDocumentsAndStableDuplicateTimestamps() throws {
        XCTAssertEqual(try SRTCodec.decode("\n\r\n"), [])
        XCTAssertEqual(try SRTCodec.encode([]), "")
        XCTAssertEqual(try LRCCodec.decode(""), LRCDocument(entries: []))
        let document = try LRCCodec.decode("[00:02.00]Second\n[00:01.00]A\n[00:01.00]B\n")
        XCTAssertEqual(document.entries.map(\.text), ["A", "B", "Second"])
        XCTAssertEqual(try LRCCodec.decode(LRCCodec.encode(document, precision: .centiseconds)), document)
    }
}

import Foundation
import XCTest
@testable import LCCore

final class ModelTests: XCTestCase {
    func testRejectsInvalidTimeRanges() throws {
        for value in [Double.nan, .infinity, -.infinity, -1] {
            XCTAssertThrowsError(try TimeRange(start: value, end: 20))
            XCTAssertThrowsError(try TimeRange(start: 0, end: value))
        }
        XCTAssertThrowsError(try TimeRange(start: 2, end: 2))
        XCTAssertThrowsError(try TimeRange(start: 3, end: 2))
        XCTAssertEqual(try TimeRange(start: 1, end: 2).duration, 1)
    }

    func testDecodingDoesNotBypassValidation() throws {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
        for value in ["-1", "20", "\"NaN\"", "\"Inf\"", "\"-Inf\""] {
            let data = Data("{\"start\":\(value),\"end\":20}".utf8)
            XCTAssertThrowsError(try decoder.decode(TimeRange.self, from: data))
        }
        XCTAssertThrowsError(try decoder.decode(Segment.self, from: Data(#"{"range":{"start":0,"end":10},"padding":1}"#.utf8)))
        XCTAssertThrowsError(try decoder.decode(ExportSettings.self, from: Data(#"{"codec":"h264","fps":24,"includeEndCard":false,"lrcRelativeToSegment":true}"#.utf8)))
    }

    func testSegmentBoundariesAndPadding() throws {
        for length in [15.0, 60.0] { XCTAssertNoThrow(try Segment(range: TimeRange(start: 0, end: length))) }
        for length in [14.999, 60.001] { XCTAssertThrowsError(try Segment(range: TimeRange(start: 0, end: length))) }
        for padding in [-1.0, 5.01, .nan, .infinity] { XCTAssertThrowsError(try Segment(range: TimeRange(start: 0, end: 15), padding: padding)) }
        let segment = try Segment(range: TimeRange(start: 0.5, end: 15.5))
        XCTAssertEqual(segment.decodedStart, 0)
        XCTAssertEqual(try segment.decodedEnd(audioDuration: 16), 16)
        XCTAssertThrowsError(try segment.decodedEnd(audioDuration: 15))
    }

    func testPartialTimingAndLocks() throws {
        let pending = try LyricLine(index: 0, paragraphIndex: 0, text: "Original", start: 1)
        XCTAssertNil(pending.end)
        XCTAssertFalse(pending.isLocked)
        for source in [TimingSource.manual, .tapSync] {
            let line = try LyricLine(index: 0, paragraphIndex: 0, text: "Original", start: 1, confidence: 1, source: source)
            XCTAssertTrue(line.isLocked)
        }
        XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: "x", start: 1, end: 1))
        XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: "x", end: -.infinity))
        XCTAssertThrowsError(try LyricLine(index: -1, paragraphIndex: 0, text: "x"))
        XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: "x", confidence: .nan))
    }

    func testUTF16CharacterBoundaries() throws {
        let text = "A👩🏽‍💻e\u{301}日"
        let emojiEnd = "A👩🏽‍💻".utf16.count
        let valid = try WordTiming(text: "👩🏽‍💻", range: 1..<emojiEnd, start: 1, end: 2)
        XCTAssertNoThrow(try LyricLine(index: 0, paragraphIndex: 0, text: text, words: [valid]))
        for range in [1..<2, emojiEnd..<(emojiEnd + 1), 0..<100] {
            let word = try WordTiming(text: "synthetic", range: range, start: 1, end: 2)
            XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: text, words: [word]))
        }
    }

    func testAudioSourceValidation() throws {
        for path in ["../audio.wav", "/tmp/audio.wav", "cache/../audio.wav", "C:\\audio.wav"] {
            XCTAssertThrowsError(try AudioSource(relativePath: path, contentSHA256: String(repeating: "a", count: 64), duration: 60, sampleRate: 44100, originalFilename: "audio.wav"))
        }
        XCTAssertThrowsError(try AudioSource(relativePath: "audio.wav", contentSHA256: "unverified", duration: 60, sampleRate: 44100, originalFilename: "audio.wav"))
        XCTAssertThrowsError(try AudioSource(relativePath: "audio.wav", contentSHA256: String(repeating: "a", count: 64), duration: .nan, sampleRate: 44100, originalFilename: "audio.wav"))
    }

    func testASRWordsValidateIntervalsAndProbability() throws {
        XCTAssertNoThrow(try ASRWord(text: "original", start: 1, end: 2, prob: 0.5, isEndEstimated: true))
        XCTAssertThrowsError(try ASRWord(text: "x", start: 1, end: 1, prob: 1, isEndEstimated: true))
        for prob: Float in [-1, 1.1, .nan, .infinity] {
            XCTAssertThrowsError(try ASRWord(text: "x", start: 1, end: 2, prob: prob, isEndEstimated: true))
        }
    }

    func testProjectGoldenRoundTrip() throws {
        let data = try fixture()
        let project = try ProjectMigrator.decode(data)
        XCTAssertEqual(project.rawLyrics, "First original line\n\nSecond original line")
        XCTAssertEqual(project.primaryASRLanguage, .en)
        XCTAssertFalse(try XCTUnwrap(project.templateOverrides).showCredit)
        let encoded = try ProjectMigrator.encode(project)
        XCTAssertEqual(try ProjectMigrator.decode(encoded), project)
        let original = try JSONSerialization.jsonObject(with: data) as! NSDictionary
        let roundTrip = try JSONSerialization.jsonObject(with: encoded) as! NSDictionary
        XCTAssertEqual(original, roundTrip)
        XCTAssertEqual(encoded, try ProjectMigrator.encode(project))
    }

    func testUnknownSchemaIsRejected() throws {
        for version in [0, 2, -1] {
            XCTAssertThrowsError(try ProjectMigrator.decode(mutated { $0["schemaVersion"] = version }))
        }
    }

    func testProjectChecksNestedBoundsAndIDs() throws {
        XCTAssertThrowsError(try ProjectMigrator.decode(mutated { object in
            var audio = object["audio"] as! [String: Any]; audio["duration"] = 10; object["audio"] = audio
        }))
        XCTAssertThrowsError(try ProjectMigrator.decode(mutated { object in
            let lines = object["lines"] as! [[String: Any]]; object["lines"] = [lines[0], lines[0]]
        }))
        XCTAssertThrowsError(try ProjectMigrator.decode(mutated { object in
            var lines = object["lines"] as! [[String: Any]]; lines[0]["end"] = 100; object["lines"] = lines
        }))
        XCTAssertThrowsError(try ProjectMigrator.decode(mutated { $0["primaryASRLanguage"] = "ja" }))
    }

    func testNestedNonfiniteValuesAreRejected() throws {
        for value in ["NaN", "Inf", "-Inf"] {
            let data = try mutated { object in
                var lines = object["lines"] as! [[String: Any]]; lines[0]["start"] = value; object["lines"] = lines
            }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
            XCTAssertThrowsError(try decoder.decode(Project.self, from: data))
        }
    }

    func testDefaultsAndSettingsValidation() throws {
        XCTAssertTrue(try TemplateOverrides().showCredit)
        XCTAssertFalse(try ExportSettings().includeEndCard)
        XCTAssertEqual(try ExportSettings().fps, 30)
        XCTAssertThrowsError(try ExportSettings(fps: 24))
        XCTAssertThrowsError(try TemplateOverrides(customBackgroundRelativePath: "../image.png"))
        XCTAssertThrowsError(try ProcessingInfo(separationEngineID: "passthrough", transcriptionEngineID: "whisper", whisperModelID: "base", usedCoreMLEncoder: false, usedDTWTimestamps: true, durationSeconds: .infinity, overallConfidence: 0.5))
    }

    func testWordsAreOrderedAndContained() throws {
        let first = try WordTiming(text: "ab", range: 0..<2, start: 1, end: 2)
        let adjacent = try WordTiming(text: "cd", range: 2..<4, start: 2, end: 3)
        XCTAssertNoThrow(try LyricLine(index: 0, paragraphIndex: 0, text: "abcd", start: 1, end: 3, words: [first, adjacent]))
        let rangeOverlap = try WordTiming(text: "bc", range: 1..<3, start: 2, end: 3)
        let timeOverlap = try WordTiming(text: "cd", range: 2..<4, start: 1.9, end: 3)
        for words in [[adjacent, first], [first, rangeOverlap], [first, timeOverlap]] {
            XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: "abcd", words: words))
        }
        XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: "abcd", start: 1.1, words: [first]))
        XCTAssertThrowsError(try LyricLine(index: 0, paragraphIndex: 0, text: "abcd", end: 1.9, words: [first]))
        let valid = try LyricLine(index: 0, paragraphIndex: 0, text: "abcd", words: [first, adjacent])
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as! [String: Any]
        object["start"] = 1.1
        XCTAssertThrowsError(try JSONDecoder().decode(LyricLine.self, from: JSONSerialization.data(withJSONObject: object)))
    }

    func testParagraphOrderAndShortAudioAreRejected() throws {
        XCTAssertThrowsError(try ProjectMigrator.decode(mutated { object in
            var lines = object["lines"] as! [[String: Any]]
            lines[0]["paragraphIndex"] = 1
            var second = lines[0]
            second["id"] = UUID().uuidString
            second["index"] = 1
            second["paragraphIndex"] = 0
            object["lines"] = lines + [second]
        }))
        for duration in [0.0, 14.999] {
            XCTAssertThrowsError(try AudioSource(relativePath: "audio.wav", contentSHA256: String(repeating: "a", count: 64), duration: duration, sampleRate: 44100, originalFilename: "audio.wav")) { error in
                XCTAssertEqual(error as? LCError, .invalidValue("audio.duration"))
            }
        }
        XCTAssertNoThrow(try AudioSource(relativePath: "audio.wav", contentSHA256: String(repeating: "a", count: 64), duration: 15, sampleRate: 44100, originalFilename: "audio.wav"))
    }

    func testDecodedManualConfidenceAndAllCharacterBoundaries() throws {
        XCTAssertThrowsError(try ProjectMigrator.decode(mutated { object in
            var lines = object["lines"] as! [[String: Any]]
            lines[0]["source"] = "manual"
            lines[0]["confidence"] = 0.5
            object["lines"] = lines
        }))
        XCTAssertEqual(characterOffsets(in: ""), [0])
        XCTAssertEqual(characterOffsets(in: "A👩🏽‍💻e\u{301}日"), [0, 1, 8, 10, 11])
    }

    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "project-v1", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func mutated(_ update: (inout [String: Any]) -> Void) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: fixture()) as! [String: Any]
        update(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

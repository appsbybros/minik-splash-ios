import XCTest
@testable import MinikMultiPingPong
import CoreGraphics
import CoreText

// Android app/src/test/.../multiplayer/MatchTextTest.kt (MinikCrossPong 828c6fc): MPMatchText keeps the canonical player and
// score order even when a nickname has the opposite direction.
final class MatchTextTests: XCTestCase {
    private struct VisualGlyph {
        let x: Double
        let order: Int
        let index: Int
    }

    /// Kotlin `visual` (java.text.Bidi.reorderVisually): the text's characters in display order for a paragraph of the given
    /// direction, without format characters (the isolates). iOS has no java.text.Bidi: CoreText lays the text out as one line
    /// and its glyphs, ordered by position, give the visual order.
    private func visualText(_ text: String, rtl: Bool) -> String {
        var direction: CTWritingDirection = rtl ? .rightToLeft : .leftToRight
        let style: CTParagraphStyle = withUnsafeBytes(of: &direction) { raw -> CTParagraphStyle in
            var setting = CTParagraphStyleSetting(spec: .baseWritingDirection, valueSize: MemoryLayout<CTWritingDirection>.size,
                                                  value: raw.baseAddress!)
            return CTParagraphStyleCreate(&setting, 1)
        }
        let key = NSAttributedString.Key(rawValue: kCTParagraphStyleAttributeName as String)
        let attributed = NSAttributedString(string: text, attributes: [key: style])
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        var glyphs: [VisualGlyph] = []
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            if count <= 0 { continue }
            var indices = [CFIndex](repeating: 0, count: count)
            var positions = [CGPoint](repeating: CGPoint.zero, count: count)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for i in 0..<count {
                let order = glyphs.count
                glyphs.append(VisualGlyph(x: Double(positions[i].x), order: order, index: indices[i]))
            }
        }
        glyphs.sort { $0.x != $1.x ? $0.x < $1.x : $0.order < $1.order }
        let units = Array(text.utf16)
        var used = Set<Int>()
        var visual: [UInt16] = []
        for glyph in glyphs where glyph.index >= 0 && glyph.index < units.count && !used.contains(glyph.index) {
            used.insert(glyph.index)
            visual.append(units[glyph.index])
        }
        var result = ""
        for scalar in String(decoding: visual, as: UTF16.self).unicodeScalars where scalar.properties.generalCategory != .format {
            result.unicodeScalars.append(scalar)
        }
        return result
    }

    /// Kotlin `String.indexOf`: the character offset of `needle` in `text`, or -1.
    private func offset(of needle: String, in text: String) -> Int {
        guard let range = text.range(of: needle) else { return -1 }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    // Kotlin: mixedNamesNeverReverseCanonicalScore
    func testMixedNamesNeverReverseCanonicalScore() {
        let pairs: [(String, String)] = [("Player", "שחקן"), ("שחקן", "Player"), ("מיניק", "שחקן")]
        for rtl in [false, true] {
            for names in pairs {
                let line = visualText(MPMatchText.result(names.0, 2, 3, names.1), rtl: rtl)
                XCTAssertTrue(line.contains("2 : 3"), line)
                XCTAssertFalse(line.contains("3 : 2"), line)
            }
        }
    }

    // Kotlin: liveScoreAndStandingNumbersKeepTheirDeclaredOrder
    func testLiveScoreAndStandingNumbersKeepTheirDeclaredOrder() {
        for rtl in [false, true] {
            XCTAssertEqual("2 : 3", visualText(MPMatchText.score(2, 3), rtl: rtl))
            let standing = visualText("שחקן · " + MPMatchText.ordered("1 / 1 / 0 / 3 / 3:2"), rtl: rtl)
            XCTAssertTrue(standing.contains("1 / 1 / 0 / 3 / 3:2"), standing)
        }
    }

    // Kotlin: canonicalPairKeepsFirstParticipantFirstInBothLanguages
    func testCanonicalPairKeepsFirstParticipantFirstInBothLanguages() {
        for rtl in [false, true] {
            let line = visualText(MPMatchText.pair("Player", "שחקן"), rtl: rtl)
            XCTAssertTrue(offset(of: "Player", in: line) < offset(of: "↔", in: line), line)
        }
    }

    // Kotlin: resultSummaryKeepsPairBeforeScoreWithHebrewWinner
    func testResultSummaryKeepsPairBeforeScoreWithHebrewWinner() {
        for rtl in [false, true] {
            // Kotlin MatchText.summary(a, b, state) is the two-name case of MPMatchText.summary(names, state).
            let line = visualText(MPMatchText.summary(["Player", "שחקן"], MPMatchText.score(2, 3) + " · שחקן"), rtl: rtl)
            XCTAssertTrue(offset(of: "Player", in: line) < offset(of: "2 : 3", in: line), line)
            // Not ported: the MatchText.standing(1, "שחקן", "1 / 1 / 0 / 3 / 3:2") assertions (startsWith "1.", endsWith the
            // values) — MPMatchText has no standing(rank:player:values:) builder.
        }
    }
}

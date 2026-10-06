import XCTest
@testable import MinikSplash

/// Port of Android core/LearningAcceptanceTest.kt plus golden generator parity with Android.
final class LearningAcceptanceTests: XCTestCase {
    private func number(_ s: String) -> Double {
        let p = s.trimmingCharacters(in: .whitespaces).split(separator: "/").map { Double(String($0)) ?? .nan }
        return p[0] / (p.count > 1 ? p[1] : 1)
    }

    private func evaluate(_ s: String) -> Double {
        let sums = s.components(separatedBy: " + ")
        if sums.count > 1 { return sums.map { evaluate($0) }.reduce(0, +) }
        for op in [" − ", " × ", " ÷ "] {
            let terms = s.components(separatedBy: op)
            if terms.count == 2 {
                let a = evaluate(terms[0])
                let b = evaluate(terms[1])
                switch op {
                case " − ": return a - b
                case " × ": return a * b
                default:
                    XCTAssertNotEqual(b, 0)
                    return a / b
                }
            }
        }
        return number(s)
    }

    func testArithmeticSolutionsAreCorrectIndependentlyOfOptionGeneration() {
        for skill in Skill.allCases.prefix(6) {
            for level in 0...5 {
                for seed in 0...199 {
                    let q = QuestionBank.generate("q", skill, level, KotlinRandom(seed: Int64(seed)))
                    let value = evaluate(q.en)
                    XCTAssertEqual(value, number(q.answer), accuracy: 0.0000001, q.en)
                    XCTAssertEqual(q.options.filter { abs(number($0) - value) < 0.0000001 }.count, 1)
                }
            }
        }
    }

    func testEnglishMasteryDoesNotUnlockUnlearnedArithmetic() {
        let p = LearningProfile()
        p.skills[.english]?.independent = 200
        p.skills[.world]?.independent = 200
        for seed in 0...200 {
            let skill = QuestionBank.chooseSkill(p, .math, KotlinRandom(seed: Int64(seed)), seed)
            XCTAssertTrue([Skill.add, Skill.subtract].contains(skill))
        }
        p.skills[.add]?.independent = 6
        let seen = Set((0...200).map { QuestionBank.chooseSkill(p, .math, KotlinRandom(seed: Int64($0)), $0) })
        XCTAssertTrue(seen.contains(.multiply))
        XCTAssertFalse(seen.contains(.divide))
        XCTAssertFalse(seen.contains(.fraction))
    }

    func testLowLevelSubtractionRemainsNonNegativeWhileAdvancedAllowsNegatives() {
        let advanced = (0...300).map { Int(QuestionBank.generate("q", .subtract, 4, KotlinRandom(seed: Int64($0))).answer) ?? 0 }
        XCTAssertTrue(advanced.contains { $0 < 0 })
        for level in 0...3 {
            for seed in 0...100 {
                XCTAssertGreaterThanOrEqual(Int(QuestionBank.generate("q", .subtract, level, KotlinRandom(seed: Int64(seed))).answer) ?? -1, 0)
            }
        }
    }

    /// Every generated question (text, Hebrew, answer, option order, explanations) equals Android's.
    func testGeneratedQuestionsMatchAndroid() {
        let rows = AndroidGolden.rows(AndroidGolden.questions)
        XCTAssertEqual(rows.count, 8 * 6 * 3 + 4 * 6)
        for row in rows {
            let f = row.components(separatedBy: "|")
            guard f.count == 11, let seed = Int64(f[1]), let skill = Skill(rawValue: f[3]), let level = Int(f[4]) else {
                XCTFail(row)
                continue
            }
            let q = QuestionBank.generate("q", skill, level, KotlinRandom(seed: seed), hebrew: f[2] == "1")
            XCTAssertEqual(q.en, f[5], row)
            XCTAssertEqual(q.he, f[6], row)
            XCTAssertEqual(q.answer, f[7], row)
            XCTAssertEqual(q.options, f[8].components(separatedBy: ";"), row)
            XCTAssertEqual(q.explanationEn, f[9], row)
            XCTAssertEqual(q.explanationHe, f[10], row)
        }
    }

    func testSkillChoiceMatchesAndroid() {
        let fresh = LearningProfile()
        let grown = LearningProfile()
        grown.skills[.add]?.independent = 9
        grown.skills[.subtract]?.independent = 2
        grown.skills[.multiply]?.independent = 7
        grown.skills[.divide]?.independent = 4
        grown.skills[.divide]?.assisted = 1
        let rows = AndroidGolden.rows(AndroidGolden.choose)
        XCTAssertEqual(rows.count, 6)
        for row in rows {
            let halves = row.components(separatedBy: " | ")
            let head = halves[0].split(separator: " ").map { String($0) }
            guard halves.count == 2, head.count == 3, let topic = Topic(rawValue: head[2]) else {
                XCTFail(row)
                continue
            }
            let profile = head[1] == "0" ? fresh : grown
            let expected = halves[1].split(separator: " ").map { String($0) }
            let actual = (0..<12).map { QuestionBank.chooseSkill(profile, topic, KotlinRandom(seed: Int64($0 * 31 + 5)), $0).rawValue }
            XCTAssertEqual(actual, expected, row)
        }
    }

    func testReviewedBanksMatchAndroidSizes() {
        XCTAssertEqual(QuestionBank.english.count, 24)
        XCTAssertEqual(QuestionBank.world.count, 12)
        for fact in QuestionBank.english + QuestionBank.world {
            XCTAssertEqual(fact.choicesEn.count, 4)
            XCTAssertEqual(fact.choicesHe.count, 4)
            XCTAssertEqual(Set(fact.choicesEn).count, 4)
        }
    }
}

import XCTest
@testable import MinikPlus

final class RetroPongHostTests: XCTestCase {
    private func isolated(_ body: (UserDefaults, RetroPongStorage) throws -> Void) rethrows {
        let suite = "retro-pong-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults, RetroPongStorage(defaults))
    }
    func testFreshUserStartsAtBeginnerWithNoPoints() {
        isolated { _, storage in
            XCTAssertEqual(storage.progress, RetroPongProgress())
            XCTAssertEqual(storage.progress.opponentDifficulty, "beginner")
            XCTAssertEqual(storage.progress.targetScore, 5)
        }
    }
    func testLegacySettingsAreImportedWithoutChangingOldOrMathKeys() {
        isolated { defaults, storage in
            defaults.set("medium", forKey: "minik.ping-pong.difficulty")
            defaults.set(10, forKey: "minik.ping-pong.target.medium")
            defaults.set(83, forKey: "math.progress")
            XCTAssertEqual(storage.progress.opponentDifficulty, "medium")
            XCTAssertEqual(storage.progress.targetScore, 11)
            XCTAssertEqual(defaults.integer(forKey: "minik.ping-pong.target.medium"), 10)
            XCTAssertEqual(defaults.integer(forKey: "math.progress"), 83)
        }
    }
    func testSavedRankLevelsAndSettingsWinOverLegacyDefaults() throws {
        try isolated { defaults, storage in
            var value = RetroPongProgress()
            value.points = 1203; value.operation = "multiply"; value.levels["multiply"] = 8
            value.opponentDifficulty = "hard"; value.targetScore = 7; value.balloonMadness = false
            let raw = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
            XCTAssertTrue(storage.save(raw))
            defaults.set("beginner", forKey: "minik.ping-pong.difficulty")
            XCTAssertEqual(RetroPongStorage(defaults).progress, value)
        }
    }
    func testInvalidAndOversizedStateCannotReplaceProgress() throws {
        try isolated { _, storage in
            var value = RetroPongProgress(); value.points = 700
            XCTAssertTrue(storage.save(String(decoding: try JSONEncoder().encode(value), as: UTF8.self)))
            for raw in ["{}", "null", String(repeating: "x", count: 8193)] { XCTAssertFalse(storage.save(raw)) }
            value.points = -1
            XCTAssertFalse(storage.save(String(decoding: try JSONEncoder().encode(value), as: UTF8.self)))
            XCTAssertEqual(storage.progress.points, 700)
        }
    }
    func testAllOperationsAndDifficultyBounds() {
        var value = RetroPongProgress()
        for difficulty in ["beginner", "medium", "hard"] {
            value.opponentDifficulty = difficulty; XCTAssertTrue(value.valid)
        }
        value.levels["addition"] = 13; XCTAssertFalse(value.valid)
        value.levels["addition"] = 1; value.trainMode = "ball"; XCTAssertFalse(value.valid)
        value.trainMode = "tap"; value.targetScore = 10; XCTAssertFalse(value.valid)
    }
    func testBootstrapIsJSONAndCannotInjectLanguageScript() throws {
        try isolated { _, storage in
            let script = storage.bootstrap(language: "he\";alert(1)", paused: true)
            let raw = script.dropFirst("window.__minikRetroConfig=".count).dropLast()
            let config = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            XCTAssertEqual(config["language"] as? String, "en")
            XCTAssertEqual(config["paused"] as? Bool, true)
            XCTAssertNotNil(config["state"] as? [String: Any])
            XCTAssertEqual(config["monetization"] as? Bool, false)
            XCTAssertEqual(config["parents"] as? Bool, false)
        }
    }
    func testStandaloneBootstrapEnablesTheAdBoundaryAndParentsLink() throws {
        try isolated { _, storage in
            let script = storage.bootstrap(language: "en", paused: false, canExit: false, monetization: true, parents: true)
            let raw = script.dropFirst("window.__minikRetroConfig=".count).dropLast()
            let config = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            XCTAssertEqual(config["monetization"] as? Bool, true)
            XCTAssertEqual(config["parents"] as? Bool, true)
            XCTAssertEqual(config["canExit"] as? Bool, false)
        }
    }
    func testNavigationCannotEscapeTheBundledGame() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RetroPong", isDirectory: true)
        XCTAssertTrue(RetroPongNavigation.isBundled(root.appendingPathComponent("index.html"), directory: root))
        XCTAssertFalse(RetroPongNavigation.isBundled(URL(string: "https://example.com"), directory: root))
        XCTAssertFalse(RetroPongNavigation.isBundled(root.appendingPathComponent("../other/index.html"), directory: root))
        XCTAssertFalse(RetroPongNavigation.isBundled(root.appendingPathComponent("../RetroPong-other/index.html"), directory: root))
        XCTAssertFalse(RetroPongNavigation.isBundled(nil, directory: root))
    }
}

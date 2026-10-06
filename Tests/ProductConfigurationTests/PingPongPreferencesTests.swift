import XCTest
@testable import MinikPlus

final class PingPongPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PingPongPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsAndInvalidStoredValuesResolveSafely() {
        let preferences = PingPongPreferences(userDefaults: defaults)
        XCTAssertEqual(preferences.selectedDifficulty, .starter)
        XCTAssertEqual(preferences.selectedControlMode, .tap)
        XCTAssertEqual(preferences.selectedTarget(for: .starter), 7)

        defaults.set("expert", forKey: "minik.ping-pong.difficulty")
        defaults.set("drag", forKey: "minik.ping-pong.control-mode")
        defaults.set(15, forKey: "minik.ping-pong.target.hard")
        XCTAssertEqual(preferences.selectedDifficulty, .starter)
        XCTAssertEqual(preferences.selectedControlMode, .tap)
        XCTAssertEqual(preferences.selectedTarget(for: .hard), 7)
    }

    func testDifficultyModeAndPerDifficultyTargetsPersist() {
        let preferences = PingPongPreferences(userDefaults: defaults)
        preferences.selectedDifficulty = .hard
        preferences.selectedControlMode = .swipe
        preferences.setSelectedTarget(10, for: .easy)
        preferences.setSelectedTarget(11, for: .hard)

        let restored = PingPongPreferences(userDefaults: defaults)
        XCTAssertEqual(restored.selectedDifficulty, .hard)
        XCTAssertEqual(restored.selectedControlMode, .swipe)
        XCTAssertEqual(restored.selectedTarget(for: .easy), 10)
        XCTAssertEqual(restored.selectedTarget(for: .hard), 11)
    }

    func testInterstitialOpportunityDefaultsToEveryTwoCompletedMatches() {
        let policy = PingPongInterstitialPolicy()
        XCTAssertFalse(policy.isOpportunity(afterCompletedMatch: 0))
        XCTAssertFalse(policy.isOpportunity(afterCompletedMatch: 1))
        XCTAssertTrue(policy.isOpportunity(afterCompletedMatch: 2))
        XCTAssertFalse(policy.isOpportunity(afterCompletedMatch: 3))
        XCTAssertTrue(policy.isOpportunity(afterCompletedMatch: 4))

        let custom = PingPongInterstitialPolicy(completedMatchesPerOpportunity: 3)
        XCTAssertTrue(custom.isOpportunity(afterCompletedMatch: 3))
        XCTAssertFalse(custom.isOpportunity(afterCompletedMatch: 4))
    }
}
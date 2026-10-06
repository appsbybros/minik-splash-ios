import XCTest
@testable import MinikPlus

final class TicTacToePreferencesTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TicTacToePreferencesTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsMatchAndroidProduction() {
        let preferences = TicTacToePreferences(userDefaults: userDefaults)

        XCTAssertEqual(preferences.selectedLevel, .adaptive)
        XCTAssertFalse(preferences.hasSpokenFirstInstruction)
        XCTAssertEqual(preferences.adaptiveState, .androidDefault)
    }

    func testLevelInstructionAndAdaptiveStateRoundTrip() {
        let preferences = TicTacToePreferences(userDefaults: userDefaults)
        var state = TicTacToeAdaptiveState.androidDefault
        state.baseline = .easy
        state.hardChance = 0.32
        state.wins = 7
        state.gamesPlayed = 11

        preferences.selectedLevel = .d
        preferences.hasSpokenFirstInstruction = true
        preferences.adaptiveState = state

        let reloaded = TicTacToePreferences(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.selectedLevel, .d)
        XCTAssertTrue(reloaded.hasSpokenFirstInstruction)
        XCTAssertEqual(reloaded.adaptiveState, state)
    }

    func testInvalidPersistedValuesFallBackSafely() {
        userDefaults.set("UNKNOWN", forKey: "minik.tic-tac-toe.selected-level")
        userDefaults.set(Data("not-json".utf8), forKey: "minik.tic-tac-toe.adaptive-state")
        let preferences = TicTacToePreferences(userDefaults: userDefaults)

        XCTAssertEqual(preferences.selectedLevel, .adaptive)
        XCTAssertEqual(preferences.adaptiveState, .androidDefault)

        var invalidState = TicTacToeAdaptiveState.androidDefault
        invalidState.hardChance = 0.9
        preferences.adaptiveState = invalidState

        XCTAssertEqual(preferences.adaptiveState, .androidDefault)
    }
}

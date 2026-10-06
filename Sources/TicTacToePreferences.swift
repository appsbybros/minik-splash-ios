import Foundation

protocol TicTacToePreferencesProviding: AnyObject {
    var selectedLevel: TicTacToeLevel { get set }
    var hasSpokenFirstInstruction: Bool { get set }
    var adaptiveState: TicTacToeAdaptiveState { get set }
}

final class TicTacToePreferences: TicTacToePreferencesProviding {
    private enum Key {
        static let selectedLevel = "minik.tic-tac-toe.selected-level"
        static let hasSpokenFirstInstruction = "minik.tic-tac-toe.first-instruction-spoken"
        static let adaptiveState = "minik.tic-tac-toe.adaptive-state"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var selectedLevel: TicTacToeLevel {
        get {
            guard let rawValue = userDefaults.string(forKey: Key.selectedLevel),
                  let level = TicTacToeLevel(rawValue: rawValue) else {
                return .adaptive
            }
            return level
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Key.selectedLevel)
        }
    }

    var hasSpokenFirstInstruction: Bool {
        get {
            userDefaults.bool(forKey: Key.hasSpokenFirstInstruction)
        }
        set {
            userDefaults.set(newValue, forKey: Key.hasSpokenFirstInstruction)
        }
    }

    var adaptiveState: TicTacToeAdaptiveState {
        get {
            guard let data = userDefaults.data(forKey: Key.adaptiveState),
                  let state = try? decoder.decode(TicTacToeAdaptiveState.self, from: data),
                  state.hardChance.isFinite,
                  (0...0.7).contains(state.hardChance),
                  state.wins >= 0,
                  state.losses >= 0,
                  state.draws >= 0,
                  state.gamesPlayed >= 0 else {
                return .androidDefault
            }
            return state
        }
        set {
            guard let data = try? encoder.encode(newValue) else {
                return
            }
            userDefaults.set(data, forKey: Key.adaptiveState)
        }
    }
}

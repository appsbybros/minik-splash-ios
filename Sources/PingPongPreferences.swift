import Foundation

protocol PingPongPreferencesProviding: AnyObject {
    var selectedDifficulty: PingPongDifficulty { get set }
    var selectedControlMode: PingPongControlMode { get set }
    var selectedVisualStyle: PingPongVisualStyle { get set }
    func selectedTarget(for difficulty: PingPongDifficulty) -> Int
    func setSelectedTarget(_ target: Int, for difficulty: PingPongDifficulty)
}

final class PingPongPreferences: PingPongPreferencesProviding {
    private enum Key {
        static let difficulty = "minik.ping-pong.difficulty"
        static let controlMode = "minik.ping-pong.control-mode"
        static let visualStyle = "minik.ping-pong.visual-style"

        static func target(for difficulty: PingPongDifficulty) -> String {
            "minik.ping-pong.target.\(difficulty.rawValue)"
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var selectedDifficulty: PingPongDifficulty {
        get {
            guard let rawValue = userDefaults.string(forKey: Key.difficulty),
                  let value = PingPongDifficulty(rawValue: rawValue) else {
                return .starter
            }
            return value
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Key.difficulty)
        }
    }

    var selectedControlMode: PingPongControlMode {
        get {
            guard let rawValue = userDefaults.string(forKey: Key.controlMode),
                  let value = PingPongControlMode(rawValue: rawValue) else {
                return .tap
            }
            return value
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Key.controlMode)
        }
    }

    var selectedVisualStyle: PingPongVisualStyle {
        get {
            guard let rawValue = userDefaults.string(forKey: Key.visualStyle),
                  let value = PingPongVisualStyle(rawValue: rawValue) else {
                return .modern
            }
            return value
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Key.visualStyle)
        }
    }

    func selectedTarget(for difficulty: PingPongDifficulty) -> Int {
        let stored = userDefaults.object(forKey: Key.target(for: difficulty)) as? Int
        return difficulty.resolvedTarget(stored)
    }

    func setSelectedTarget(_ target: Int, for difficulty: PingPongDifficulty) {
        userDefaults.set(
            difficulty.resolvedTarget(target),
            forKey: Key.target(for: difficulty)
        )
    }
}

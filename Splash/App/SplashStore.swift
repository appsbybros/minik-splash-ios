import Foundation

/// Android SharedPreferences files "minik_splash", "splash_local_battle" and "splash_online",
/// kept as prefixed UserDefaults keys with the same names and JSON values.
enum SplashPrefs {
    private static let defaults = UserDefaults.standard

    private static func key(_ file: String, _ name: String) -> String { return file + "." + name }

    static func string(_ name: String, file: String = "minik_splash") -> String? {
        return defaults.string(forKey: key(file, name))
    }

    static func setString(_ value: String?, _ name: String, file: String = "minik_splash") {
        if let value = value {
            defaults.set(value, forKey: key(file, name))
        } else {
            defaults.removeObject(forKey: key(file, name))
        }
    }

    static func int(_ name: String, _ fallback: Int, file: String = "minik_splash") -> Int {
        return defaults.object(forKey: key(file, name)) as? Int ?? fallback
    }

    static func setInt(_ value: Int, _ name: String, file: String = "minik_splash") {
        defaults.set(value, forKey: key(file, name))
    }

    static func setBool(_ value: Bool, _ name: String, file: String = "minik_splash") {
        defaults.set(value, forKey: key(file, name))
    }

    static func contains(_ name: String, file: String = "minik_splash") -> Bool {
        return defaults.object(forKey: key(file, name)) != nil
    }

    static var onlineRoom: String? {
        get { return string("room", file: "splash_online") }
        set { setString(newValue, "room", file: "splash_online") }
    }
}

/// Port of Android LocalBattleStore.kt: one saved local battle (and its cup progress).
final class LocalBattleStore {
    struct Saved {
        let engine: SplashEngine
        let cup: Bool
        let round: Int
        let scores: [String: Int]
    }

    private let file = "splash_local_battle"

    func hasBattle() -> Bool {
        return SplashPrefs.contains("battle", file: file)
    }

    func save(_ e: SplashEngine, cupRound: Int, cupScores: [String: Int], cup: Bool) {
        if e.practice { return }
        if e.result != nil {
            clear()
            return
        }
        let data: Node = ["members": e.members.map { WorldCodec.member($0) }, "mode": e.mode.name, "topic": e.topic.name,
                          "seed": NSNumber(value: e.seed), "id": e.matchId, "hebrew": e.hebrew, "duration": e.config.duration,
                          "state": WorldCodec.checkpoint(e), "cup": cup, "cupRound": cupRound, "cupScores": cupScores]
        guard let text = NodeJSON.string(data) else { return }
        SplashPrefs.setString(text, "battle", file: file)
    }

    func load() -> Saved? {
        guard let n = NodeJSON.node(SplashPrefs.string("battle", file: file)) else { return nil }
        let members = n.list("members").map { item -> Member in
            let m = NodeValue.node(item)
            return WorldCodec.member(m.str("id"), m)
        }
        guard let mode = GameMode(rawValue: n.str("mode")), let topic = Topic(rawValue: n.str("topic")),
              SplashEngine.validRoster(members, mode) else { return nil }
        let e = SplashEngine(members: members, mode: mode, topic: topic, seed: KotlinNumber.long(n.num("seed")),
                             config: SplashConfig(duration: n.num("duration", 180.0)), hebrew: n.flag("hebrew"),
                             matchId: n.str("id"))
        WorldCodec.restore(e, n.node("state"))
        var scores: [String: Int] = [:]
        for (key, value) in n.node("cupScores") { scores[key] = KotlinNumber.int(NodeValue.number(value) ?? 0) }
        return Saved(engine: e, cup: n.flag("cup"), round: KotlinNumber.int(n.num("cupRound")), scores: scores)
    }

    func clear() {
        SplashPrefs.setString(nil, "battle", file: file)
    }
}

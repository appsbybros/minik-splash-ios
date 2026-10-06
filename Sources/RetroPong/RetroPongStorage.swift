import Foundation

/// One local state contract for the Math host and the standalone app. App sandboxes remain separate.
struct RetroPongProgress: Codable, Equatable {
    var version = 1
    var points = 0
    var operation = "addition"
    var levels = ["addition": 1, "subtraction": 1, "multiply": 1, "divide": 1]
    var controlDesktop = "arrows", controlTouch = "arrows", trainMode = "tap"
    var opponentDifficulty = "beginner", targetScore = 5
    var balloonMadness: Bool?
    var valid: Bool {
        version == 1 && points >= 0 && points <= 9_007_199_254_740_991 &&
        ["addition", "subtraction", "multiply", "divide"].contains(operation) &&
        ["beginner", "medium", "hard"].contains(opponentDifficulty) && [3, 5, 7, 11].contains(targetScore) &&
        ["tap", "off"].contains(trainMode) && ["addition", "subtraction", "multiply", "divide"].allSatisfy { (1...12).contains(levels[$0] ?? 0) }
    }
}

final class RetroPongStorage {
    static let webKey = "minik.pong.progress.v1"
    static let nativeKey = "minik.retro-pong.progress.v1"
    private let defaults: UserDefaults
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    var progress: RetroPongProgress {
        if let data = defaults.data(forKey: Self.nativeKey), let value = try? JSONDecoder().decode(RetroPongProgress.self, from: data), value.valid { return value }
        // Import only explicitly saved legacy settings, leaving all old keys intact.
        var value = RetroPongProgress()
        if let level = defaults.string(forKey: "minik.ping-pong.difficulty") {
            value.opponentDifficulty = ["medium", "hard"].contains(level) ? level : "beginner"
            if let target = defaults.object(forKey: "minik.ping-pong.target." + level) as? Int {
                value.targetScore = target == 10 ? 11 : [3, 5, 7, 11].contains(target) ? target : 5
            }
        }
        return value
    }
    @discardableResult func save(_ raw: String) -> Bool {
        guard raw.utf8.count <= 8192, let data = raw.data(using: .utf8),
              let value = try? JSONDecoder().decode(RetroPongProgress.self, from: data), value.valid,
              let canonical = try? JSONEncoder().encode(value) else { return false }
        defaults.set(canonical, forKey: Self.nativeKey); return true
    }
    func bootstrap(language: String, paused: Bool, canExit: Bool = false, monetization: Bool = false, parents: Bool = false) -> String {
        let value = (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(progress))) ?? [:]
        let config: [String: Any] = ["language": language == "he" ? "he" : "en", "state": value, "paused": paused, "canExit": canExit,
                                     "monetization": monetization, "parents": parents]
        let data = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        return "window.__minikRetroConfig=" + (data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}") + ";"
    }
}

enum RetroPongNavigation {
    static func isBundled(_ url: URL?, directory: URL) -> Bool {
        guard let url, url.isFileURL else { return false }
        let root = directory.resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return path.hasPrefix(root + "/")
    }
}

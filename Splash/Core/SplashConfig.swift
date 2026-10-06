import Foundation

/// Port of Android core/SplashConfig.kt: physics, gestures, penalties, bot timing, network
/// cadence and RenderConfig framing. Values are identical to Android.
struct SplashConfig: Equatable {
    var width: Double = 12.0
    var depth: Double = 12.0
    var moveSpeed: Double = 3.8
    var throwSpeed: Double = 7.8
    var gravity: Double = 2.6
    var launchLift: Double = 1.2
    var personalSpace: Double = 1.12
    var actorRadius: Double = 0.38
    var standingHeight: Double = 1.7
    var crouchHeight: Double = 1.02
    var jumpVelocity: Double = 4.2
    var jumpGravity: Double = 9.5
    var crouchSeconds: Double = 0.85
    var pickupRadius: Double = 1.05
    var answerRing: Double = 1.60
    var cleanSeconds: Double = 1.5
    var returnShield: Double = 0.8
    var paintLayers: Int = 3
    var mistakeRecovery: Double = 0.65
    var mistakePoints: Int = 1
    var target: Int = 10
    var teamTarget: Int = 20
    var duration: Double = 180.0
    var friendlyFire: Bool = false
    var doubleTapMs: Int64 = 220
    var gestureSlopDp: Double = 11.0
    var bodyTouchDp: Double = 34.0
    var arcTouchDp: Double = 24.0
    var doubleTapDistanceDp: Double = 38.0
    var movementDragDp: Double = 32.0
    var render: RenderConfig = RenderConfig()
    var snapshotHz: Int = 12
    var inputHz: Int = 20
    var botThinkMin: Double = 1.9
    var botThinkMax: Double = 3.8
    var particleLimit: Int = 220

    /// Android's `init { require(...) }` checks, kept as a query instead of a crash.
    var isValid: Bool {
        var ok = width >= 8.0 && depth >= 8.0 && moveSpeed > 0.0 && throwSpeed > 0.0 && gravity > 0.0
        ok = ok && personalSpace >= actorRadius * 2.0 && personalSpace < 2.0
        ok = ok && standingHeight > crouchHeight && crouchHeight > 0.0
        ok = ok && jumpVelocity > 0.0 && jumpGravity > 0.0
        ok = ok && pickupRadius >= 0.4 && pickupRadius <= 2.0 && answerRing > pickupRadius
        ok = ok && cleanSeconds >= 0.1 && cleanSeconds <= 4.0
        ok = ok && returnShield >= 0.0 && returnShield <= 2.0
        ok = ok && paintLayers >= 1 && paintLayers <= 6
        ok = ok && mistakePoints >= 0 && mistakeRecovery >= 0.0 && mistakeRecovery <= 2.0
        ok = ok && target > 0 && teamTarget > 0 && duration > 0.0
        ok = ok && doubleTapMs >= 150 && doubleTapMs <= 350
        ok = ok && snapshotHz >= 5 && snapshotHz <= 30 && inputHz >= 5 && inputHz <= 30
        ok = ok && botThinkMin > 0.0 && botThinkMax >= botThinkMin
        ok = ok && particleLimit >= 30 && particleLimit <= 600
        return ok
    }
}

enum GameMode: String, KotlinEnum {
    case solo = "SOLO"
    case teams = "TEAMS"
}

enum Topic: String, KotlinEnum {
    case math = "MATH"
    case english = "ENGLISH"
    case world = "WORLD"
    case mixed = "MIXED"
}

struct SplashCharacter: Equatable {
    let id: String
    let en: String
    let he: String
    let skill: Double

    func name(_ hebrew: Bool) -> String { return hebrew ? he : en }
}

enum Characters {
    static let all: [SplashCharacter] = [
        SplashCharacter(id: "miniko", en: "Miniko", he: "מיניקו", skill: 0.70),
        SplashCharacter(id: "minik", en: "Minik", he: "מיניק", skill: 0.64),
        SplashCharacter(id: "kyra", en: "Kyra", he: "ספיר", skill: 0.94),
        SplashCharacter(id: "flare", en: "Flare", he: "Flare", skill: 0.9),
        SplashCharacter(id: "gaya", en: "Gaya", he: "גאיה", skill: 0.83),
        SplashCharacter(id: "mia", en: "Mia", he: "מיה", skill: 0.77),
        SplashCharacter(id: "amber", en: "Amber", he: "ענבר", skill: 0.82),
        SplashCharacter(id: "comet", en: "Comet", he: "שביט", skill: 0.86),
        SplashCharacter(id: "june", en: "June", he: "סהר", skill: 0.80),
        SplashCharacter(id: "moshiko", en: "Bouncy Bob", he: "מושיקו", skill: 0.66),
        SplashCharacter(id: "coach67", en: "Coach67", he: "Coach67", skill: 0.88)
    ]

    static func get(_ id: String) -> SplashCharacter {
        return all.first { $0.id == id } ?? all[0]
    }
}

struct V: Equatable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static let zero = V(0, 0)

    static func + (a: V, b: V) -> V { return V(a.x + b.x, a.y + b.y) }
    static func - (a: V, b: V) -> V { return V(a.x - b.x, a.y - b.y) }
    static func * (a: V, n: Double) -> V { return V(a.x * n, a.y * n) }

    func length() -> Double { return hypot(x, y) }

    func unit() -> V {
        let d = length()
        return d < 0.0001 ? V(0, -1) : self * (1 / d)
    }
}

enum Facing {
    case front, back, left, right

    static func of(_ direction: V) -> Facing {
        if abs(direction.x) > abs(direction.y) * 0.85 { return direction.x < 0 ? .left : .right }
        return direction.y < 0 ? .back : .front
    }
}

/// Projection and visual balancing (Android RenderConfig).
struct RenderConfig: Equatable {
    var horizontalPadding: Double = 2.0
    var floorTop: Double = 0.32
    var floorDepth: Double = 0.552
    var heightScale: Double = 0.067
    var backPerspective: Double = 0.82
    var depthPerspective: Double = 0.018
    var characterWidth: Double = 0.235
    var numberBalloonWidth: Double = 0.125
    var wordBalloonWidth: Double = 0.16
    var longWordBalloonWidth: Double = 0.18
}

import CoreGraphics
import Foundation

enum PingPongDifficulty: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case starter
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .starter: return String(localized: "Starter")
        case .easy: return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard: return String(localized: "Hard")
        }
    }

    var supportsControlMode: Bool { self != .starter }

    var allowedTargets: [Int] {
        switch self {
        case .starter, .easy: return [3, 5, 7, 10]
        case .medium, .hard: return [3, 5, 7, 11]
        }
    }

    var defaultTarget: Int { 7 }

    func resolvedTarget(_ target: Int?) -> Int {
        guard let target, allowedTargets.contains(target) else {
            return defaultTarget
        }
        return target
    }
}

enum PingPongControlMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case tap
    case swipe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tap: return String(localized: "Tap")
        case .swipe: return String(localized: "Swipe")
        }
    }
}

enum PingPongParticipant: String, Equatable, Sendable {
    case child
    case minik

    var opponent: PingPongParticipant {
        self == .child ? .minik : .child
    }

    var displayName: String {
        self == .child ? String(localized: "You") : String(localized: "Minik")
    }
}

enum PingPongPaddleSide: Equatable, Sendable {
    case backhand
    case forehand

    static func side(forNormalizedX x: CGFloat) -> PingPongPaddleSide {
        x < 0.5 ? .backhand : .forehand
    }
}

struct PingPongTuning: Equatable, Sendable {
    let tapSpatialTolerance: CGFloat
    let tapTimingWindow: TimeInterval
    let tapTimingQualityExponent: CGFloat
    let swipeCollisionForgiveness: CGFloat
    let swipeVelocityScale: CGFloat
    let minimumSwipeSpeed: CGFloat
    let maximumSwipeSpeed: CGFloat
    let serveAssistance: CGFloat
    let ballBaseSpeed: CGFloat
    let rallySpeedGrowth: CGFloat
    let maximumBallSpeed: CGFloat
    let gravity: CGFloat
    let bounceRestitution: CGFloat
    let netHeight: CGFloat
    let netClearanceVelocityTarget: CGFloat
    let maximumArcVelocity: CGFloat
    let incomingVelocityInfluence: CGFloat
    let minikReactionInterval: TimeInterval
    let minikMaximumReach: CGFloat
    let minikPredictionAmount: CGFloat
    let minikAimError: CGFloat
    let minikErrorProbability: Double
    let minikPoorContactProbability: Double
    let minikCornerPreference: CGFloat
    let minikReturnSpeedMultiplier: CGFloat
    let minikForehandPreference: Double
    let minikServeFaultProbability: Double

    static func values(for difficulty: PingPongDifficulty) -> PingPongTuning {
        switch difficulty {
        case .starter:
            return PingPongTuning(
                tapSpatialTolerance: 0.22,
                tapTimingWindow: 0.52,
                tapTimingQualityExponent: 0.72,
                swipeCollisionForgiveness: 0.18,
                swipeVelocityScale: 0.18,
                minimumSwipeSpeed: 0.20,
                maximumSwipeSpeed: 0.78,
                serveAssistance: 1,
                ballBaseSpeed: 0.40,
                rallySpeedGrowth: 0.005,
                maximumBallSpeed: 0.58,
                gravity: 3.6,
                bounceRestitution: 0.54,
                netHeight: 0.075,
                netClearanceVelocityTarget: 1.30,
                maximumArcVelocity: 1.82,
                incomingVelocityInfluence: 0.08,
                minikReactionInterval: 0.32,
                minikMaximumReach: 0.24,
                minikPredictionAmount: 0.50,
                minikAimError: 0.16,
                minikErrorProbability: 0.24,
                minikPoorContactProbability: 0.24,
                minikCornerPreference: 0.08,
                minikReturnSpeedMultiplier: 0.86,
                minikForehandPreference: 0.82,
                minikServeFaultProbability: 0.12
            )
        case .easy:
            return PingPongTuning(
                tapSpatialTolerance: 0.15,
                tapTimingWindow: 0.36,
                tapTimingQualityExponent: 0.86,
                swipeCollisionForgiveness: 0.13,
                swipeVelocityScale: 0.30,
                minimumSwipeSpeed: 0.24,
                maximumSwipeSpeed: 0.96,
                serveAssistance: 0.92,
                ballBaseSpeed: 0.50,
                rallySpeedGrowth: 0.012,
                maximumBallSpeed: 0.78,
                gravity: 3.8,
                bounceRestitution: 0.55,
                netHeight: 0.078,
                netClearanceVelocityTarget: 1.27,
                maximumArcVelocity: 1.78,
                incomingVelocityInfluence: 0.10,
                minikReactionInterval: 0.28,
                minikMaximumReach: 0.29,
                minikPredictionAmount: 0.62,
                minikAimError: 0.12,
                minikErrorProbability: 0.13,
                minikPoorContactProbability: 0.18,
                minikCornerPreference: 0.14,
                minikReturnSpeedMultiplier: 0.94,
                minikForehandPreference: 0.74,
                minikServeFaultProbability: 0.08
            )
        case .medium:
            return PingPongTuning(
                tapSpatialTolerance: 0.105,
                tapTimingWindow: 0.25,
                tapTimingQualityExponent: 1.02,
                swipeCollisionForgiveness: 0.095,
                swipeVelocityScale: 0.38,
                minimumSwipeSpeed: 0.28,
                maximumSwipeSpeed: 1.10,
                serveAssistance: 0.68,
                ballBaseSpeed: 0.60,
                rallySpeedGrowth: 0.018,
                maximumBallSpeed: 0.94,
                gravity: 4.0,
                bounceRestitution: 0.56,
                netHeight: 0.08,
                netClearanceVelocityTarget: 1.24,
                maximumArcVelocity: 1.74,
                incomingVelocityInfluence: 0.13,
                minikReactionInterval: 0.22,
                minikMaximumReach: 0.35,
                minikPredictionAmount: 0.76,
                minikAimError: 0.075,
                minikErrorProbability: 0.065,
                minikPoorContactProbability: 0.09,
                minikCornerPreference: 0.25,
                minikReturnSpeedMultiplier: 1.02,
                minikForehandPreference: 0.62,
                minikServeFaultProbability: 0.04
            )
        case .hard:
            return PingPongTuning(
                tapSpatialTolerance: 0.075,
                tapTimingWindow: 0.18,
                tapTimingQualityExponent: 1.18,
                swipeCollisionForgiveness: 0.072,
                swipeVelocityScale: 0.44,
                minimumSwipeSpeed: 0.32,
                maximumSwipeSpeed: 1.22,
                serveAssistance: 0.42,
                ballBaseSpeed: 0.68,
                rallySpeedGrowth: 0.024,
                maximumBallSpeed: 1.08,
                gravity: 4.2,
                bounceRestitution: 0.57,
                netHeight: 0.082,
                netClearanceVelocityTarget: 1.21,
                maximumArcVelocity: 1.70,
                incomingVelocityInfluence: 0.16,
                minikReactionInterval: 0.16,
                minikMaximumReach: 0.41,
                minikPredictionAmount: 0.88,
                minikAimError: 0.042,
                minikErrorProbability: 0.025,
                minikPoorContactProbability: 0.025,
                minikCornerPreference: 0.34,
                minikReturnSpeedMultiplier: 1.09,
                minikForehandPreference: 0.54,
                minikServeFaultProbability: 0.02
            )
        }
    }
}

enum PingPongAssetNames {
    static let arena = "ping_pong_arena"
    static let table = "ping_pong_table"
    static let ball = "ping_pong_ball"
    static let starterPaddle = "ping_pong_player_starter_paddle"
    static let minikLeftReady = "minik_ping_pong_left_ready"
    static let minikLeftStrike = "minik_ping_pong_left_strike"
    static let minikRightReady = "minik_ping_pong_right_ready"
    static let minikRightStrike = "minik_ping_pong_right_strike"
    static let minikPong = "minik_pong"

    static func playerPaddle(
        difficulty: PingPongDifficulty,
        side: PingPongPaddleSide
    ) -> String {
        if difficulty == .starter {
            return starterPaddle
        }

        let suffix = side == .backhand ? "backhand" : "forehand"
        return "ping_pong_player_\(difficulty.rawValue)_\(suffix)"
    }

    static func minikPose(side: PingPongPaddleSide, striking: Bool) -> String {
        switch (side, striking) {
        case (.backhand, false): return minikLeftReady
        case (.backhand, true): return minikLeftStrike
        case (.forehand, false): return minikRightReady
        case (.forehand, true): return minikRightStrike
        }
    }
}

enum PingPongTableGeometry {
    static let tableXRange: ClosedRange<CGFloat> = 0...1
    static let tableYRange: ClosedRange<CGFloat> = 0...1
    static let netY: CGFloat = 0.5
    static let childStrikeYRange: ClosedRange<CGFloat> = 0.72...1

    static func isInsideTable(_ point: CGPoint) -> Bool {
        tableXRange.contains(point.x) && tableYRange.contains(point.y)
    }

    static func isInsideChildStrikeZone(_ point: CGPoint) -> Bool {
        tableXRange.contains(point.x) && childStrikeYRange.contains(point.y)
    }

    static func isOnSide(_ point: CGPoint, of participant: PingPongParticipant) -> Bool {
        participant == .child ? point.y > netY : point.y < netY
    }
}

enum PingPongServeInput {
    static func acceptsTap(at tablePoint: CGPoint?) -> Bool {
        guard let tablePoint else { return false }
        return PingPongTableGeometry.isInsideTable(tablePoint)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

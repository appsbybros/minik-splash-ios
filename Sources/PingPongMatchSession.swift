import Foundation

struct PingPongMatchSession: Equatable, Sendable {
    let difficulty: PingPongDifficulty
    let controlMode: PingPongControlMode?
    let targetScore: Int

    private(set) var childScore: Int
    private(set) var minikScore: Int
    private(set) var currentServer: PingPongParticipant
    private(set) var completedRallies: Int
    private(set) var winner: PingPongParticipant?

    init(
        difficulty: PingPongDifficulty,
        controlMode: PingPongControlMode? = .tap,
        targetScore: Int = 7
    ) {
        self.difficulty = difficulty
        self.controlMode = difficulty.supportsControlMode ? (controlMode ?? .tap) : nil
        self.targetScore = difficulty.resolvedTarget(targetScore)
        self.childScore = 0
        self.minikScore = 0
        self.currentServer = difficulty == .starter ? .minik : .child
        self.completedRallies = 0
        self.winner = nil
    }

    var isComplete: Bool { winner != nil }

    var requiresTwoPointLead: Bool {
        difficulty == .medium || difficulty == .hard
    }

    func score(for participant: PingPongParticipant) -> Int {
        participant == .child ? childScore : minikScore
    }

    @discardableResult
    mutating func awardPoint(to participant: PingPongParticipant) -> Bool {
        guard winner == nil else {
            return false
        }

        if participant == .child {
            childScore += 1
        } else {
            minikScore += 1
        }
        completedRallies += 1

        if hasWon(participant) {
            winner = participant
            return true
        }

        updateServerAfterCompletedRally()
        return true
    }

    mutating func startNextMatch() {
        childScore = 0
        minikScore = 0
        currentServer = difficulty == .starter ? .minik : .child
        completedRallies = 0
        winner = nil
    }

    private func hasWon(_ participant: PingPongParticipant) -> Bool {
        let participantScore = score(for: participant)
        let opponentScore = score(for: participant.opponent)
        guard participantScore >= targetScore else {
            return false
        }
        return !requiresTwoPointLead || participantScore - opponentScore >= 2
    }

    private mutating func updateServerAfterCompletedRally() {
        switch difficulty {
        case .starter:
            currentServer = .minik
        case .easy:
            currentServer = .child
        case .medium, .hard:
            if childScore >= targetScore - 1, minikScore >= targetScore - 1 {
                currentServer = currentServer.opponent
            } else {
                let serviceGroup = (completedRallies / 2) % 2
                currentServer = serviceGroup == 0 ? .child : .minik
            }
        }
    }
}

import Foundation

enum MathLevelMode: String, Codable, Hashable, Sendable {
    case automatic
    case manual
}

enum MathLevelPhase: String, Codable, Hashable, Sendable {
    case calibration
    case stable
    case promotionProbation
}

struct MathLevelTuning: Hashable, Sendable {
    let calibrationAttempts: Int
    let promotionStreak: Int
    let masteryWindowSize: Int
    let masteryWindowCorrect: Int
    let demotionStreak: Int
    let demotionWindowCorrectMaximum: Int
    let probationAttempts: Int
    let probationFailures: Int
    let cooldownAttempts: Int
    let verySlowResponseSeconds: Double

    static let productDefault = MathLevelTuning(
        calibrationAttempts: 3,
        promotionStreak: 8,
        masteryWindowSize: 20,
        masteryWindowCorrect: 18,
        demotionStreak: 7,
        demotionWindowCorrectMaximum: 8,
        probationAttempts: 6,
        probationFailures: 4,
        cooldownAttempts: 10,
        verySlowResponseSeconds: 120
    )
}

enum MathLevelEligibilityPolicy {
    static let gradedFamilies: Set<ActivityFamily> = [
        .pairs,
        .buildNumber,
        .buildQuantity,
        .multipleChoice,
        .buildMath,
        .mixed,
        .soccer,
        .tower,
        .memory
    ]

    static func affectsAutomaticLevel(_ family: ActivityFamily) -> Bool {
        gradedFamilies.contains(family)
    }
}

struct MathActivityTimeBaseline: Codable, Hashable, Sendable {
    private(set) var sampleCount: Int = 0
    private(set) var meanSeconds: Double = 0

    mutating func record(seconds: Double) {
        guard seconds >= 0, seconds.isFinite else { return }
        sampleCount += 1
        meanSeconds += (seconds - meanSeconds) / Double(sampleCount)
    }
}

struct MathLevelState: Codable, Hashable, Sendable {
    var mode: MathLevelMode
    var activeLevelID: MathCurriculumLevelID
    var phase: MathLevelPhase
    var previousLevelID: MathCurriculumLevelID?
    var firstAttemptWindow: [Bool]
    var consecutiveCorrect: Int
    var consecutiveUnsuccessful: Int
    var phaseAttemptCount: Int
    var phaseFailureCount: Int
    var cooldownRemaining: Int
    var timeBaselines: [ActivityFamily: MathActivityTimeBaseline]
    var verySlowSignalCount: Int

    static var firstRun: MathLevelState {
        MathLevelState(
            mode: .automatic,
            activeLevelID: .m1,
            phase: .calibration,
            previousLevelID: nil,
            firstAttemptWindow: [],
            consecutiveCorrect: 0,
            consecutiveUnsuccessful: 0,
            phaseAttemptCount: 0,
            phaseFailureCount: 0,
            cooldownRemaining: 0,
            timeBaselines: [:],
            verySlowSignalCount: 0
        )
    }
}

struct MathLevelController: Sendable {
    private(set) var state: MathLevelState
    let tuning: MathLevelTuning
    let implementationReadyLevelIDs: Set<MathCurriculumLevelID>

    init(
        state: MathLevelState = .firstRun,
        tuning: MathLevelTuning = .productDefault,
        implementationReadyLevelIDs: Set<MathCurriculumLevelID> = [.m1, .m2, .m3, .m4, .m5, .m6, .m7, .m8, .m9, .m10]
    ) {
        self.tuning = tuning
        self.implementationReadyLevelIDs = implementationReadyLevelIDs
        self.state = state
        if state.mode == .automatic {
            self.state.activeLevelID = clampedReadyLevel(state.activeLevelID)
        }
    }

    mutating func setManualLevel(_ levelID: MathCurriculumLevelID) {
        state.mode = .manual
        state.activeLevelID = levelID
        resetEvidence(phase: .stable)
    }

    mutating func returnToAutomatic() {
        state.mode = .automatic
        state.activeLevelID = clampedReadyLevel(state.activeLevelID)
        state.previousLevelID = nil
        resetEvidence(phase: .calibration)
    }

    mutating func record(_ attempt: ActivityAttemptData) {
        guard state.mode == .automatic,
              attempt.isFirstAttempt,
              attempt.mathLevelID == state.activeLevelID,
              MathLevelEligibilityPolicy.affectsAutomaticLevel(attempt.activityFamily) else {
            return
        }

        if let seconds = attempt.responseDurationSeconds {
            var baseline = state.timeBaselines[attempt.activityFamily] ?? MathActivityTimeBaseline()
            baseline.record(seconds: seconds)
            state.timeBaselines[attempt.activityFamily] = baseline
            if seconds > tuning.verySlowResponseSeconds {
                state.verySlowSignalCount += 1
            }
        }

        let correct = attempt.result == .correct
        state.phaseAttemptCount += 1
        if correct {
            state.consecutiveCorrect += 1
            state.consecutiveUnsuccessful = 0
        } else {
            state.consecutiveCorrect = 0
            state.consecutiveUnsuccessful += 1
            state.phaseFailureCount += 1
        }
        state.firstAttemptWindow.append(correct)
        if state.firstAttemptWindow.count > tuning.masteryWindowSize {
            state.firstAttemptWindow.removeFirst(
                state.firstAttemptWindow.count - tuning.masteryWindowSize
            )
        }

        switch state.phase {
        case .calibration:
            evaluateCalibrationIfReady()
        case .promotionProbation:
            evaluateProbationIfReady()
        case .stable:
            evaluateStableAdaptation()
        }
    }

    private mutating func evaluateCalibrationIfReady() {
        guard state.phaseAttemptCount >= tuning.calibrationAttempts else { return }
        let correct = state.firstAttemptWindow.suffix(tuning.calibrationAttempts).filter { $0 }.count
        let offset = correct == tuning.calibrationAttempts ? 2 : correct == 2 ? 1 : -1
        if offset > 0 {
            promote(by: offset)
        } else if offset < 0 {
            changeLevel(by: offset, phase: .stable)
        } else {
            resetEvidence(phase: .stable)
        }
    }

    private mutating func evaluateProbationIfReady() {
        guard state.phaseAttemptCount >= tuning.probationAttempts else { return }
        if state.phaseFailureCount >= tuning.probationFailures,
           let previous = state.previousLevelID {
            state.activeLevelID = clampedReadyLevel(previous)
        }
        state.previousLevelID = nil
        state.cooldownRemaining = tuning.cooldownAttempts
        resetEvidence(phase: .stable, preservingCooldown: true)
    }

    private mutating func evaluateStableAdaptation() {
        let severeFailure = state.consecutiveUnsuccessful >= tuning.demotionStreak
        if state.cooldownRemaining > 0 {
            state.cooldownRemaining -= 1
            if severeFailure { changeLevel(by: -1, phase: .stable) }
            return
        }

        let fullWindow = state.firstAttemptWindow.count == tuning.masteryWindowSize
        let correctInWindow = state.firstAttemptWindow.filter { $0 }.count
        if state.consecutiveCorrect >= tuning.promotionStreak
            || (fullWindow && correctInWindow >= tuning.masteryWindowCorrect) {
            promote(by: 1)
        } else if severeFailure
                    || (fullWindow && correctInWindow <= tuning.demotionWindowCorrectMaximum) {
            changeLevel(by: -1, phase: .stable)
        }
    }

    private mutating func promote(by offset: Int) {
        let original = state.activeLevelID
        changeLevel(by: offset, phase: .promotionProbation)
        if state.activeLevelID == original {
            state.previousLevelID = nil
            resetEvidence(phase: .stable)
        } else {
            state.previousLevelID = original
        }
    }

    private mutating func changeLevel(by offset: Int, phase: MathLevelPhase) {
        let levels = MathCurriculumPolicy.levels.map(\.id)
        guard let currentIndex = levels.firstIndex(of: state.activeLevelID) else { return }
        let targetIndex = min(max(currentIndex + offset, 0), levels.count - 1)
        state.activeLevelID = clampedReadyLevel(levels[targetIndex])
        state.cooldownRemaining = phase == .stable ? tuning.cooldownAttempts : 0
        resetEvidence(phase: phase, preservingCooldown: true)
    }

    private func clampedReadyLevel(_ requested: MathCurriculumLevelID) -> MathCurriculumLevelID {
        let levels = MathCurriculumPolicy.levels.map(\.id)
        let requestedIndex = levels.firstIndex(of: requested) ?? 0
        return levels.enumerated()
            .filter { $0.offset <= requestedIndex && implementationReadyLevelIDs.contains($0.element) }
            .last?.element
            ?? levels.first(where: implementationReadyLevelIDs.contains)
            ?? .m1
    }

    private mutating func resetEvidence(
        phase: MathLevelPhase,
        preservingCooldown: Bool = false
    ) {
        state.phase = phase
        state.firstAttemptWindow = []
        state.consecutiveCorrect = 0
        state.consecutiveUnsuccessful = 0
        state.phaseAttemptCount = 0
        state.phaseFailureCount = 0
        state.verySlowSignalCount = 0
        if !preservingCooldown { state.cooldownRemaining = 0 }
    }
}

final class LocalMathLevelRepository {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "minik.math-level-state.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func load() -> MathLevelState {
        guard let data = userDefaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(MathLevelState.self, from: data) else {
            return .firstRun
        }
        return state
    }

    func save(_ state: MathLevelState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

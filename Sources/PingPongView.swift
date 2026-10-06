import SpriteKit
import SwiftUI
import UIKit

struct PingPongView: View {
    private enum Phase: Equatable {
        case setup
        case playing
        case result
    }

    @State private var selectedDifficulty: PingPongDifficulty
    @State private var selectedControlMode: PingPongControlMode
    @State private var selectedVisualStyle: PingPongVisualStyle
    @State private var selectedTarget: Int
    @State private var match: PingPongMatchSession
    @State private var phase: Phase = .setup
    @State private var statusText = "Choose how you want to play"
    @State private var scene = PingPongScene()
    @State private var nextRallyTask: Task<Void, Never>?
    @State private var resultReactionScale: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var appScenePhase

    private let preferences: PingPongPreferencesProviding
    private let onExit: (() -> Void)?
    private let onCompletedMatch: () -> Void

    init(
        preferences: PingPongPreferencesProviding = PingPongPreferences(),
        onExit: (() -> Void)? = nil,
        onCompletedMatch: @escaping () -> Void = {}
    ) {
        let difficulty = preferences.selectedDifficulty
        let mode = preferences.selectedControlMode
        let target = preferences.selectedTarget(for: difficulty)
        self.preferences = preferences
        self.onExit = onExit
        self.onCompletedMatch = onCompletedMatch
        _selectedDifficulty = State(initialValue: difficulty)
        _selectedControlMode = State(initialValue: mode)
        _selectedVisualStyle = State(initialValue: preferences.selectedVisualStyle)
        _selectedTarget = State(initialValue: target)
        _match = State(initialValue: PingPongMatchSession(
            difficulty: difficulty,
            controlMode: mode,
            targetScore: target
        ))
    }

    var body: some View {
        Group {
            switch phase {
            case .setup:
                configurationView(isResult: false)
            case .playing:
                gameplayView
            case .result:
                configurationView(isResult: true)
            }
        }
        .onAppear(perform: bindScene)
        .onChange(of: selectedDifficulty) { _, newValue in
            selectedTarget = preferences.selectedTarget(for: newValue)
        }
        .onChange(of: appScenePhase) { _, newValue in
            if newValue == .active {
                scene.resumeGameplay()
            } else {
                scene.suspendGameplay()
            }
        }
        .onDisappear(perform: stopGameplayWork)
    }

    private func configurationView(isResult: Bool) -> some View {
        ZStack {
            if selectedVisualStyle == .retro {
                PingPongRetroPalette.backgroundGradient
                    .ignoresSafeArea()
            } else {
                Image(PingPongAssetNames.arena)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 20) {
                    header

                    VStack(spacing: 18) {
                        if selectedVisualStyle == .retro {
                            if !isResult {
                                Image(PingPongAssetNames.minikPong)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 132)
                                    .accessibilityHidden(true)
                            }
                        } else {
                            Image(systemName: "figure.table.tennis")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(Color(red: 0.08, green: 0.55, blue: 0.62))
                        }

                        Text(isResult ? resultTitle : "Ping Pong")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        if isResult {
                            Image(
                                selectedVisualStyle == .retro
                                    ? PingPongAssetNames.minikPong
                                    : match.winner == .child
                                    ? PingPongAssetNames.minikRightReady
                                    : PingPongAssetNames.minikRightStrike
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(height: 112)
                            .scaleEffect(resultReactionScale)
                            .accessibilityHidden(true)
                            .task(id: match.completedRallies) {
                                guard !reduceMotion else { return }
                                resultReactionScale = 0.92
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                                    resultReactionScale = 1.08
                                }
                                try? await Task.sleep(nanoseconds: 230_000_000)
                                withAnimation(.easeOut(duration: 0.14)) {
                                    resultReactionScale = 1
                                }
                            }

                            Text(verbatim: "\(match.childScore) – \(match.minikScore)")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(resultColor)
                                .accessibilityLabel(
                                    localizedFormat(
                                        "Final score. You %lld, Minik %lld",
                                        Int64(match.childScore),
                                        Int64(match.minikScore)
                                    )
                                )
                        } else {
                            Text("Choose your match settings")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        configurationControls

                        Button(isResult
                            ? String(localized: "Play Again")
                            : String(localized: "Start Match"), action: startMatch)
                            .buttonStyle(MinikPrimaryActionStyle())
                            .accessibilityHint("Starts a new match with the selected settings")
                    }
                    .padding(24)
                    .frame(maxWidth: 560)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32)
                            .strokeBorder(.white.opacity(0.72), lineWidth: 1.2)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var configurationControls: some View {
        VStack(spacing: 14) {
            configurationRow(title: String(localized: "Mode")) {
                // Segmented when every label fits untruncated; otherwise a menu.
                ViewThatFits(in: .horizontal) {
                    visualStylePicker
                        .pickerStyle(.segmented)
                        .fixedSize()
                    visualStylePicker
                        .pickerStyle(.menu)
                }
                .accessibilityHint("Selects the look of the game")
            }

            configurationRow(title: "Difficulty") {
                Picker("Difficulty", selection: $selectedDifficulty) {
                    ForEach(PingPongDifficulty.allCases) { difficulty in
                        Text(difficulty.displayName).tag(difficulty)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityHint("Selects difficulty for the next match")
            }

            if selectedDifficulty.supportsControlMode {
                configurationRow(title: String(localized: "Controls")) {
                    Picker("Controls", selection: $selectedControlMode) {
                        ForEach(PingPongControlMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("Selects Tap or Swipe control for the next match")
                }
            }

            configurationRow(title: "Target") {
                Picker("Target score", selection: $selectedTarget) {
                    ForEach(selectedDifficulty.allowedTargets, id: \.self) { target in
                        Text(verbatim: "\(target)").tag(target)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityHint("Selects the score needed to win the next match")
            }
        }
    }

    private var visualStylePicker: some View {
        Picker("Mode", selection: $selectedVisualStyle) {
            ForEach(PingPongVisualStyle.allCases) { style in
                Text(style.displayName).tag(style)
            }
        }
    }

    private func configurationRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.headline)
            Spacer()
            content()
                .frame(maxWidth: 230)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
    }

    private var gameplayView: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Ping Pong table. Timing and position control the return.")
                .accessibilityValue(statusText)
                .accessibilityAction(named: "Return left") {
                    scene.performAccessibilityReturn(side: .backhand)
                }
                .accessibilityAction(named: "Return right") {
                    scene.performAccessibilityReturn(side: .forehand)
                }

            VStack(spacing: 12) {
                gameplayHeader
                Spacer()
                Text(statusText)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.42))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(.ultraThickMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .accessibilityLabel(statusText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
    }

    private var header: some View {
        HStack {
            if let onExit {
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Close Ping Pong")
            }
            Spacer()
        }
    }

    private var gameplayHeader: some View {
        HStack(spacing: 10) {
            if onExit != nil {
                Button(action: exitGame) {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .frame(width: 44, height: 44)
                        .background(.ultraThickMaterial, in: Circle())
                }
                .accessibilityLabel("Close Ping Pong")
            }

            scorePill(title: "You", score: match.childScore)
            scorePill(title: "Minik", score: match.minikScore)

            VStack(alignment: .trailing, spacing: 2) {
                Text(match.difficulty.displayName)
                if let mode = match.controlMode {
                    Text(mode.displayName)
                }
                Text(localizedFormat("First to %lld", Int64(match.targetScore)))
                Text(localizedFormat("%@ serves", match.currentServer.displayName))
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.42))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        }
    }

    private func scorePill(title: String, score: Int) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
            Text(verbatim: "\(score)")
                .font(.system(.title2, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.42))
        .frame(minWidth: 54)
        .padding(.vertical, 7)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedFormat("%@ score %lld", title, Int64(score)))
    }

    private var resultTitle: String {
        match.winner == .child
            ? String(localized: "You win!")
            : String(localized: "Minik wins")
    }

    private var resultColor: Color {
        match.winner == .child
            ? Color(red: 0.08, green: 0.55, blue: 0.30)
            : Color(red: 0.66, green: 0.22, blue: 0.37)
    }

    private func bindScene() {
        scene.onStatusChanged = { message in
            statusText = message
        }
        scene.onPointResolved = { resolution in
            handlePoint(resolution)
        }
    }

    private func startMatch() {
        nextRallyTask?.cancel()
        let target = selectedDifficulty.resolvedTarget(selectedTarget)
        preferences.selectedDifficulty = selectedDifficulty
        preferences.selectedVisualStyle = selectedVisualStyle
        if selectedDifficulty.supportsControlMode {
            preferences.selectedControlMode = selectedControlMode
        }
        preferences.setSelectedTarget(target, for: selectedDifficulty)

        match = PingPongMatchSession(
            difficulty: selectedDifficulty,
            controlMode: selectedControlMode,
            targetScore: target
        )
        statusText = "Get ready"
        phase = .playing
        scene.configure(
            difficulty: selectedDifficulty,
            controlMode: selectedDifficulty.supportsControlMode ? selectedControlMode : nil,
            reduceMotion: reduceMotion,
            visualStyle: selectedVisualStyle
        )
        scene.startRally(server: match.currentServer)
        announce(localizedFormat(
            "New %@ match. %@ serves.",
            selectedDifficulty.displayName,
            match.currentServer.displayName
        ))
    }

    private func handlePoint(_ resolution: PingPongRallyResolution) {
        guard phase == .playing, match.awardPoint(to: resolution.pointWinner) else { return }
        let scoreAnnouncement = localizedFormat(
            "%@ scores. You %lld, Minik %lld.",
            resolution.pointWinner.displayName,
            Int64(match.childScore),
            Int64(match.minikScore)
        )
        announce(scoreAnnouncement)

        if match.isComplete {
            scene.cancelGameplay()
            selectedDifficulty = match.difficulty
            if let mode = match.controlMode {
                selectedControlMode = mode
            }
            selectedTarget = match.targetScore
            phase = .result
            onCompletedMatch()
            announce(resultTitle)
            return
        }

        nextRallyTask?.cancel()
        nextRallyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled, phase == .playing else { return }
            scene.startRally(server: match.currentServer)
            announce(localizedFormat("%@ serves", match.currentServer.displayName))
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func localizedFormat(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: String(localized: key), arguments: arguments)
    }

    private func stopGameplayWork() {
        nextRallyTask?.cancel()
        nextRallyTask = nil
        scene.cancelGameplay()
    }

    private func exitGame() {
        stopGameplayWork()
        onExit?()
    }
}

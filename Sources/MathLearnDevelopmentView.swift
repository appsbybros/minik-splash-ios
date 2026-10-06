import SwiftUI

/// Temporary entry point for exercising runnable Math activity slices.
struct MathLearnDevelopmentView: View {
    private enum Screen {
        case menu
        case learn
        case multipleChoice
        case build
        case tower
        case pairs
        case memory
        case soccer
    }

    private let sessionFactory = MathActivitySessionFactory(
        configuration: .configuration(for: .minikMath)
    )
    @State private var screen = Screen.menu
    @State private var selectedLevelID = MathCurriculumPolicy.latestRunnableLevel.id

    @ViewBuilder
    var body: some View {
        switch screen {
        case .menu:
            VStack(spacing: 16) {
                Text("Minik Math")
                    .font(.largeTitle)

                Picker("Math level", selection: $selectedLevelID) {
                    ForEach(MathCurriculumPolicy.runnableLevels) { level in
                        Text(level.title).tag(level.id)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedLevel.subtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                if isSupported(.learn) {
                    Button("Learn") {
                        screen = .learn
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isSupported(.multipleChoice) {
                    Button("Multiple Choice") {
                        screen = .multipleChoice
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isSupported(.build) {
                    Button("Build") {
                        screen = .build
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isSupported(.tower) {
                    Button("Tower") {
                        screen = .tower
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isSupported(.pairs) {
                    Button("Pairs") {
                        screen = .pairs
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isSupported(.memory) {
                    Button("Memory") {
                        screen = .memory
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isSupported(.soccer) {
                    Button("Soccer") {
                        screen = .soccer
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

        case .learn:
            if let session = sessionFactory.makeLearnSession(for: selectedLevelID) {
                LearnView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Learn content unavailable")
            }

        case .multipleChoice:
            if let session = sessionFactory.makeMultipleChoiceSession(for: selectedLevelID) {
                MultipleChoiceView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Multiple choice unavailable")
            }

        case .build:
            if let session = sessionFactory.makeBuildSession(for: selectedLevelID) {
                BuildView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Build unavailable")
            }

        case .tower:
            if let session = sessionFactory.makeTowerSession(for: selectedLevelID) {
                TowerView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Tower unavailable")
            }

        case .pairs:
            if let session = sessionFactory.makePairsSession(for: selectedLevelID) {
                PairsView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Pairs unavailable")
            }

        case .memory:
            if let session = sessionFactory.makeMemorySession(for: selectedLevelID) {
                MemoryView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Memory unavailable")
            }

        case .soccer:
            if let session = sessionFactory.makeSoccerSession(for: selectedLevelID) {
                SoccerView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView(message: "Soccer unavailable")
            }
        }
    }

    private func backToMenu() {
        screen = .menu
    }

    private func isSupported(_ activity: MathActivityKind) -> Bool {
        MathCurriculumPolicy.specification(
            for: activity,
            levelID: selectedLevelID
        ) != nil
    }

    private var selectedLevel: MathCurriculumLevelDescriptor {
        MathCurriculumPolicy.level(for: selectedLevelID)
            ?? MathCurriculumPolicy.latestRunnableLevel
    }

    private func unavailableView(message: LocalizedStringKey) -> some View {
        VStack(spacing: 16) {
            Text(message)

            Button("Menu", action: backToMenu)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

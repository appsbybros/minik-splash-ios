import SwiftUI

/// Temporary entry point for exercising language Learn content.
struct LanguageLearnDevelopmentView: View {
    private enum Screen {
        case menu
        case learn(LanguageIdentifier)
        case multipleChoice(LanguageIdentifier)
        case firstLetterChoices(LanguageIdentifier)
        case firstLetterPictures(LanguageIdentifier)
        case build(LanguageIdentifier)
        case pairs(LanguageIdentifier)
        case letterPairs(LanguageIdentifier)
        case memory(LanguageIdentifier)
        case wordMemory(LanguageIdentifier)
        case imageToWord(LanguageIdentifier)
        case wordToImage(LanguageIdentifier)
        case wordCards(LanguageIdentifier)
        case wordBuild(LanguageIdentifier)
    }

    private let configuration: ProductConfiguration
    private let sessionFactory: LanguageActivitySessionFactory
    @State private var screen = Screen.menu

    init(configuration: ProductConfiguration) {
        self.configuration = configuration
        self.sessionFactory = LanguageActivitySessionFactory(configuration: configuration)
    }

    @ViewBuilder
    var body: some View {
        switch screen {
        case .menu:
            ScrollView {
                VStack(spacing: 16) {
                    Text(configuration.displayName)
                        .font(.largeTitle)

                    if configuration.allowsLearnedLanguage(.english) {
                        languageButtons(for: .english, title: "English")
                    }

                    if configuration.allowsLearnedLanguage(.hebrew) {
                        languageButtons(for: .hebrew, title: "Hebrew")
                    }
                }
                .padding()
            }

        case .learn(let language):
            if let session = sessionFactory.makeLearnSession(for: language) {
                LearnView(
                    session: session,
                    presentation: .language,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .multipleChoice(let language):
            if let session = sessionFactory.makeMultipleChoiceSession(for: language) {
                MultipleChoiceView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView
            }

        case .firstLetterChoices(let language):
            if let session = sessionFactory.makeFirstLetterChoicesSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    presentation: .firstLetterPictureToLetter,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .firstLetterPictures(let language):
            if let session = sessionFactory.makeFirstLetterPicturesSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    presentation: .firstLetterLetterToPicture,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .build(let language):
            if let session = sessionFactory.makeBuildSession(for: language) {
                BuildView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView
            }

        case .pairs(let language):
            if let session = sessionFactory.makePairsSession(for: language) {
                PairsView(
                    session: session,
                    languageSkillID: LanguageSkillIDs.letterWordAssociation,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .letterPairs(let language):
            if let session = sessionFactory.makeLetterPairsSession(for: language) {
                PairsView(
                    session: session,
                    languageSkillID: LanguageSkillIDs.initialLetterAssociation,
                    makeNextSession: {
                        sessionFactory.makeLetterPairsSession(for: language)
                    },
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .memory(let language):
            if let session = sessionFactory.makeMemorySession(for: language) {
                MemoryView(session: session, onComplete: backToMenu, onExit: backToMenu)
            } else {
                unavailableView
            }

        case .wordMemory(let language):
            if let session = sessionFactory.makeWordMemorySession(for: language) {
                MemoryView(
                    session: session,
                    presentation: .languagePicture,
                    makeNextSession: {
                        sessionFactory.makeWordMemorySession(for: language)
                    },
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .imageToWord(let language):
            if let session = sessionFactory.makeImageToWordSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    presentation: .pictureToWord,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .wordToImage(let language):
            if let session = sessionFactory.makeWordToImageSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    presentation: .wordToPicture,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }

        case .wordCards(let language):
            if let session = sessionFactory.makeWordCardsSession(for: language) {
                CardsView(session: session, onExit: backToMenu)
            } else {
                unavailableView
            }

        case .wordBuild(let language):
            if let session = sessionFactory.makeWordBuildSession(for: language) {
                BuildView(
                    session: session,
                    presentation: .word,
                    onComplete: backToMenu,
                    onExit: backToMenu
                )
            } else {
                unavailableView
            }
        }
    }

    @ViewBuilder
    private func languageButtons(for language: LanguageIdentifier, title: String) -> some View {
        Button(localizedTitle("Learn %@", title)) {
            screen = .learn(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Multiple Choice %@", title)) {
            screen = .multipleChoice(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("First Letter Choices %@", title)) {
            screen = .firstLetterChoices(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("First Letter Pictures %@", title)) {
            screen = .firstLetterPictures(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Build %@", title)) {
            screen = .build(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Word Build %@", title)) {
            screen = .wordBuild(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Pairs %@", title)) {
            screen = .pairs(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Letter Pairs %@", title)) {
            screen = .letterPairs(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Memory %@", title)) {
            screen = .memory(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Word Memory %@", title)) {
            screen = .wordMemory(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Image → Word %@", title)) {
            screen = .imageToWord(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Word → Image %@", title)) {
            screen = .wordToImage(language)
        }
        .buttonStyle(.borderedProminent)

        Button(localizedTitle("Word Cards %@", title)) {
            screen = .wordCards(language)
        }
        .buttonStyle(.borderedProminent)
    }

    private func localizedTitle(_ key: String.LocalizationValue, _ title: String) -> String {
        String(format: String(localized: key), title)
    }

    private func backToMenu() {
        screen = .menu
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Text("Learn content unavailable")

            Button("Menu", action: backToMenu)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

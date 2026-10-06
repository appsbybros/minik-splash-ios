"""Windows regression guard for the Android Build composition and typed clue/reward boundaries."""
import argparse
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]

def validate(sources):
    required = {
        "BuildView.swift": ["if isLanguageBuild {", "LanguageBuildPage(", "LanguageWordBuildClue.make(",
            "await speechPlayer.waitUntilFinished()", "session.currentChallenge.id == challengeID",
            "!Task.isCancelled", "guard languageFeedback == .correct else { return 1.4 }", "languageFeedbackID == id",
            "languagePresentationIndex", "presentationIndex: languagePresentationIndex",
            "shouldRecordLanguageAttempt", "onWordCompleted(LanguageWordCompletion(",
            "hadIncorrectLetter: session.hasIncorrectAttempt", "makeNextSession?()"],
        "LanguageBuildPage.swift": ["LanguageActivityScreen(panelStyle: .rounded, minimumContentHeight: minimumHeight)",
            "let order = session.tokenPresentationOrder", ".opacity(selected ? 0 : 1)",
            ".accessibilityHidden(selected)", "session.builtDisplayText", ".strokeBorder(LanguageSkyPalette.tileRim, lineWidth: 2)",
            "LanguagePracticeReaction(", ".allowsHitTesting(false)", "LanguagePracticeStats(",
            "Tap the letters in the right order to form the word"],
        "LanguageWordBuildPresentation.swift": ["content.contentItemID", "item: item",
            'hostCode == "he" ? .hebrew : .english', "sameLanguage ? nil",
            'hostCode == "en" || hostCode == "he" ? nil', "targetText.language"],
        "LanguageWordPracticeRewardService.swift": ["LanguageChoiceRewardMapper.rewardEvent",
            "processedEventIDs.contains(completion.id)", "processedEventIDs.contains(event.id)",
            "id: event.id", "pointsDelta: 0", "streakEffect: .unchanged",
            "completion.hadIncorrectLetter ? 0", "reason: .activityCompleted",
            "streakEffect: .increment", "cleanWordRun = nextRun"],
        "BuildSession.swift": ["hasIncorrectAttempt = true", "&& hasIncorrectAttempt",
            "hasIncorrectAttempt = false", "selectedRepresentation == expectedRepresentation"],
        "LanguageMixedPracticeView.swift": ["onWordCompleted: onWordCompleted", "progressActivityFamily: .mixed"],
        "LanguageBuildParityTests.swift": ["processedEventIDs.contains(wrong.id)",
            "let recreatedService = LanguageWordPracticeRewardService(repository: store)",
            "Persisted rejection identity must survive service recreation"],
        "LanguageOrderedTokenAttemptTrackerTests.swift": [
            "testRepeatedSemanticTokenInNewPresentationStartsAtAttemptOne"],
    }
    errors = []
    for name, fragments in required.items():
        for fragment in fragments:
            if fragment not in sources[name]: errors.append(name + ": missing " + fragment)
    page = sources["LanguageBuildPage.swift"]
    for bad in ['Text("Your word")', "placeholderToken", 'Text("Choose tokens', "progressLabel:",
                "MinikPracticeScreen(", "MinikFeedbackBadge(", "MinikPracticeSurface("]:
        if bad in page: errors.append("Build composition regressed to " + bad)
    return errors

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--self-test", action="store_true"); args = parser.parse_args()
    names = ["BuildView.swift", "LanguageBuildPage.swift", "LanguageWordBuildPresentation.swift",
             "LanguageWordPracticeRewardService.swift", "BuildSession.swift", "LanguageMixedPracticeView.swift",
             "LanguageBuildParityTests.swift", "LanguageOrderedTokenAttemptTrackerTests.swift"]
    sources = {
        n: (ROOT / ("Tests/ProductConfigurationTests" if n.endswith("Tests.swift") else "Sources") / n)
            .read_text(encoding="utf-8")
        for n in names
    }
    errors = validate(sources)
    if args.self_test:
        mutations = [
            ("BuildView.swift", "await speechPlayer.waitUntilFinished()", ""),
            ("BuildView.swift", "session.currentChallenge.id == challengeID", "true"),
            ("BuildView.swift", "languageFeedbackID == id", "true"),
            ("BuildView.swift", "guard languageFeedback == .correct else { return 1.4 }",
             "guard languageFeedback == .correct else { return 0 }"),
            ("BuildView.swift", "presentationIndex: languagePresentationIndex", "presentationIndex: session.currentChallengeIndex + 1"),
            ("LanguageBuildPage.swift", "let order = session.tokenPresentationOrder", "let order = session.selectedTokenIDs"),
            ("LanguageBuildPage.swift", ".opacity(selected ? 0 : 1)", ".opacity(1)"),
            ("LanguageWordBuildPresentation.swift", "sameLanguage ? nil", "false ? nil"),
            ("LanguageWordPracticeRewardService.swift", "processedEventIDs.contains(completion.id)", "processedEventIDs.isEmpty"),
            ("LanguageWordPracticeRewardService.swift", "processedEventIDs.contains(event.id)", "processedEventIDs.isEmpty"),
            ("LanguageWordPracticeRewardService.swift", "completion.hadIncorrectLetter ? 0", "false ? 0"),
            ("BuildSession.swift", "&& hasIncorrectAttempt", "&& lastSelectionResult == .incorrect"),
            ("LanguageBuildParityTests.swift", "Persisted rejection identity must survive service recreation",
             "Process-local rejection identity only"),
            ("LanguageOrderedTokenAttemptTrackerTests.swift",
             "testRepeatedSemanticTokenInNewPresentationStartsAtAttemptOne",
             "testRepeatedSemanticTokenInNewPresentationKeepsAttemptIndex"),
        ]
        for name, before, after in mutations:
            changed = dict(sources); assert before in changed[name]; changed[name] = changed[name].replace(before, after)
            assert validate(changed), before
        print("BUILD_NEGATIVE_FIXTURES_REJECTED=" + str(len(mutations)))
    print("LANGUAGE_BUILD_PARITY_ERRORS=" + str(len(errors)))
    for error in errors: print(error)
    print("STATIC_ONLY: typed source boundaries; native XCTest/rendering/audio remain pending.")
    return bool(errors)
if __name__ == "__main__": sys.exit(main())

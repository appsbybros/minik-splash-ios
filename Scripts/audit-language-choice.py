"""Source/asset regression checks for all four live Language choice routes.
This does not typecheck Swift or claim a rendered visual result.
"""
import argparse
import csv
import hashlib
import json
import pathlib
import sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]

def validate(sources):
    checks = {
        "MultipleChoiceView.swift": [
            "if isLanguageChoice {", "LanguageChoicePage(", "standardBody",
            "usesPictureAnswers", "usesPicturePrompt",
            "await speechPlayer.waitUntilFinished()",
            "PendingTaskKey(action: session.pendingAction, active: scenePhase == .active)",
            "scenePhase == .active", "!Task.isCancelled",
            "canSkip: session.canAdvanceManually,",
            "MultipleChoiceAttemptIdentity.itemID(", "onAttempt(attempt)",
            "feedbackSoundPlayer.play(sound)", "enqueuePracticeEncouragement",
        ],
        "LanguageChoicePage.swift": [
            "if pictures {", "VStack(spacing: gap)", "let columns = pictures ? min(2, count) : 1",
            "presentation == .firstLetterPictureToLetter ? 48 : 68",
            "LanguagePanelNavigation(", "LanguagePracticeStats(",
            "LanguagePracticeReaction(", ".allowsHitTesting(false)",
            "interfaceLocaleID.text(presentation.instructionKey)",
            "LanguagePracticePalette.ink", "LanguageAnswerStyle(state: feedback, colorDuration: pictures ? 0.3 : 0.5)",
            "Fredoka-Medium", "LanguageSkyPalette.tileRim",
        ],
        "LearningSpeech.swift": [
            "AVSpeechSynthesizerDelegate", "await withCheckedContinuation",
            "queue.cancelAll()", "guard queue.finish(id)",
            "didFinish utterance:", "didCancel utterance:",
            "nonisolated func speechSynthesizer", "Task { @MainActor [weak self]",
        ],
        "LanguageChoiceRewardMapper.swift": [
            "let skill = attempt.skillID", "LanguageSkillIDs.wordRecognition",
            "LanguageSkillIDs.wordImageAssociation", "LanguageSkillIDs.initialLetterAssociation",
            "attempt.mathLevelID == nil", "id: event.id", "case .skipped: return nil",
        ],
        "LanguagePracticeReaction.swift": [
            "TimelineView(.animation", "LanguageSuccessJump.sample(", "if correct && !reduceMotion",
            "width: 200, height: 265", "MinikVisualAsset.tryAgain",
            "MinikArtworkImage(name: successAsset)\n                        .padding(8)",
            ".rotationEffect(.degrees(sample.rotation), anchor: .bottom)",
        ],
        "MultipleChoiceSessionTests.swift": [
            "testPracticePolicyWrongSelectionCanResetForRetry",
            "XCTAssertTrue(session.canAdvanceManually)",
            ".resetAfterIncorrect(challengeID: challenge.id)",
        ],
    }
    errors = []
    for name, fragments in checks.items():
        for fragment in fragments:
            if fragment not in sources[name]:
                errors.append(name + ": missing " + fragment)
    for bad in ["MinikPracticeScreen(", "MinikPracticeSurface(", "MinikFeedbackBadge(", 'Text("Listen")',
                'Label("Selected"', "progressLabel:", "GridItem(.adaptive"]:
        if bad in sources["LanguageChoicePage.swift"]:
            errors.append("Choice page regressed to " + bad)
    if "canSkip: session.canAdvanceManually &&" in sources["MultipleChoiceView.swift"]:
        errors.append("Choice page hides Android Next during the transient wrong-answer state")
    return errors

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    names = ["MultipleChoiceView.swift", "LanguageChoicePage.swift", "LearningSpeech.swift",
             "LanguageChoiceRewardMapper.swift", "LanguagePracticeReaction.swift",
             "MultipleChoiceSessionTests.swift"]
    sources = {
        n: (ROOT / ("Tests/ProductConfigurationTests" if n.endswith("Tests.swift") else "Sources") / n)
            .read_text(encoding="utf-8")
        for n in names
    }
    errors = validate(sources)
    manifest = ROOT / "docs/language-activity-art-provenance.tsv"
    rows = list(csv.DictReader(manifest.open(encoding="utf-8"), delimiter="\t"))
    catalog = ROOT / "Resources/LanguageActivityArt.xcassets"
    actual_assets = {p.stem for p in catalog.glob("*.imageset")}
    if actual_assets != {row["asset_name"] for row in rows}:
        errors.append("Activity art catalog/provenance inventory mismatch")
    for row in rows:
        original = ROOT / row["android_source"]
        asset = row["asset_name"]
        original_image = Image.open(original).convert("RGBA")
        actual_image = Image.open(catalog / (asset + ".imageset") / (asset + ".png")).convert("RGBA")
        if hashlib.sha256(original.read_bytes()).hexdigest() != row["sha256"]:
            errors.append(asset + ": Android source hash differs")
        if original_image.size != actual_image.size or original_image.tobytes() != actual_image.tobytes():
            errors.append(asset + ": decoded original artwork differs")
    font_rows = list(csv.DictReader((ROOT / "docs/language-font-provenance.tsv").open(encoding="utf-8"), delimiter="\t"))
    for row in font_rows:
        original = (ROOT / row["android_source"]).read_bytes()
        actual = (ROOT / "Resources/LanguageMedia" / row["filename"]).read_bytes()
        if original != actual or hashlib.sha256(actual).hexdigest() != row["sha256"]:
            errors.append("Original Fredoka font differs")
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    if project.count("UIAppFonts: [fredoka_medium.ttf, fredoka_bold.ttf]") != 2 or project.count("path: Resources/LanguageActivityArt.xcassets") != 2:
        errors.append("Both Language targets must bundle/register their original artwork and font")
    if args.self_test:
        mutations = [
            ("MultipleChoiceView.swift", "await speechPlayer.waitUntilFinished()", ""),
            ("MultipleChoiceView.swift", "active: scenePhase == .active", "active: true"),
            ("MultipleChoiceView.swift", "!Task.isCancelled", "true"),
            ("MultipleChoiceView.swift", "canSkip: session.canAdvanceManually,", "canSkip: false,"),
            ("LanguageChoicePage.swift", "VStack(spacing: gap)", "HStack(spacing: gap)"),
            ("LanguageChoicePage.swift", "let columns = pictures ? min(2, count) : 1", "let columns = pictures ? count : 1"),
            ("LanguageChoicePage.swift", ".allowsHitTesting(false)", ".allowsHitTesting(true)"),
            ("LanguageChoicePage.swift", "colorDuration: pictures ? 0.3 : 0.5", "colorDuration: 0"),
            ("LanguageChoiceRewardMapper.swift", "LanguageSkillIDs.wordRecognition", "LanguageSkillIDs.alphabetRecognition"),
            ("LearningSpeech.swift", "guard queue.finish(id)", "guard true"),
            ("LanguagePracticeReaction.swift", "width: 200, height: 265", "width: 48, height: 64"),
            ("LanguagePracticeReaction.swift", ".rotationEffect(.degrees(sample.rotation), anchor: .bottom)",
             ".rotationEffect(.degrees(sample.rotation))"),
            ("MultipleChoiceSessionTests.swift", "XCTAssertTrue(session.canAdvanceManually)",
             "XCTAssertFalse(session.canAdvanceManually)"),
        ]
        for name, old, new in mutations:
            mutated = dict(sources)
            assert old in mutated[name], old
            mutated[name] = mutated[name].replace(old, new)
            assert validate(mutated), old
        print("CHOICE_NEGATIVE_FIXTURES_REJECTED=" + str(len(mutations)))
    print("LANGUAGE_CHOICE_PARITY_ERRORS=" + str(len(errors)))
    for error in errors: print(error)
    print("STATIC_ONLY: native XCTest, speech, gestures and rendered layout remain pending.")
    return bool(errors)

if __name__ == "__main__":
    sys.exit(main())

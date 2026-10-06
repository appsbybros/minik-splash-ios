"""Windows regression guard for the actual Language Pairs production route."""
import argparse
import csv
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

def validate(view, model, visuals, hub):
    errors = []
    requirements = {
        "view": [
            "if isLanguagePairs { languageBody } else { standardBody }",
            "ForEach(session.mixedBoardItems",
            ".opacity(hidden ? 0 : 1)",
            ".accessibilityHidden(hidden)",
            "LanguagePairTileStyle(selected:",
            "MinikVisualAsset.cardsMascot",
            "LanguagePairsPointsCard(",
            ".task(id: LanguagePairTaskKey(transition: pendingLanguagePair, active: scenePhase == .active))",
            "220_000_000", "330_000_000", "430_000_000", "1_300_000_000",
            "pendingLanguagePair == pending",
            "presentationIndex == pending.presentation",
            "!Task.isCancelled",
            "pendingLanguagePair = nil", "lastAudibleLanguagePairID != pending.id",
            "hiddenLanguageGroups = []",
            "speechPlayer.enqueueInterfaceSpeech",
        ],
        "model": ["var mixedBoardItems:", "mixedPresentationOrder.compactMap { byID[$0] }"],
        "visuals": ["LanguageActivityScreen", "panelHeight < 560", "dynamicTypeSize.isAccessibilitySize", ".scrollBounceBehavior(.basedOnSize)",
                    "LanguagePanelNavigation", "MinikVisualAsset.close", "LanguagePairTileStyle"],
        "hub": [r".environment(\.languageRewardState, languageRewards)",
                "languageRewards = ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state("],
    }
    sources = {"view": view, "model": model, "visuals": visuals, "hub": hub}
    for name, fragments in requirements.items():
        for fragment in fragments:
            if fragment not in sources[name]:
                errors.append(name + ": missing " + fragment)
    language = view.split("private var languageBody:", 1)[1].split("private var standardBody:", 1)[0]
    for forbidden in ['Label("Selected"', "MinikPracticeScreen(", "MinikFeedbackBadge(", "continueButton("]:
        if forbidden in language:
            errors.append("Language Pairs regressed to " + forbidden)
    return errors

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    source = lambda n: (ROOT / "Sources" / n).read_text(encoding="utf-8")
    view, model, visuals, hub = [source(n) for n in
        ["PairsView.swift", "PairsSession.swift", "LanguageActivityVisuals.swift", "MinikActivityHubView.swift"]]
    errors = validate(view, model, visuals, hub)
    rows = list(csv.DictReader((ROOT / "docs/language-feedback-audio-provenance.tsv").open(encoding="utf-8"), delimiter="\t"))
    if {row["filename"] for row in rows} != {"success_sound.mp3", "failure_pictures_screen_sound.mp3", "success_pictures_screen_sound.mp3", "success_in_a_raw_sound.mp3"} or len(rows) != 4:
        errors.append("Feedback audio provenance must contain all four original practice sounds exactly once")
    for row in rows:
        original = (ROOT / row["android_source"]).read_bytes()
        actual = (ROOT / "Resources/LanguageMedia" / row["filename"]).read_bytes()
        if original != actual or hashlib.sha256(original).hexdigest() != row["sha256"]:
            errors.append(row["filename"] + ": original feedback audio differs")
    if args.self_test:
        mutations = [
            ("ForEach(session.mixedBoardItems", "ForEach(session.activeMixedItems"),
            ("pendingLanguagePair == pending", "true"),
            ("!Task.isCancelled", "true"),
            ("1_300_000_000", "0"),
            ("LanguagePairsPointsCard(", "Text(repeating: 0)("),
            ("MinikVisualAsset.cardsMascot", '"minik_activity_pairs"'),
            ("hiddenLanguageGroups = []", "hiddenLanguageGroups = hiddenLanguageGroups"),
            ("lastAudibleLanguagePairID != pending.id", "true"),
        ]
        for before, after in mutations:
            assert before in view, before
            assert validate(view.replace(before, after), model, visuals, hub), before
        print("PAIRS_NEGATIVE_FIXTURES_REJECTED=8")
    print("LANGUAGE_PAIRS_ERRORS=" + str(len(errors)))
    for error in errors: print(error)
    print("STATIC_ONLY: Swift typechecking, XCTest, animation, speech and final layout require iOS.")
    return bool(errors)

if __name__ == "__main__":
    sys.exit(main())

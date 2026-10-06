"""Check Learn's complete original artwork and production projection on Windows."""
import argparse
import csv
import hashlib
import json
import pathlib
import re
import sys
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    errors = []
    provider = (ROOT / "Sources/LanguageLearnContentProvider.swift").read_text(encoding="utf-8")
    stems = re.findall(r'image: AssetReference\(rawValue: "learn_([a-z_]+)"\)', provider)
    expected = {"language_letter_" + stem + suffix for stem in stems for suffix in ["", "_capital"]}
    expected.add("language_learn_divider")
    rows = list(csv.DictReader((ROOT / "docs/language-learn-artwork-provenance.tsv").open(encoding="utf-8"), delimiter="\t"))
    if len(stems) != 53 or len(expected) != 107 or {row["asset"] for row in rows} != expected:
        errors.append("Incomplete 26 English + 27 Hebrew original artwork inventory")
    catalog = ROOT / "Resources/LanguageLetters.xcassets"
    if {p.stem for p in catalog.glob("*.imageset")} != expected:
        errors.append("Asset catalog inventory differs from the alphabet catalog")
    for row in rows:
        source = ROOT / row["android_source"]
        name = row["asset"]
        directory = catalog / (name + ".imageset")
        content = json.loads((directory / "Contents.json").read_text(encoding="utf-8"))
        target = directory / content["images"][0]["filename"]
        original = Image.open(source).convert("RGBA")
        actual = Image.open(target).convert("RGBA")
        if hashlib.sha256(source.read_bytes()).hexdigest() != row["sha256"]:
            errors.append(name + ": Android source hash changed")
        if original.size != actual.size or original.tobytes() != actual.tobytes():
            errors.append(name + ": original decoded pixels differ")
        if not actual.getchannel("A").getbbox():
            errors.append(name + ": empty visible artwork")
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    for target in ["MinikPlus", "MinikPlusEnglish"]:
        section = re.search(r"^  " + target + r":\n(?:(?!^  \w).|\n)*", project, re.M).group()
        if "Resources/LanguageLetters.xcassets" not in section:
            errors.append(target + ": Learn artwork is not bundled")
    view = (ROOT / "Sources/LearnView.swift").read_text(encoding="utf-8")
    page = (ROOT / "Sources/LanguageLearnPage.swift").read_text(encoding="utf-8")
    def missing_contract(view_source, page_source):
        return ("LanguageLearnContentProvider.presentation(for: session.currentCard)" not in view_source
                or "LanguageLearnPage(" not in view_source
                or "card.capitalLetterAsset" not in page_source
                or "card.smallLetterAsset" not in page_source
                or 'Image("language_learn_divider")' not in page_source
                or "Text(card.word.text)" not in page_source
                or 'Image(systemName: "play.fill")' not in page_source)
    if missing_contract(view, page):
        errors.append("Production route lost the separated original-artwork presentation")
    if args.self_test:
        assert missing_contract(view.replace("LanguageLearnPage(", "OldCombinedCard("), page)
        assert missing_contract(view, page.replace("card.capitalLetterAsset", "card.word.text"))
        assert missing_contract(view, page.replace('Image(systemName: "play.fill")', 'Text("Listen")'))
        print("LEARN_NEGATIVE_FIXTURES_REJECTED=3")
    print(f"LEARN_CARDS={len(stems)}; ORIGINAL_ASSETS={len(rows)}; ERRORS={len(errors)}")
    for error in errors:
        print(error)
    print("STATIC_ONLY: rendered spacing, VoiceOver and XCTest require iOS.")
    return bool(errors)

if __name__ == "__main__":
    sys.exit(main())

"""Deterministic catalog/source regression guard; this is not a rendered UI test."""
import argparse
import copy
import importlib.util
import json
import pathlib
import re
import sys

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parents[1]

def validate_catalog(catalog, mapping, authored, android, english_only=False):
    errors = []
    expected = set(android) - ({"he"} if english_only else set())
    for key, name in mapping.items():
        entry = catalog["strings"].get(key, {})
        locales = entry.get("localizations", {})
        if set(locales) != expected:
            errors.append(f"{key}: locale coverage")
        for locale in expected:
            expected_value = key if locale == "en" else android[locale][name].strip().rstrip(":")
            actual = locales.get(locale, {}).get("stringUnit", {}).get("value")
            if actual != expected_value:
                errors.append(f"{key}/{locale}: differs from Android reference")
    for key, translations in authored.items():
        for locale in expected:
            expected_value = key if locale == "en" else translations[locale]
            script_ranges = {"am": (0x1200, 0x137F), "ar": (0x0600, 0x06FF), "he": (0x0590, 0x05FF), "ru": (0x0400, 0x04FF)}
            if "??" in expected_value or chr(0xFFFD) in expected_value or re.search(r"\w\?\w", expected_value):
                errors.append(f"{key}/{locale}: damaged Unicode in authored text")
            if locale in script_ranges:
                low, high = script_ranges[locale]
                if not any(low <= ord(c) <= high for c in expected_value):
                    errors.append(f"{key}/{locale}: expected native script is absent")
            actual = catalog["strings"].get(key, {}).get("localizations", {}).get(locale, {}).get("stringUnit", {}).get("value")
            if actual != expected_value:
                errors.append(f"{key}/{locale}: missing authored translation")
    return errors

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    options = parser.parse_args()
    spec = importlib.util.spec_from_file_location("catalog_sync", ROOT / "Scripts/sync-language-parity-localization.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    mapping = json.loads((ROOT / "docs/language-interface-android-key-map.json").read_text(encoding="utf-8"))
    authored = json.loads((ROOT / "docs/language-interface-authored-translations.json").read_text(encoding="utf-8"))
    android = module.android_values()
    errors = []
    catalogs = {}
    for variant in ["All", "EnglishOnly"]:
        catalogs[variant] = json.loads((ROOT / "Resources/Localization" / variant / "Localizable.xcstrings").read_text(encoding="utf-8"))
        errors += validate_catalog(catalogs[variant], mapping, authored, android, variant == "EnglishOnly")
    source = {p.name: p.read_text(encoding="utf-8") for p in (ROOT / "Sources").glob("*.swift")}
    requirements = {
        "RootView.swift": [r".environment(\.locale, effectiveInterfaceLocale.locale)",
                           "return interfaceLocaleController.selectedLocale",
                           "return effectiveInterfaceLocale.layoutDirection"],
        "InterfaceLocale.swift": ["String(localized: LocalizedStringResource(key, locale: locale))"],
        "LanguageShellViews.swift": ["interfaceLocaleID.text(activity.titleKey)", "LanguageIntroView", "LanguageMenuView"],
        "ParentAreaView.swift": ["interfaceLocaleController.selectedLocale.text(locale.displayNameKey)",
                               r".environment(\.locale, interfaceLocaleController.selectedLocale.locale)"],
    }
    format_only = source["InterfaceLocale.swift"].replace("String(localized: LocalizedStringResource(key, locale: locale))", "String(localized: key, locale: locale)")
    for filename, fragments in requirements.items():
        for fragment in fragments:
            if fragment not in source[filename]:
                errors.append(filename + ": missing explicit selected-locale path: " + fragment)
    if options.self_test:
        original = catalogs["All"]
        mutations = [
            ("Hebrew English placeholder", "Parent Area", "he", "Parent Area"),
            ("Arabic English placeholder", "Interface language", "ar", "Interface language"),
            ("Menu English placeholder", "Letter Pairs", "he", "Letter Pairs"),
            ("Wrong locale value", "Parent Area", "fr", original["strings"]["Parent Area"]["localizations"]["de"]["stringUnit"]["value"]),
        ]
        for name, key, locale, value in mutations:
            altered = copy.deepcopy(original)
            altered["strings"][key]["localizations"][locale]["stringUnit"]["value"] = value
            assert validate_catalog(altered, mapping, authored, android), name
        altered = copy.deepcopy(catalogs["EnglishOnly"])
        altered["strings"]["Parent Area"]["localizations"]["he"] = original["strings"]["Parent Area"]["localizations"]["he"]
        assert validate_catalog(altered, mapping, authored, android, True), "English Only Hebrew exposure"
        corrupted_authored = copy.deepcopy(authored)
        corrupted_authored["Records & Streaks"]["he"] = "????? ??????"
        corrupted_catalog = copy.deepcopy(original)
        corrupted_catalog["strings"]["Records & Streaks"]["localizations"]["he"]["stringUnit"]["value"] = "????? ??????"
        assert validate_catalog(corrupted_catalog, mapping, corrupted_authored, android), "coupled encoding corruption"
        assert any(fragment not in format_only for fragment in requirements["InterfaceLocale.swift"]), "formatting-only locale initializer"
        print("SELF_TEST_MUTATIONS_REJECTED=7")
    print(f"ANDROID_MAPPED_KEYS={len(mapping)}; AUTHORED_KEYS={len(authored)}")
    print(f"LANGUAGE_INTERFACE_ERRORS={len(errors)}")
    for error in errors:
        print(error)
    print("STATIC_ONLY: XCTest, VoiceOver and rendered locale refresh require macOS/iOS.")
    return bool(errors)

if __name__ == "__main__":
    sys.exit(main())

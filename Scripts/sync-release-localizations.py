"""Maintain source-owned release strings without claiming unreviewed translations.

English is the source text. Until a native-language review replaces a fallback,
every non-English value intentionally remains English and `needs_review`.
"""

from __future__ import annotations

import json
import pathlib
import re
import xml.etree.ElementTree as ET


ROOT = pathlib.Path(__file__).resolve().parents[1]
ANDROID_RESOURCES = ROOT.parent / "android/app/src/main/res"
CATALOGS = {
    ROOT / "Resources/Localization/All/Localizable.xcstrings": (
        "am", "ar", "de", "en", "es", "fr", "he", "nl", "pt-BR", "pt-PT", "ru"
    ),
    ROOT / "Resources/Localization/EnglishOnly/Localizable.xcstrings": (
        "am", "ar", "de", "en", "es", "fr", "nl", "pt-BR", "pt-PT", "ru"
    ),
}

ANDROID_LOCALE_DIRECTORIES = {
    "am": "values-am",
    "ar": "values-ar",
    "de": "values-de",
    "en": "values",
    "es": "values-es",
    "fr": "values-fr",
    "he": "values-he",
    "nl": "values-nl",
    "pt-BR": "values-pt-rBR",
    "pt-PT": "values-pt-rPT",
    "ru": "values-ru",
}

ANDROID_STRING_KEYS = {
    "New score record!": "records_dialog_new_score_title",
    "New streak record!": "records_dialog_new_streak_title",
    "Not now": "records_name_cancel",
    "Two new records!": "records_dialog_new_both_title",
}

# The Android Dutch file contains verbatim French values for this newly added
# dialog group. Do not label those wrong-language values as reviewed Dutch.
UNUSABLE_ANDROID_TRANSLATIONS = {
    ("nl", "records_name_cancel"),
}

OBSOLETE_LEADERBOARD_STRINGS = {
    "Great job! You reached a new place on the leaderboard. Enter your name to save the record.",
    "New record!",
    "Save record",
    "Saving record",
    "The record could not be saved.",
    "Enter a name to save the record.",
    "Your name",
    "Only the generated alias or avatar, score or streak, product identifier, and timestamp are sent.",
    "A best score is waiting for parent approval.",
    "A grown-up can approve Online leaderboard in Parent Area. Until then, this score stays pending.",
    "Nothing is shared until a grown-up turns on Online leaderboard.",
    "Opens a grown-up check before changing online leaderboard participation",
    "Opens a grown-up check before deleting public leaderboard records",
}

STRINGS = (
    "%lld + %lld",
    "%lld plus %lld",
    "A little Minik practice is ready when you are.",
    "Ads removed",
    "Answer",
    "Best streaks",
    "A best score is waiting to publish.",
    "Cancel",
    "Checking purchases…",
    "Close",
    "Contacting the App Store…",
    "Grown-ups only",
    "Choose a fun public alias for the online leaderboard.",
    "Choosing alias",
    "A calmer experience, without ads",
    "For parents",
    "Learning reminders",
    "Loading records",
    "Minik Player",
    "Great score!",
    "New score record!",
    "New streak record!",
    "New records will appear here.",
    "No records yet",
    "Not quite. Try again.",
    "Not now",
    "Nothing is shared before you choose a public alias.",
    "Not configured for this build",
    "Opens a grown-up check before contacting the App Store",
    "Opens a grown-up check before restoring App Store purchases",
    "Opens a grown-up check before leaving the app",
    "Turns public leaderboard participation on or off",
    "Deletes this participant’s public leaderboard records",
    "Online leaderboard",
    "Online leaderboard disabled.",
    "Online leaderboard enabled.",
    "Online leaderboard is waiting for an alias.",
    "Online leaderboard will retry the pending record when Firebase is available.",
    "Only an opaque participant identifier, generated alias or avatar, score or streak, product identifier, and timestamp are sent.",
    "Player",
    "Purchase approval is pending.",
    "Purchase cancelled.",
    "Links are not configured for this build.",
    "Purchases",
    "Purchases are not configured for this build.",
    "Notification permission is requested only when a parent turns reminders on",
    "Notifications are turned off in Settings.",
    "Rank %lld: %@, %lld",
    "Remote records are not configured for this build.",
    "Remove Ads — %@",
    "Remind me later",
    "Restore Purchases",
    "Restoring purchases…",
    "Scores",
    "Saved on this device",
    "Share records using a generated alias.",
    "Show different aliases",
    "Send one gentle reminder each week.",
    "Showing saved records while offline.",
    "The reminder could not be scheduled.",
    "The child chooses from generated aliases after a qualifying score.",
    "This score is ready to publish when Online leaderboard is on and Firebase is available.",
    "The leaderboard setting could not be updated.",
    "The App Store request could not be completed.",
    "Don’t show this again",
    "This action is for a grown-up.",
    "Time for Minik",
    "Two new records!",
    "Public alias",
    "Public leaderboard records deleted.",
    "Delete public leaderboard records",
    "Firebase stores the public leaderboard.",
    "Updating reminder settings…",
    "Version %@",
    "Version %@ (%@)",
    "Version unavailable",
    "Updating leaderboard settings…",
    "You can delete this participant’s public leaderboard records.",
    "You can turn participation off later.",
    "You can remove ads from the app for a cleaner, more focused experience for your child.",
    "Your Remove Ads purchase is active.",
    "Your child’s local name stays on this device.",
    "Solve this to continue.",
)


def android_strings(locale: str) -> dict[str, str]:
    directory = ANDROID_LOCALE_DIRECTORIES[locale]
    path = ANDROID_RESOURCES / directory / "strings.xml"
    if not path.is_file():
        return {}
    root = ET.parse(path).getroot()
    return {
        element.attrib["name"]: "".join(element.itertext())
        .replace("\\'", "'")
        .replace("\\’", "’")
        for element in root.findall("string")
        if "name" in element.attrib
    }


def entry_for(key: str, locales: tuple[str, ...]) -> dict[str, object]:
    android_key = ANDROID_STRING_KEYS.get(key)
    localizations = {}
    for locale in locales:
        value = android_strings(locale).get(android_key, "") if android_key else ""
        if (locale, android_key) in UNUSABLE_ANDROID_TRANSLATIONS:
            value = ""
        if value:
            state = "translated"
        else:
            value = key
            state = "translated" if locale == "en" else "needs_review"
        localizations[locale] = {
            "stringUnit": {
                "state": state,
                "value": value,
            }
        }

    return {
        "extractionState": "manual",
        "comment": (
            f"Android production string: {android_key}; missing or unusable locale values fall back "
            "to English and require linguistic review."
            if android_key else
            "iOS release integration; non-English fallback requires linguistic review."
        ),
        "localizations": localizations,
    }


def replace_entries(source: str, entries: dict[str, dict[str, object]], newline: str) -> str:
    decoder = json.JSONDecoder()
    opening = re.search(r'"strings"\s*:\s*\{', source)
    if opening is None:
        raise ValueError("Catalog has no strings object.")

    cursor = opening.end()
    spans: dict[str, tuple[int, int]] = {}
    while True:
        whitespace = re.compile(r"[\s,]*").match(source, cursor)
        assert whitespace is not None
        cursor = whitespace.end()
        if source[cursor] == "}":
            break
        key, key_end = decoder.raw_decode(source, cursor)
        separator = re.compile(r"\s*:\s*").match(source, key_end)
        if separator is None:
            raise ValueError(f"Malformed catalog entry: {key}")
        value_start = separator.end()
        _, value_end = decoder.raw_decode(source, value_start)
        spans[key] = (value_start, value_end)
        cursor = value_end

    additions = [
        json.dumps(key, ensure_ascii=False)
        + ": "
        + json.dumps(entry, ensure_ascii=False, separators=(",", ":"))
        for key, entry in entries.items()
        if key not in spans
    ]
    if additions:
        prefix = newline + "                    "
        source = source[: opening.end()] + prefix + ("," + prefix).join(additions) + "," + source[opening.end() :]

    json.loads(source)
    return source


def remove_obsolete_entries(source: str) -> str:
    markers = {
        json.dumps(key, ensure_ascii=False) + ":"
        for key in OBSOLETE_LEADERBOARD_STRINGS
    }
    updated = "".join(
        line for line in source.splitlines(keepends=True)
        if not any(line.lstrip().startswith(marker) for marker in markers)
    )
    json.loads(updated)
    return updated


def main() -> None:
    for path, locales in CATALOGS.items():
        with path.open("r", encoding="utf-8", newline="") as stream:
            original = stream.read()
        newline = "\r\n" if "\r\n" in original else "\n"
        entries = {key: entry_for(key, locales) for key in STRINGS}
        updated = remove_obsolete_entries(original)
        updated = replace_entries(updated, entries, newline)
        with path.open("w", encoding="utf-8", newline="") as stream:
            stream.write(updated)
        print(f"{path.parent.name}: {len(entries)} release keys synchronized")


if __name__ == "__main__":
    main()

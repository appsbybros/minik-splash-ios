"""Import only reviewed Language key mappings; Android is always read-only.
Existing catalog entries outside this mapping retain their exact source text.
"""
import json
import pathlib
import re
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAPPING = ROOT / "docs/language-interface-android-key-map.json"
LOCALE_DIRS = {
    "en": "values", "am": "values-am", "ar": "values-ar", "de": "values-de",
    "es": "values-es", "fr": "values-fr", "he": "values-he", "nl": "values-nl",
    "pt-BR": "values-pt-rBR", "pt-PT": "values-pt-rPT", "ru": "values-ru",
}

def android_values():
    result = {}
    for locale, directory in LOCALE_DIRS.items():
        path = ROOT.parent / "android/app/src/main/res" / directory / "strings.xml"
        result[locale] = {
            node.attrib["name"]: "".join(node.itertext())
            .replace(r"\n", " ").replace(r"\'", "'").replace("\\" + chr(0x2019), chr(0x2019)).replace(r'\"', '"')
            for node in ET.parse(path).getroot() if node.tag == "string"
        }
    return result

def patch_object(source, desired):
    """Change JSON leaves without reformatting existing catalog entries."""
    decoder = json.JSONDecoder()
    cursor, spans = 1, {}
    while True:
        cursor = re.compile(r"[\s,]*").match(source, cursor).end()
        if source[cursor] == "}":
            break
        key, key_end = decoder.raw_decode(source, cursor)
        value_start = re.compile(r"\s*:\s*").match(source, key_end).end()
        old_value, value_end = decoder.raw_decode(source, value_start)
        spans[key] = (value_start, value_end, old_value)
        cursor = value_end
    replacements = []
    for key, value in desired.items():
        if key not in spans:
            continue  # new-entry metadata is recorded in the mapping manifest
        start, end, old_value = spans[key]
        if old_value == value:
            continue
        updated = patch_object(source[start:end], value) if isinstance(value, dict) and isinstance(old_value, dict) else json.dumps(value, ensure_ascii=False)
        replacements.append((start, end, updated))
    for start, end, value in sorted(replacements, reverse=True):
        source = source[:start] + value + source[end:]
    return source

def replace_entries(source, entries):
    # Decode each JSON value to find its exact end (including formatted blocks).
    decoder = json.JSONDecoder()
    opening = re.search(r'"strings"\s*:\s*\{', source).end()
    cursor, spans = opening, {}
    while True:
        cursor = re.compile(r"[\s,]*").match(source, cursor).end()
        if source[cursor] == "}":
            break
        key, key_end = decoder.raw_decode(source, cursor)
        value_start = re.compile(r"\s*:\s*").match(source, key_end).end()
        _, value_end = decoder.raw_decode(source, value_start)
        spans[key] = (value_start, value_end)
        cursor = value_end
    replacements = [
        (spans[key][0], spans[key][1], patch_object(source[spans[key][0]:spans[key][1]], entry))
        for key, entry in entries.items() if key in spans
    ]
    for start, end, value in sorted(replacements, reverse=True):
        source = source[:start] + value + source[end:]
    additions = [
        json.dumps(key, ensure_ascii=False) + ": " +
        json.dumps(entry, ensure_ascii=False, separators=(",", ":"))
        for key, entry in entries.items() if key not in spans
    ]
    if additions:
        source = source[:opening] + "\n                    " + ",\n                    ".join(additions) + "," + source[opening:]
    json.loads(source)
    return source

def main():
    mapping = json.loads(MAPPING.read_text(encoding="utf-8"))
    values = android_values()
    # Resolve everything before writing either catalog; a missing source is an error.
    resolved = {}
    for key, name in mapping.items():
        resolved[key] = {}
        for locale in LOCALE_DIRS:
            value = values[locale][name]
            resolved[key][locale] = key if locale == "en" else value.strip().rstrip(":")
    for variant in ["All", "EnglishOnly"]:
        path = ROOT / "Resources/Localization" / variant / "Localizable.xcstrings"
        entries = {
            key: {
                "extractionState": "manual",
                "comment": "Android reference: " + mapping[key],
                "localizations": {
                    locale: {"stringUnit": {"state": "translated", "value": value}}
                    for locale, value in translations.items()
                    if variant != "EnglishOnly" or locale != "he"
                },
            }
            for key, translations in resolved.items()
        }
        original = path.read_text(encoding="utf-8")
        updated = replace_entries(original, entries)
        path.write_text(updated, encoding="utf-8", newline="\n")
        print(f"{variant}: {len(entries)} mapped Language keys; Android text preserved.")

if __name__ == "__main__":
    main()

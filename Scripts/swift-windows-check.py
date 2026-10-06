"""Windows pre-flight for the iOS sources, run before spending macOS build minutes.

1. Parses every Swift file in Sources and Tests (syntax errors such as reserved
   words used as names).
2. Type-checks the source files that import only Foundation (game, leaderboard,
   lesson and policy logic) with the Swift for Windows toolchain. Errors that
   only come from types defined in Apple-framework files left out of that set
   are filtered out; everything else is printed.

It cannot check SwiftUI, UIKit, SpriteKit, WebKit, StoreKit, Firebase or Google
Mobile Ads code; only an Xcode build can.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOUNDATION_ONLY = {"Foundation"}


def find_swiftc():
    for candidate in os.environ.get("PATH", "").split(os.pathsep):
        path = Path(candidate) / "swiftc.exe"
        if path.is_file():
            return path
    base = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Swift" / "Toolchains"
    found = sorted(base.glob("*/usr/bin/swiftc.exe"))
    return found[-1] if found else None


def find_sdk():
    if os.environ.get("SDKROOT"):
        return os.environ["SDKROOT"]
    base = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Swift" / "Platforms"
    found = sorted(base.glob("*/Windows.platform/Developer/SDKs/Windows.sdk"))
    return str(found[-1]) if found else None


def imports(text):
    return set(re.findall(r"^\s*(?:@\w+\s+)*import\s+(?:struct\s+|class\s+|enum\s+)?(\w+)", text, re.M))


def declared_names(text):
    return set(re.findall(r"\b(?:struct|class|enum|protocol|actor|typealias)\s+([A-Z]\w*)", text))


def main():
    swiftc = find_swiftc()
    if swiftc is None:
        print("swiftc.exe not found; install the Swift toolchain (winget install Swift.Toolchain).")
        return 2

    sources = sorted((ROOT / "Sources").rglob("*.swift"))
    tests = sorted((ROOT / "Tests").rglob("*.swift"))

    parse = subprocess.run([str(swiftc), "-parse", *map(str, sources + tests)], capture_output=True, text=True)
    parse_errors = [line for line in (parse.stdout + parse.stderr).splitlines() if ": error:" in line]
    print(f"PARSE: {len(sources) + len(tests)} files, {len(parse_errors)} errors")
    for line in parse_errors:
        print("  " + line.replace(str(ROOT) + os.sep, ""))

    texts = {path: path.read_text(encoding="utf-8-sig") for path in sources}
    checked = [path for path, text in texts.items() if imports(text) <= FOUNDATION_ONLY]
    excluded_names = set()
    for path, text in texts.items():
        if path not in checked:
            excluded_names |= declared_names(text)
    sdk = find_sdk()
    command = [str(swiftc), "-typecheck", "-swift-version", "5", "-module-name", "MinikPlus",
               "-D", "MINIK_PLUS", *map(str, checked)]
    if sdk:
        command[1:1] = ["-sdk", sdk]
    typecheck = subprocess.run(command, capture_output=True, text=True)
    lines = (typecheck.stdout + typecheck.stderr).splitlines()
    errors = []
    for line in lines:
        if ": error:" not in line:
            continue
        mentioned = set(re.findall(r"'([A-Za-z_]\w*)", line))
        if mentioned & excluded_names:
            continue
        errors.append(line.replace(str(ROOT) + os.sep, ""))
    print(f"TYPECHECK: {len(checked)} Foundation-only files, {len(errors)} errors not explained by Apple-only files")
    for line in errors:
        print("  " + line)
    return 1 if parse_errors or errors else 0


if __name__ == "__main__":
    sys.exit(main())

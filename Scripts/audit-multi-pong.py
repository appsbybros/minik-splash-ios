#!/usr/bin/env python3
"""Static audit of the Multi Ping Pong iOS port (target MinikMultiPingPong, sources in MultiPong/).

Checks, without building or touching the network:
  * the public entry points shared Sources/** rely on still exist (ModernPongView, ModernPongExperience, ModernPongResult);
  * the Firebase client writes only under minikCrossPong/ with the Android app name and bundle id;
  * ads stay off (no interstitial unit, no ad unit IDs) in MultiPong/;
  * the Firebase rules mirror keeps the root closed and matches the hash recorded in docs/multi-pong-ios-handoff.md;
  * every unit-test file imports the app module with @testable;
  * braces, brackets and parentheses balance in every Swift file of MultiPong/ and Tests/MultiPongTests/;
  * the text catalog (MultiPong/MPTextCatalog.swift, Android AppText) is complete: four non-blank columns per row, no
    duplicate keys, and every {n} of a translation exists in its English key;
  * the six app languages agree in MPText.swift and in the CFBundleLocalizations of the MinikMultiPingPong target.

With --android <path to the MinikCrossPong checkout>, it also
  * re-hashes every Android file listed in the handoff document: the committed blobs of the commit it names, and the
    working-tree files listed in its "working-tree files" section;
  * compares MultiPong/MPTextCatalog.swift row by row with the Android AppText.kt of that working tree.

With --android and --write-catalog it regenerates MultiPong/MPTextCatalog.swift from the Android AppText.kt instead of
comparing (then run the audit again).

Usage: python3 Scripts/audit-multi-pong.py [--android C:/Projects/MinikCrossPong [--write-catalog]]
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / 'docs' / 'multi-pong-ios-handoff.md'
CATALOG = ROOT / 'MultiPong' / 'MPTextCatalog.swift'
ANDROID_COMMIT = '828c6fc094f3afb05d86fea0616704a17976dfaf'
APP_TEXT = 'app/src/main/java/com/appsbybros/minik/localization/AppText.kt'
LANGUAGES = ['en', 'he', 'ar', 'es', 'hi', 'nl']
COLUMNS = ['es', 'ar', 'hi', 'nl']
BACKSLASH = chr(92)
failures = []


def check(condition, message):
    if not condition:
        failures.append(message)


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def balanced(text):
    """Bracket balance outside strings and comments (Swift string interpolation aware)."""
    pairs = {')': '(', ']': '[', '}': '{'}
    stack, i, n = [], 0, len(text)
    in_string = multi = False
    interpolation = []
    while i < n:
        c = text[i]
        if multi:
            if text.startswith('"""', i):
                multi, i = False, i + 3
                continue
            i += 1
            continue
        if in_string:
            if c == BACKSLASH and i + 1 < n and text[i + 1] == '(':
                interpolation.append(len(stack))
                stack.append('(')
                in_string, i = False, i + 2
                continue
            if c == BACKSLASH:
                i += 2
                continue
            if c == '"':
                in_string = False
            i += 1
            continue
        if text.startswith('//', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if text.startswith('/*', i):
            j = text.find('*/', i)
            i = n if j < 0 else j + 2
            continue
        if text.startswith('"""', i):
            multi, i = True, i + 3
            continue
        if c == '"':
            in_string, i = True, i + 1
            continue
        if c in '([{':
            stack.append(c)
        elif c in ')]}':
            if not stack or stack[-1] != pairs[c]:
                return False
            stack.pop()
            if c == ')' and interpolation and interpolation[-1] == len(stack):
                interpolation.pop()
                in_string = True
        i += 1
    return not stack and not in_string and not multi


def documented_hashes():
    """(committed blobs at ANDROID_COMMIT, working-tree files) listed under the document's SHA-256 headings."""
    committed, worktree = {}, {}
    target = committed
    for line in DOC.read_text(encoding='utf-8').splitlines():
        if line.startswith('#'):
            if 'SHA-256' in line:
                target = worktree if 'working-tree' in line else committed
            continue
        m = re.fullmatch(r'([0-9a-f]{64})  (\S.*)', line.strip())
        if m:
            target[m.group(2)] = m.group(1)
    return committed, worktree


# ---- text catalog (Android AppText.kt <-> MultiPong/MPTextCatalog.swift) ---------------------------------------------

def kotlin_string(s, i):
    """The Kotlin string literal at s[i] == '"' (no templates allowed) and the index after it."""
    i += 1
    out = []
    simple = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', "'": "'", BACKSLASH: BACKSLASH, '$': '$', 'b': '\b'}
    while True:
        c = s[i]
        if c == '"':
            return ''.join(out), i + 1
        if c == BACKSLASH:
            e = s[i + 1]
            if e in simple:
                out.append(simple[e])
                i += 2
            elif e == 'u':
                out.append(chr(int(s[i + 2:i + 6], 16)))
                i += 6
            else:
                raise ValueError(f'unknown Kotlin escape \\{e}')
            continue
        if c == '$' and (s[i + 1].isalpha() or s[i + 1] in '_{'):
            raise ValueError('a Kotlin string template in AppText: ' + s[i - 20:i + 20])
        out.append(c)
        i += 1


def android_rows(text):
    """[(chunk, key, [es, ar, hi, nl])] in AppText order."""
    rows = []
    for m in re.finditer(r'private fun (chunk\d+)\(\)=mapOf\(', text):
        i = m.end()
        while True:
            while text[i] in ' \r\n\t,':
                i += 1
            if text[i] == ')':
                break
            key, i = kotlin_string(text, i)
            to = re.compile(r'\s*to\s*listOf\(').match(text, i)
            if not to:
                raise ValueError('unexpected AppText row near ' + text[i:i + 60])
            i = to.end()
            values = []
            while True:
                while text[i] in ' \r\n\t,':
                    i += 1
                if text[i] == ')':
                    i += 1
                    break
                value, i = kotlin_string(text, i)
                values.append(value)
            rows.append((m.group(1), key, values))
    return rows


def swift_literal(value):
    out = ['"']
    for c in value:
        code = ord(c)
        if c == BACKSLASH:
            out.append(BACKSLASH * 2)
        elif c == '"':
            out.append(BACKSLASH + '"')
        elif c == '\n':
            out.append(BACKSLASH + 'n')
        elif c == '\r':
            out.append(BACKSLASH + 'r')
        elif c == '\t':
            out.append(BACKSLASH + 't')
        elif 0xD800 <= code <= 0xDFFF:
            raise ValueError('a lone surrogate in AppText')
        elif unicodedata.category(c) in ('Cc', 'Cf', 'Zl', 'Zp'):
            out.append(BACKSLASH + 'u{%X}' % code)
        else:
            out.append(c)
    out.append('"')
    return ''.join(out)


def parse_swift_string(s, i):
    """A literal written by swift_literal at s[i] == '"' and the index after it."""
    i += 1
    out = []
    simple = {'n': '\n', 'r': '\r', 't': '\t', '"': '"', BACKSLASH: BACKSLASH, '0': '\0', "'": "'"}
    while True:
        c = s[i]
        if c == '"':
            return ''.join(out), i + 1
        if c == '\n':
            raise ValueError('a line break inside a catalog literal')
        if c == BACKSLASH:
            e = s[i + 1]
            if e in simple:
                out.append(simple[e])
                i += 2
            elif e == 'u' and s[i + 2] == '{':
                j = s.index('}', i)
                out.append(chr(int(s[i + 3:j], 16)))
                i = j + 1
            else:
                raise ValueError(f'unexpected Swift escape \\{e} in the catalog')
            continue
        out.append(c)
        i += 1


def swift_rows(text):
    """[(chunk, key, [values])] from MPTextCatalog.swift."""
    rows = []
    chunk = None
    for line in text.splitlines():
        m = re.match(r'\s*private static let (chunk\d+): \[\(String, \[String\]\)\] = \[\s*$', line)
        if m:
            chunk = m.group(1)
            continue
        stripped = line.strip()
        if not stripped.startswith('("'):
            continue
        key, i = parse_swift_string(stripped, 1)
        if not stripped.startswith(', [', i):
            raise ValueError('unexpected catalog row: ' + stripped[:80])
        i += 3
        values = []
        while True:
            value, i = parse_swift_string(stripped, i)
            values.append(value)
            if stripped.startswith(', ', i):
                i += 2
                continue
            break
        if stripped[i:] not in ('])', ']),'):
            raise ValueError('unexpected catalog row end: ' + stripped[-40:])
        rows.append((chunk, key, values))
    return rows


def write_catalog(rows, source_hash):
    chunks = []
    for chunk, _, _ in rows:
        if chunk not in chunks:
            chunks.append(chunk)
    lines = [
        '// Generated by Scripts/audit-multi-pong.py --write-catalog from the Android catalog',
        f'// {APP_TEXT}',
        f'// (MinikCrossPong working tree on {ANDROID_COMMIT[:7]}, SHA-256 {source_hash}).',
        '// Do not edit by hand: regenerate it from the Android file.',
        '',
        '/// Android `AppText` rows in their Android order: the English key, then its Spanish, Arabic, Hindi and Dutch texts',
        '/// (`MPText.columns`). `{0}`, `{1}`… stand for the names and numbers inside a text. Read through `MPText`.',
        'enum MPTextCatalog {',
        '    static let rows: [(String, [String])] = Array([',
        '        ' + ', '.join(chunks),
        '    ].joined())',
    ]
    for chunk in chunks:
        lines.append(f'    private static let {chunk}: [(String, [String])] = [')
        body = [r for r in rows if r[0] == chunk]
        for index, (_, key, values) in enumerate(body):
            comma = ',' if index < len(body) - 1 else ''
            lines.append('        (' + swift_literal(key) + ', [' + ', '.join(swift_literal(v) for v in values) + '])' + comma)
        lines.append('    ]')
    lines.append('}')
    CATALOG.write_bytes(('\n'.join(lines) + '\n').encode('utf-8'))


def placeholders(value):
    return set(int(n) for n in re.findall(r'\{([0-9]+)\}', value))


def check_catalog(rows):
    keys = [key for _, key, _ in rows]
    check(len(rows) > 0, 'MPTextCatalog.swift has no rows')
    check(len(keys) == len(set(keys)), 'MPTextCatalog.swift has duplicate keys')
    for _, key, values in rows:
        check(len(values) == len(COLUMNS), f'catalog row without {len(COLUMNS)} columns: {key[:60]!r}')
        for column, value in zip(COLUMNS, values):
            check(value.strip() != '', f'blank {column} text for {key[:60]!r}')
            check(placeholders(value) <= placeholders(key), f'{column} text uses a placeholder its key lacks: {key[:60]!r}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--android', help='path to the MinikCrossPong checkout (read-only)')
    parser.add_argument('--write-catalog', action='store_true', help='regenerate MultiPong/MPTextCatalog.swift from --android')
    args = parser.parse_args()

    if args.write_catalog:
        if not args.android:
            print('--write-catalog needs --android')
            return 2
        source = (pathlib.Path(args.android) / APP_TEXT).read_bytes()
        rows = android_rows(source.decode('utf-8'))
        write_catalog(rows, hashlib.sha256(source).hexdigest())
        print(f'Wrote {CATALOG.relative_to(ROOT)}: {len(rows)} rows')
        return 0

    view = read('MultiPong/ModernPongView.swift')
    models = read('MultiPong/MPMultiplayerModels.swift')
    controller = read('MultiPong/MPController.swift')
    check(re.search(r'struct ModernPongView: View', view), 'ModernPongView is missing')
    check('init(experience: ModernPongExperience = .full, commerce: MinikCommerceController? = nil, onClose: @escaping (ModernPongResult?) -> Void' in view,
          'ModernPongView(experience:commerce:onClose:) changed')
    check(re.search(r'enum ModernPongExperience: String, Codable \{\s*case full, simple', models), 'ModernPongExperience changed')
    check('struct ModernPongResult: Codable, Equatable { var playerPoints: Int; var opponentPoints: Int; var won: Bool }' in controller,
          'ModernPongResult changed')

    repository = read('MultiPong/MPRepository.swift')
    check('database.reference().child("minikCrossPong")' in repository, 'Firebase root is not minikCrossPong')
    check('static let appName = "minik-cross-pong"' in repository, 'Firebase app name is not minik-cross-pong')
    check('static let bundleIdentifier = "com.appsbybros.minik.crosspong"' in repository, 'bundle id check changed')
    for other in ('child("minikPingPong")', 'child("tripleShot")', '"minik-ping-pong"'):
        check(other not in repository, f'MPRepository.swift references {other}')

    ads = read('MultiPong/MPAds.swift')
    check(re.search(r'func interstitialUnit\(experience: ModernPongExperience\) -> String\? \{ nil \}', ads), 'an ad unit is configured')
    for path in sorted((ROOT / 'MultiPong').glob('*.swift')):
        check('ca-app-pub-' not in path.read_text(encoding='utf-8'), f'{path.name} contains an AdMob ID')

    rules_path = ROOT / 'Tests' / 'MultiPongFirebase' / 'rules' / 'merged.json'
    rules = json.loads(rules_path.read_text(encoding='utf-8'))['rules']
    check(rules.get('.read') is False and rules.get('.write') is False, 'merged rules open the root')
    check('minikCrossPong' in rules and 'minikPingPong' in rules and 'tripleShot' in rules, 'merged rules lack a subtree')
    check('leaderboard' not in rules.get('minikCrossPong', {}), 'minikCrossPong has a leaderboard rule')
    committed, worktree = documented_hashes()
    merged_hash = hashlib.sha256(rules_path.read_bytes()).hexdigest()
    check(committed.get('firebase-setup/merged-database-rules.json') == merged_hash, 'rules/merged.json differs from the documented Android candidate')

    for path in sorted((ROOT / 'Tests' / 'MultiPongTests').glob('*.swift')):
        check('@testable import MinikMultiPingPong' in path.read_text(encoding='utf-8'), f'{path.name} lacks @testable import')
    for folder in ('MultiPong', 'Tests/MultiPongTests'):
        for path in sorted((ROOT / folder).glob('*.swift')):
            check(balanced(path.read_text(encoding='utf-8')), f'{folder}/{path.name}: unbalanced brackets')

    # Languages: MPText, the target's CFBundleLocalizations and the catalog columns agree.
    text_source = read('MultiPong/MPText.swift')
    declared = re.search(r'static let languages: Set<String> = \[([^\]]*)\]', text_source)
    check(declared and sorted(re.findall(r'"([a-z]+)"', declared.group(1))) == sorted(LANGUAGES), 'MPText.languages changed')
    columns = re.search(r'static let columns = \[([^\]]*)\]', text_source)
    check(columns and re.findall(r'"([a-z]+)"', columns.group(1)) == COLUMNS, 'MPText.columns changed')
    project = read('project.yml')
    target = re.search(r'\n  MinikMultiPingPong:\n(.*?)\n  [A-Za-z]\w*:\n', project, re.S)
    localizations = target and re.search(r'CFBundleLocalizations: \[([^\]]*)\]', target.group(1))
    check(localizations and sorted(v.strip() for v in localizations.group(1).split(',')) == sorted(LANGUAGES),
          'CFBundleLocalizations of MinikMultiPingPong differs from the six app languages')
    try:
        catalog = swift_rows(CATALOG.read_text(encoding='utf-8'))
        check_catalog(catalog)
    except (OSError, ValueError, IndexError) as error:
        catalog = []
        failures.append(f'MPTextCatalog.swift could not be read: {error}')

    if args.android:
        android = pathlib.Path(args.android)
        for rel, expected in sorted(committed.items()):
            blob = subprocess.run(['git', '-C', str(android), 'show', f'{ANDROID_COMMIT}:{rel}'], capture_output=True)
            if blob.returncode != 0:
                failures.append(f'Android file missing at {ANDROID_COMMIT[:7]}: {rel}')
                continue
            check(hashlib.sha256(blob.stdout).hexdigest() == expected, f'Android file changed: {rel}')
        for rel, expected in sorted(worktree.items()):
            path = android / rel
            if not path.is_file():
                failures.append(f'Android working-tree file missing: {rel}')
                continue
            check(hashlib.sha256(path.read_bytes()).hexdigest() == expected, f'Android working-tree file changed: {rel}')
        check(APP_TEXT in worktree, f'{APP_TEXT} is not listed in the working-tree hashes')
        try:
            source = (android / APP_TEXT).read_bytes()
            expected_rows = android_rows(source.decode('utf-8'))
            check([(c, k, v) for c, k, v in catalog] == [(c, k, v) for c, k, v in expected_rows],
                  'MPTextCatalog.swift differs from the Android AppText.kt (run with --write-catalog)')
            check(hashlib.sha256(source).hexdigest() in CATALOG.read_text(encoding='utf-8'), 'MPTextCatalog.swift names another AppText.kt')
            print(f'Catalog rows compared with Android: {len(expected_rows)}')
        except (OSError, ValueError, IndexError) as error:
            failures.append(f'Android AppText.kt could not be read: {error}')
        print(f'Android hashes checked: {len(committed)} at {ANDROID_COMMIT[:7]}, {len(worktree)} in the working tree')

    if failures:
        print('FAILED')
        for message in failures:
            print(' -', message)
        return 1
    print('OK: Multi Ping Pong static audit passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())

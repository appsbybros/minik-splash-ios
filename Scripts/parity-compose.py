"""Android parity captures: every iOS Simulator capture beside its Android reference.

  python Scripts/parity-compose.py validate [--app A] [--text-sizes "large extra-extra-large"] [--references "01 09"]
      Checks appstore/parity.json: reference images, scene names the app accepts
      (Sources/ActivityCatalog.swift and the hub), launch-argument keys, text sizes.
  python Scripts/parity-compose.py scenes --app MinikPlus [--references "01 09"]
      Lines "id<TAB>scene<TAB>wait<TAB>launch arguments" for the capture workflow.
  python Scripts/parity-compose.py simulators --devices D --runtimes R --device-types T [--iphone N] [--ipad N]
      Reads 'xcrun simctl list devices available|runtimes|devicetypes -j' output and prints
      "device<TAB>udid<TAB>name<TAB>runtime" for an iPad mini and an iPhone (6.1-inch, else
      the newest non-Max), creating a Simulator with simctl when none exists.
  python Scripts/parity-compose.py compose --raw <dir> --out <dir> [--height 1200] [--combined-height 900] [--format jpg|png]
      Reads <raw>/<device>/<text size>/<id>.png (and <raw>/captures.tsv, shots.tsv) and writes
      <out>/<device>/<text size>/<id>.<ext>: the Android reference on the left and the iOS
      capture on the right at the same height, with labels; <out>/combined/<id>.<ext>: the
      reference and all its captures in one row; <out>/index.html, summary.md, summary.json.
      Needs Pillow (python -m pip install pillow); runs on Windows, Linux and macOS.

The mapping lives in appstore/parity.json; see docs/android-parity-capture.md.
"""
import argparse
import functools
import html
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "appstore/parity.json"
FONT = ROOT / "appstore/fonts/Heebo-Variable.ttf"
CATALOG = ROOT / "Sources/ActivityCatalog.swift"
HUB = ROOT / "Sources/MinikActivityHubView.swift"
SOURCES = ROOT / "Sources"

# Names 'xcrun simctl ui <device> content_size' accepts, smallest first.
TEXT_SIZES = (
    "extra-small", "small", "medium", "large", "extra-large", "extra-extra-large",
    "extra-extra-extra-large", "accessibility-medium", "accessibility-large",
    "accessibility-extra-large", "accessibility-extra-extra-large",
    "accessibility-extra-extra-extra-large",
)
# The tester's iPad mini first, then the phone.
DEVICE_ORDER = ("ipad", "iphone")
# 6.1-inch iPhones, preferred first.
SIX_ONE_INCH = (
    "iPhone 16e", "iPhone 16", "iPhone 15", "iPhone 15 Pro", "iPhone 14", "iPhone 14 Pro",
    "iPhone 13", "iPhone 13 Pro", "iPhone 12", "iPhone 12 Pro", "iPhone 11", "iPhone XR",
)

BACKGROUND = (30, 31, 36)
PLACEHOLDER = (52, 54, 61)
TEXT = (242, 242, 242)
MUTED = (170, 174, 184)
AMBER = (255, 196, 92)
RED = (255, 112, 112)


def load_config():
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def number(reference):
    return reference["id"].split("-", 1)[0]


def write_text(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def write_lines(lines):
    stream = sys.stdout
    if hasattr(stream, "reconfigure"):
        # Bash reads these lines; keep LF on Windows too.
        stream.reconfigure(newline="\n")
    stream.write("".join(line + "\n" for line in lines))


def select_references(config, selection):
    references = config["references"]
    tokens = (selection or "").replace(",", " ").split()
    if not tokens:
        return list(references)
    wanted, unknown = set(), []
    for token in tokens:
        matches = [reference for reference in references
                   if token == reference["id"] or token.zfill(2) == number(reference)]
        if not matches:
            unknown.append(token)
        wanted.update(reference["id"] for reference in matches)
    if unknown:
        raise SystemExit("Unknown references: " + " ".join(unknown)
                         + " (use numbers such as 01 or ids from appstore/parity.json)")
    return [reference for reference in references if reference["id"] in wanted]


def rewards_arguments(config, variant):
    """The reward ledger as property-list data; UserDefaults reads '<hex>' arguments as Data."""
    rewards = config.get("rewards")
    if not rewards:
        return []
    envelope = {
        "schemaVersion": 1,
        "ledger": {
            "entries": [{
                "scope": {"ownerID": "local-default", "product": variant},
                "state": {
                    "points": int(rewards["points"]),
                    "currentStreak": int(rewards["currentStreak"]),
                    "bestStreak": int(rewards["bestStreak"]),
                },
            }],
            "processedEventIDs": [],
        },
    }
    data = json.dumps(envelope, separators=(",", ":")).encode("utf-8")
    return ["-" + rewards["key"], "<" + data.hex() + ">"]


def launch_arguments(config, app_name, reference):
    app = config["apps"][app_name]
    arguments = (list(app.get("arguments", []))
                 + rewards_arguments(config, app["variant"])
                 + list(reference.get("arguments", [])))
    for argument in arguments:
        if not argument or any(character.isspace() for character in argument):
            raise SystemExit(f"{reference['id']}: launch argument {argument!r} is empty or has whitespace")
    return arguments


def wait_seconds(config, reference):
    try:
        return int(reference.get("wait", config.get("defaultWait", 7)))
    except (TypeError, ValueError):
        return 0


def print_scenes(app_name, selection):
    config = load_config()
    if app_name not in config["apps"]:
        raise SystemExit(f"{app_name} is not in appstore/parity.json apps")
    lines = []
    for reference in select_references(config, selection):
        lines.append("\t".join([reference["id"], reference["scene"], str(wait_seconds(config, reference)),
                                " ".join(launch_arguments(config, app_name, reference))]))
    write_lines(lines)
    return 0


# ---------------------------------------------------------------- validate

def language_kinds():
    text = CATALOG.read_text(encoding="utf-8")
    match = re.search(r"enum LanguageActivityKind\b[^{]*\{(.*?)\n\s*var id\b", text, re.S)
    if not match:
        raise SystemExit("enum LanguageActivityKind was not found in Sources/ActivityCatalog.swift")
    return set(re.findall(r"^\s*case\s+(\w+)\s*$", match.group(1), re.M))


def product_variants():
    text = (SOURCES / "ProductConfiguration.swift").read_text(encoding="utf-8")
    match = re.search(r"enum ProductVariant\b[^{]*\{(.*?)\}", text, re.S)
    return set(re.findall(r"^\s*case\s+(\w+)\s*$", match.group(1), re.M)) if match else set()


def argument_problem(arguments):
    """Why a '-key value' list cannot go through the workflow's space-separated column, or None."""
    if not isinstance(arguments, list) or not all(isinstance(argument, str) for argument in arguments):
        return "arguments must be a list of strings"
    spaced = [argument for argument in arguments if not argument or any(character.isspace() for character in argument)]
    if spaced:
        return f"arguments must be non-empty and have no whitespace: {spaced}"
    if len(arguments) % 2 or not all(argument.startswith("-") for argument in arguments[::2]):
        return "arguments must be '-key value' pairs"
    return None


def rewards_drift():
    """What Sources/Rewards.swift no longer shares with the seeded ledger in rewards_arguments."""
    text = (SOURCES / "Rewards.swift").read_text(encoding="utf-8")
    expected = {
        "schema version 1": r"static let schemaVersion = 1\b",
        "the envelope fields": r"let schemaVersion: Int\s+let ledger: RewardLedger",
        "owner 'local-default'": r'"local-default"',
        "points": r"var points: Int64\b",
        "currentStreak": r"var currentStreak: Int\b",
        "bestStreak": r"var bestStreak: Int\b",
    }
    return [label for label, pattern in expected.items() if not re.search(pattern, text)]


def scene_problem(scene, kinds, hub_text):
    if scene.startswith("language."):
        kind = scene.split(".", 1)[1]
        if kind not in kinds:
            return f"'{kind}' is not a LanguageActivityKind case"
        if 'value(after: "language")' not in hub_text:
            return "the hub no longer opens language.<activity> scenes"
        return None
    if scene == "home":
        return None
    if f'scene == "{scene}"' not in hub_text:
        return f"the hub's applyStoreScreenshotScene does not handle '{scene}'"
    return None


def validate(app_name, text_sizes, selection):
    config = load_config()
    errors, warnings = [], []
    reference_dir = ROOT / config["referenceDir"]
    kinds = language_kinds()
    hub_text = HUB.read_text(encoding="utf-8")
    corpus = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in SOURCES.rglob("*.swift"))
    if '"MinikScreenshotScene"' not in corpus:
        errors.append("Sources no longer read the MinikScreenshotScene launch argument")

    keys = set()
    seen = set()
    for reference in config["references"]:
        rid = reference.get("id", "")
        if not rid or rid in seen:
            errors.append(f"missing or duplicate id: {rid!r}")
            continue
        seen.add(rid)
        if not (reference_dir / f"{rid}.png").is_file():
            errors.append(f"{rid}: {config['referenceDir']}/{rid}.png does not exist")
        problem = scene_problem(reference.get("scene", ""), kinds, hub_text)
        if problem:
            errors.append(f"{rid}: scene {reference.get('scene')!r}: {problem}")
        if not isinstance(reference.get("exact"), bool):
            errors.append(f"{rid}: 'exact' must be true or false")
        if not reference.get("exact") and not reference.get("note"):
            errors.append(f"{rid}: a closest-scene mapping needs a note")
        wanted_scene = reference.get("wantedScene")
        if wanted_scene and not reference.get("exact") and scene_problem(wanted_scene, kinds, hub_text) is None:
            warnings.append(f"{rid}: the app now opens scene {wanted_scene!r}; map this reference to it")
        if wait_seconds(config, reference) <= 0:
            errors.append(f"{rid}: wait must be a positive whole number of seconds")
        arguments = reference.get("arguments", [])
        problem = argument_problem(arguments)
        if problem:
            errors.append(f"{rid}: {problem}")
        else:
            keys.update(argument[1:] for argument in arguments[::2])
    for png in sorted(reference_dir.glob("*.png")):
        if png.stem not in seen:
            warnings.append(f"{png.name} has no mapping")

    variants = product_variants()
    for name, app in config["apps"].items():
        arguments = app.get("arguments", [])
        problem = argument_problem(arguments)
        if problem:
            errors.append(f"apps.{name}: {problem}")
        else:
            keys.update(argument[1:] for argument in arguments[::2])
        if app.get("variant") not in variants:
            errors.append(f"apps.{name}: variant {app.get('variant')!r} is not a ProductVariant case")
    rewards = config.get("rewards")
    if rewards:
        try:
            for field in ("points", "currentStreak", "bestStreak"):
                int(rewards[field])
            keys.add(rewards["key"])
        except (KeyError, TypeError, ValueError):
            errors.append("rewards needs 'key' and whole-number 'points', 'currentStreak' and 'bestStreak'")
        drift = rewards_drift()
        if drift:
            warnings.append("Sources/Rewards.swift no longer matches the seeded ledger (" + ", ".join(drift)
                            + "); the Points and streak badges may show 0")
    # The app's own keys must still exist in Sources; Apple* keys belong to the system.
    for key in sorted(key for key in keys if key.startswith("minik.")):
        if f'"{key}"' not in corpus:
            errors.append(f"launch-argument key {key!r} is not used in Sources")

    if app_name and app_name not in config["apps"]:
        errors.append(f"app {app_name!r} is not in appstore/parity.json apps")
    for size in (text_sizes or "").split():
        if size not in TEXT_SIZES:
            errors.append(f"text size {size!r} is not one of: {', '.join(TEXT_SIZES)}")
    try:
        chosen = select_references(config, selection)
    except SystemExit as error:
        errors.append(str(error))
        chosen = []

    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}")
    if errors:
        return 1
    closest = [reference["id"] for reference in config["references"] if not reference["exact"]]
    print(f"appstore/parity.json is valid: {len(config['references'])} references, "
          f"{len(chosen)} selected; closest-scene only: {', '.join(closest) or 'none'}")
    return 0


# ---------------------------------------------------------------- simulators

def ios_version(runtime_id):
    match = re.search(r"\.iOS-(\d+(?:-\d+)*)$", runtime_id or "")
    return tuple(int(part) for part in match.group(1).split("-")) if match else None


def runtime_names(runtimes_json):
    names = {}
    for runtime in runtimes_json.get("runtimes", []):
        identifier = runtime.get("identifier", "")
        version = ios_version(identifier)
        if version is not None:
            names[identifier] = runtime.get("name") or "iOS " + ".".join(str(part) for part in version)
    return names


def available_devices(devices_json):
    found = []
    for runtime_id, devices in devices_json.get("devices", {}).items():
        version = ios_version(runtime_id)
        if version is None:
            continue
        for device in devices:
            if device.get("isAvailable", True) is False:
                continue
            found.append({"name": device.get("name", ""), "udid": device.get("udid", ""),
                          "runtime": runtime_id, "version": version})
    return found


def supporting_runtimes(type_id, runtimes_json):
    """Available iOS runtimes that can run a device type, newest first."""
    result = []
    for runtime in runtimes_json.get("runtimes", []):
        version = ios_version(runtime.get("identifier", ""))
        if version is None or runtime.get("isAvailable", True) is False:
            continue
        supported = runtime.get("supportedDeviceTypes")
        if supported is not None and type_id not in {item.get("identifier") for item in supported}:
            continue
        result.append((version, runtime["identifier"]))
    return [identifier for _, identifier in sorted(result, reverse=True)]


def mini_rank(name):
    if "A17 Pro" in name:
        return 3
    generation = re.search(r"\((\d+)(?:st|nd|rd|th) generation\)", name)
    # The 6th generation has the A17 Pro's 744 x 1133 pt; older minis are 768 x 1024 pt.
    return 2 if generation and int(generation.group(1)) >= 6 else 1


def model_number(name):
    match = re.search(r"iPhone (\d+)", name)
    return int(match.group(1)) if match else 0


def choose_phone(candidates):
    six = [device for device in candidates if device["name"] in SIX_ONE_INCH]
    if six:
        return min(six, key=lambda device: SIX_ONE_INCH.index(device["name"]))
    regular = [device for device in candidates
               if not re.search(r"Max|Plus|Air|mini|SE", device["name"])]
    if regular:
        return max(regular, key=lambda device: (model_number(device["name"]),
                                                device["name"] == f"iPhone {model_number(device['name'])}"))
    return None


def create_simulator(name, type_id, runtimes_json, names, run):
    runtimes = supporting_runtimes(type_id, runtimes_json)
    if not runtimes:
        raise SystemExit(f"No available iOS runtime runs {name}")
    try:
        udid = run(["xcrun", "simctl", "create", name, type_id, runtimes[0]]).strip()
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"simctl create {name} failed: {(error.stderr or '').strip()}")
    if not udid:
        raise SystemExit(f"simctl create returned no UDID for {name}")
    print(f"Created {name} on {names.get(runtimes[0], runtimes[0])}: {udid}", file=sys.stderr)
    return {"name": name, "udid": udid, "runtime": runtimes[0], "version": ios_version(runtimes[0])}


def named_simulator(name, devices, types, runtimes_json, names, run):
    exact = [device for device in devices if device["name"] == name]
    if exact:
        return max(exact, key=lambda device: device["version"])
    for device_type in types:
        if device_type.get("name") == name:
            return create_simulator(name, device_type["identifier"], runtimes_json, names, run)
    known = sorted({device["name"] for device in devices} | {item.get("name", "") for item in types})
    raise SystemExit(f"No Simulator or device type named {name!r}. Known: {', '.join(known)}")


def pick_simulators(devices_json, runtimes_json, types_json, iphone_name, ipad_name, run):
    devices = available_devices(devices_json)
    types = types_json.get("devicetypes", [])
    names = runtime_names(runtimes_json)

    if ipad_name:
        ipad = named_simulator(ipad_name, devices, types, runtimes_json, names, run)
    else:
        minis = [device for device in devices if device["name"].startswith("iPad mini")]
        if minis:
            ipad = max(minis, key=lambda device: (device["version"], mini_rank(device["name"])))
        else:
            mini_types = [item for item in types if item.get("name", "").startswith("iPad mini")]
            if not mini_types:
                raise SystemExit("No iPad mini Simulator or device type is available")
            best = max(mini_types, key=lambda item: mini_rank(item["name"]))
            ipad = create_simulator(best["name"], best["identifier"], runtimes_json, names, run)

    if iphone_name:
        iphone = named_simulator(iphone_name, devices, types, runtimes_json, names, run)
    else:
        phones = [device for device in devices if device["name"].startswith("iPhone")]
        # Prefer the iPad's runtime, then the newest runtime that has a suitable iPhone.
        iphone = choose_phone([device for device in phones if device["runtime"] == ipad["runtime"]])
        for version in sorted({device["version"] for device in phones}, reverse=True):
            if iphone is not None:
                break
            iphone = choose_phone([device for device in phones if device["version"] == version])
        if iphone is None:
            for wanted in SIX_ONE_INCH:
                match = [item for item in types if item.get("name") == wanted]
                if match and supporting_runtimes(match[0]["identifier"], runtimes_json):
                    iphone = create_simulator(wanted, match[0]["identifier"], runtimes_json, names, run)
                    break
        if iphone is None:
            raise SystemExit("No suitable iPhone Simulator or device type is available")

    lines = []
    for role, device in (("ipad", ipad), ("iphone", iphone)):
        runtime = names.get(device["runtime"]) or "iOS " + ".".join(str(part) for part in device["version"] or ())
        lines.append("\t".join([role, device["udid"], device["name"], runtime]))
    return lines


def simctl(command):
    return subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True,
                          text=True, check=True).stdout


def print_simulators(args):
    def read(path):
        return json.loads(Path(path).read_text(encoding="utf-8"))
    write_lines(pick_simulators(read(args.devices), read(args.runtimes), read(args.device_types),
                                (args.iphone or "").strip(), (args.ipad or "").strip(), simctl))
    return 0


# ---------------------------------------------------------------- compose

@functools.lru_cache(maxsize=None)
def face(size, weight=400):
    from PIL import ImageFont
    if FONT.exists():
        try:
            font = ImageFont.truetype(str(FONT), size)
            try:
                font.set_variation_by_axes([weight])
            except Exception:
                pass
            return font
        except OSError:
            pass
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def line_height(font):
    return round(getattr(font, "size", 11) * 1.4)


def text_width(draw, text, font):
    left, _, right, _ = draw.textbbox((0, 0), text, font=font)
    return right - left


def fit(draw, text, font, width):
    if text_width(draw, text, font) <= width:
        return text
    while text and text_width(draw, text + "...", font) > width:
        text = text[:-1]
    return text.rstrip() + "..."


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if line and text_width(draw, trial, font) > width:
            lines.append(line)
            line = word
        else:
            line = trial
    if line:
        lines.append(line)
    return lines


def block_height(lines):
    return sum(line_height(font) for _, font, _ in lines)


def draw_block(draw, x, y, width, lines):
    for text, font, color in lines:
        draw.text((x, y), fit(draw, text, font, width), font=font, fill=color)
        y += line_height(font)


def wrapped_lines(draw, items, width):
    result = []
    for text, font, color in items:
        result.extend((line, font, color) for line in wrap(draw, text, font, width))
    return result


def scaled(image, height):
    from PIL import Image
    resample = getattr(Image, "Resampling", Image).LANCZOS
    width = max(1, round(image.width * height / image.height))
    return image.resize((width, height), resample)


def status_text(status):
    return {
        "not-running": "warning: the app was not running at capture time (crash?)",
        "launch-failed": "the app did not launch",
        "no-screenshot": "simctl took no screenshot",
        "size-rejected": "simctl did not accept this text size",
        "install-failed": "the app could not be installed on this Simulator",
        "boot-failed": "this Simulator did not boot",
    }.get(status, f"capture status: {status}")


def scene_text(reference):
    text = f"scene: {reference['scene']}"
    if not reference["exact"]:
        text += f" (closest; wanted: {reference.get('wanted', 'another screen')})"
    return text


def notes(reference, small):
    items = []
    if not reference["exact"]:
        items.append(("Not the same screen: " + reference.get("note", ""), small, AMBER))
    elif reference.get("note"):
        items.append(("State: " + reference["note"], small, MUTED))
    return items


def pair_image(reference, android, capture, info, status, height):
    from PIL import Image, ImageDraw
    left, right = scaled(android, height), scaled(capture, height)
    margin = max(12, round(height * 0.03))
    title, detail = face(max(14, round(height * 0.026)), 700), face(max(12, round(height * 0.019)), 400)
    width = margin + left.width + margin + right.width + margin
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    left_lines = [("Android reference", title, TEXT),
                  (f"{number(reference)} - {reference['title']}", detail, MUTED)]
    applied = info.get("applied", "")
    size_line = f"text size: {info['size']}" + (f" (simctl: {applied})" if applied and applied != info["size"] else "")
    right_lines = [(f"iOS - {info['app']}", title, TEXT),
                   (f"{info['simulator']} - {info['runtime']}".strip(" -"), detail, MUTED),
                   (size_line, detail, MUTED),
                   (scene_text(reference), detail, MUTED if reference["exact"] else AMBER)]
    footer_items = notes(reference, detail)
    if status != "ok":
        footer_items.insert(0, (status_text(status), detail, RED))
    footer = wrapped_lines(probe, footer_items, width - 2 * margin)
    header_height = max(block_height(left_lines), block_height(right_lines))
    top = margin + header_height + margin // 2
    total = top + height + (margin // 2 + block_height(footer) if footer else 0) + margin
    canvas = Image.new("RGB", (width, total), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    draw_block(draw, margin, margin, left.width, left_lines)
    draw_block(draw, 2 * margin + left.width, margin, right.width, right_lines)
    canvas.paste(left, (margin, top))
    canvas.paste(right, (2 * margin + left.width, top))
    if footer:
        draw_block(draw, margin, top + height + margin // 2, width - 2 * margin, footer)
    return canvas


def combined_image(reference, android, panels, height):
    """panels: (first label, second label, label color, image or None)."""
    from PIL import Image, ImageDraw
    margin = max(12, round(height * 0.03))
    title, bold, detail = (face(max(16, round(height * 0.036)), 700), face(max(12, round(height * 0.024)), 700),
                           face(max(11, round(height * 0.021)), 400))
    images = [scaled(android, height)] + [scaled(image, height) if image is not None else None for _, _, _, image in panels]
    widths = [image.width if image is not None else round(height * 0.46) for image in images]
    width = margin + sum(widths) + margin * (len(widths) - 1) + margin
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    header = [(f"{number(reference)} - {reference['title']}", title, TEXT),
              (scene_text(reference), detail, MUTED if reference["exact"] else AMBER)]
    header += wrapped_lines(probe, notes(reference, detail), width - 2 * margin)
    labels = [("Android", "reference", MUTED)] + [(first, second, color) for first, second, color, _ in panels]
    label_height = line_height(bold) + line_height(detail)
    top = margin + block_height(header) + margin // 2 + label_height
    canvas = Image.new("RGB", (width, top + height + margin), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    draw_block(draw, margin, margin, width - 2 * margin, header)
    x = margin
    for image, panel_width, (first, second, color) in zip(images, widths, labels):
        draw_block(draw, x, top - label_height, panel_width, [(first, bold, TEXT), (second, detail, color)])
        if image is None:
            draw.rectangle([x, top, x + panel_width - 1, top + height - 1], fill=PLACEHOLDER)
            message = "no capture"
            draw.text((x + (panel_width - text_width(draw, message, bold)) // 2, top + height // 2),
                      message, font=bold, fill=MUTED)
        else:
            canvas.paste(image, (x, top))
        x += panel_width + margin
    return canvas


def read_tsv(path):
    if not path.is_file():
        return []
    lines = [line.rstrip("\r") for line in path.read_text(encoding="utf-8").split("\n") if line.strip()]
    if not lines:
        return []
    header = lines[0].split("\t")
    return [dict(zip(header, line.split("\t"))) for line in lines[1:]]


def size_rank(size):
    return TEXT_SIZES.index(size) if size in TEXT_SIZES else len(TEXT_SIZES)


def device_rank(device):
    return DEVICE_ORDER.index(device) if device in DEVICE_ORDER else len(DEVICE_ORDER)


def discover_variants(raw_root, known=()):
    """(device, text size) pairs with captures, plus those the run recorded without any."""
    variants = {(device, size) for device, size in known if device and size}
    for device_dir in raw_root.iterdir():
        if not device_dir.is_dir():
            continue
        for size_dir in device_dir.iterdir():
            if size_dir.is_dir() and any(size_dir.glob("*.png")):
                variants.add((device_dir.name, size_dir.name))
    return sorted(variants, key=lambda item: (device_rank(item[0]), item[0], size_rank(item[1]), item[1]))


def save(image, path, image_format):
    path.parent.mkdir(parents=True, exist_ok=True)
    if image_format == "png":
        image.save(path)
    else:
        image.save(path, quality=88, optimize=True)


def compose(raw_root, out_root, height, combined_height, image_format):
    from PIL import Image
    config = load_config()
    if not raw_root.is_dir():
        print(f"No raw captures at {raw_root}")
        return 1
    manifest = {(row.get("device"), row.get("text_size")): row for row in read_tsv(raw_root / "captures.tsv")}
    shots = read_tsv(raw_root / "shots.tsv")
    statuses = {(row.get("device"), row.get("text_size"), row.get("id")): row.get("status", "ok")
                for row in shots}
    # References the run tried; empty when there is no shots.tsv (e.g. hand-made captures).
    attempted = {row.get("id") for row in shots}
    variants = discover_variants(raw_root, list(manifest) + [key[:2] for key in statuses])
    if not variants:
        print(f"No captures under {raw_root}/<device>/<text size>/")
        return 1
    apps = sorted({row.get("app") for row in manifest.values() if row.get("app")})
    app = " / ".join(apps) or "iOS"

    def info(device, size):
        row = manifest.get((device, size), {})
        return {"app": row.get("app") or app, "simulator": row.get("simulator") or device,
                "runtime": row.get("runtime", ""), "size": size, "applied": row.get("applied", "")}

    extension = "png" if image_format == "png" else "jpg"
    out_root.mkdir(parents=True, exist_ok=True)
    reference_dir = ROOT / config["referenceDir"]
    report, skipped, made = [], [], 0
    for reference in config["references"]:
        rid = reference["id"]
        has_capture = any((raw_root / device / size / f"{rid}.png").is_file() for device, size in variants)
        if attempted and rid not in attempted and not has_capture:
            skipped.append(rid)
            continue
        entry = {"id": rid, "title": reference["title"], "scene": reference["scene"], "exact": reference["exact"],
                 "wanted": reference.get("wanted"), "note": reference.get("note", ""),
                 "pairs": [], "missing": [], "problems": [], "combined": None}
        report.append(entry)
        with Image.open(reference_dir / f"{rid}.png") as source:
            android = source.convert("RGB")
        panels = []
        for device, size in variants:
            details = info(device, size)
            label = details["simulator"]
            capture_path = raw_root / device / size / f"{rid}.png"
            status = statuses.get((device, size, rid), "ok")
            if not capture_path.is_file():
                status = "missing" if status == "ok" else status
                entry["missing"].append(f"{device}/{size} ({status})")
                panels.append((label, f"text {size}: {status}", RED, None))
                continue
            with Image.open(capture_path) as source:
                capture = source.convert("RGB")
            if status != "ok":
                entry["problems"].append(f"{device}/{size}: {status}")
            output = out_root / device / size / f"{rid}.{extension}"
            save(pair_image(reference, android, capture, details, status, height), output, image_format)
            entry["pairs"].append({"device": device, "size": size, "label": f"{label} - {size}",
                                   "path": output.relative_to(out_root).as_posix(), "status": status})
            made += 1
            panels.append((label, f"text {size}" + ("" if status == "ok" else f": {status}"),
                           MUTED if status == "ok" else RED, capture))
            print(f"{output.relative_to(out_root).as_posix()}")
        if entry["pairs"]:
            output = out_root / "combined" / f"{rid}.{extension}"
            save(combined_image(reference, android, panels, combined_height), output, image_format)
            entry["combined"] = output.relative_to(out_root).as_posix()

    variant_info = [info(device, size) for device, size in variants]
    write_index(out_root, app, variant_info, report, skipped)
    write_summary(out_root, app, variant_info, report, skipped)
    for entry in report:
        if entry["missing"]:
            print(f"missing {entry['id']}: {', '.join(entry['missing'])}")
    if skipped:
        print(f"not selected in this run: {', '.join(skipped)}")
    print(f"{made} side-by-side images written to {out_root}")
    return 0 if made else 1


def describe_variants(variant_info):
    devices = []
    for item in variant_info:
        name = f"{item['simulator']} ({item['runtime']})" if item["runtime"] else item["simulator"]
        if name not in devices:
            devices.append(name)
    sizes = []
    for item in variant_info:
        if item["size"] not in sizes:
            sizes.append(item["size"])
    return ", ".join(devices), ", ".join(sizes)


def write_index(out_root, app, variant_info, report, skipped):
    devices, sizes = describe_variants(variant_info)
    sections = []
    if skipped:
        sections.append(f'<p class="note">Not selected in this run: {html.escape(", ".join(skipped))}.</p>')
    for entry in report:
        if entry["exact"]:
            match = '<span class="ok">same screen</span>'
        else:
            match = f'<span class="warn">closest scene; wanted: {html.escape(entry["wanted"] or "another screen")}</span>'
        parts = [f'<section id="{html.escape(entry["id"])}">',
                 f'<h2>{html.escape(entry["id"].split("-", 1)[0])} &middot; {html.escape(entry["title"])}</h2>',
                 f'<p class="meta">scene <code>{html.escape(entry["scene"])}</code> &middot; {match}</p>']
        if entry["note"]:
            parts.append(f'<p class="note">{html.escape(entry["note"])}</p>')
        if entry["combined"]:
            parts.append(f'<a href="{html.escape(entry["combined"])}"><img src="{html.escape(entry["combined"])}" '
                         f'loading="lazy" alt="{html.escape(entry["title"])}: Android and iOS"></a>')
            links = " ".join(f'<a href="{html.escape(pair["path"])}">{html.escape(pair["label"])}</a>'
                             for pair in entry["pairs"])
            parts.append(f'<p class="pairs">Side by side: {links}</p>')
        else:
            parts.append('<p class="warn">Not captured in this run.</p>')
        for problem in entry["missing"]:
            parts.append(f'<p class="bad">No capture: {html.escape(problem)}</p>')
        for problem in entry["problems"]:
            parts.append(f'<p class="bad">{html.escape(problem)}</p>')
        parts.append("</section>")
        sections.append("\n".join(parts))
    write_text(
        out_root / "index.html",
        "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        "<title>Android parity</title><style>"
        "body{font-family:system-ui,sans-serif;background:#1e1f24;color:#eee;margin:0;padding:16px}"
        "h1{font-size:22px;margin:0 0 4px}h2{font-size:18px;margin:0 0 4px}"
        "section{margin:24px 0;padding-top:12px;border-top:1px solid #444}"
        "img{max-width:100%;height:auto;display:block;margin:8px 0}"
        "a{color:#8ab4ff}code{color:#ffd27f}.meta,.note,.pairs{margin:4px 0;font-size:14px}"
        ".note{color:#bbb}.ok{color:#7fdc9a}.warn{color:#ffc45c}.bad{color:#ff7070;margin:2px 0}"
        "</style></head><body>\n"
        f"<h1>Android parity: {html.escape(app)}</h1>\n"
        f"<p class=\"meta\">Left: the Android reference (docs/reference/android-ui). Right: the iOS Simulator "
        f"capture at the same height. Devices: {html.escape(devices)}. Text sizes: {html.escape(sizes)}.</p>\n"
        + "\n".join(sections) + "\n</body></html>\n")


def write_summary(out_root, app, variant_info, report, skipped):
    devices, sizes = describe_variants(variant_info)
    expected = len(variant_info)
    lines = [f"## Android parity: {app}", "",
             f"Devices: {devices}. Text sizes: {sizes}.", "",
             "| Reference | Scene | Same screen | Captured | Problems |", "|---|---|---|---|---|"]
    for entry in report:
        same = "yes" if entry["exact"] else f"no (wanted: {entry['wanted'] or 'another screen'})"
        problems = "; ".join([f"no capture {item}" for item in entry["missing"]] + entry["problems"])
        lines.append(f"| {entry['id'].split('-', 1)[0]} {entry['title']} | `{entry['scene']}` | {same} | "
                     f"{len(entry['pairs'])}/{expected} | {problems} |")
    if skipped:
        lines += ["", f"Not selected in this run: {', '.join(skipped)}."]
    write_text(out_root / "summary.md", "\n".join(lines) + "\n")
    write_text(out_root / "summary.json",
               json.dumps({"app": app, "variants": variant_info, "references": report,
                           "notSelected": skipped}, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("validate")
    check.add_argument("--app", default="")
    check.add_argument("--text-sizes", default="")
    check.add_argument("--references", default="")
    scenes = commands.add_parser("scenes")
    scenes.add_argument("--app", required=True)
    scenes.add_argument("--references", default="")
    simulators = commands.add_parser("simulators")
    simulators.add_argument("--devices", required=True)
    simulators.add_argument("--runtimes", required=True)
    simulators.add_argument("--device-types", required=True)
    simulators.add_argument("--iphone", default="")
    simulators.add_argument("--ipad", default="")
    composer = commands.add_parser("compose")
    composer.add_argument("--raw", type=Path, required=True)
    composer.add_argument("--out", type=Path, required=True)
    composer.add_argument("--height", type=int, default=1200)
    composer.add_argument("--combined-height", type=int, default=900)
    composer.add_argument("--format", choices=("jpg", "png"), default="jpg")
    args = parser.parse_args()
    if args.command == "validate":
        return validate(args.app, args.text_sizes, args.references)
    if args.command == "scenes":
        return print_scenes(args.app, args.references)
    if args.command == "simulators":
        return print_simulators(args)
    return compose(args.raw.resolve(), args.out.resolve(), args.height, args.combined_height, args.format)


if __name__ == "__main__":
    sys.exit(main())

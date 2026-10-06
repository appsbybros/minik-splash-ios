"""App Store screenshots: frames raw Simulator captures with a branded background
and caption at Apple's exact sizes.

  python Scripts/appstore-screenshots.py scenes <App>
      Lines "id|scene|wait|iphone orientation|ipad orientation" for the capture workflow.
  python Scripts/appstore-screenshots.py compose --raw <dir> --out <dir> [--apps A B]
      Reads <raw>/<App>/<lang>/<device>/<id>.png and writes the framed images plus
      index.html. Needs Pillow and Chrome or Edge (set CHROME to choose a browser).

Captions, scenes and palettes live in appstore/screenshots.json.
"""
import argparse
import html
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / "appstore/screenshots.json").read_text(encoding="utf-8"))
FONT = ROOT / "appstore/fonts/Heebo-Variable.ttf"
RTL = {"he", "ar"}


def orientation(app, scene, device):
    for source in (scene, app):
        value = source.get("orientation")
        if isinstance(value, dict) and device in value:
            return value[device]
        if isinstance(value, str):
            return value
    return "portrait"


def print_scenes(app_name):
    app = CONFIG["apps"][app_name]
    for scene in app["scenes"]:
        print("|".join([scene["id"], scene["scene"], str(scene.get("wait", 6)),
                        orientation(app, scene, "iphone"), orientation(app, scene, "ipad")]))
    return 0


def find_browser():
    candidates = [os.environ.get("CHROME", ""),
                  "C:/Program Files/Google/Chrome/Application/chrome.exe",
                  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
                  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"]
    candidates += [shutil.which(name) or "" for name in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser")]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate
    sys.exit("No Chrome or Edge found; set CHROME to the browser executable.")


def page(width, height, landscape, language, palette, caption, image_uri):
    base = min(width, height)
    rtl = language in RTL
    eyebrow, title, subtitle = (caption + ["", "", ""])[:3]
    pad = round(base * 0.075)
    align = ("right" if rtl else "left") if landscape else "center"
    blobs = "".join(
        f'<div class="blob" style="width:{round(base * size)}px;height:{round(base * size)}px;'
        f'{side}:{round(base * dx)}px;top:{round(height * dy)}px"></div>'
        for size, side, dx, dy in ((0.9, "right", -0.35, 0.55), (0.7, "left", -0.3, 0.78), (0.5, "left", -0.2, -0.08)))
    return f"""<!doctype html><html lang="{language}" dir="{'rtl' if rtl else 'ltr'}"><meta charset="utf-8">
<style>
@font-face{{font-family:Heebo;src:url('{FONT.as_uri()}') format('truetype');font-weight:100 900}}
*{{box-sizing:border-box;margin:0}}
html,body{{width:{width}px;height:{height}px;overflow:hidden}}
body{{font-family:Heebo,'Segoe UI',Arial,sans-serif;position:relative;color:{palette['text']};
  background:linear-gradient(165deg,{palette['top']} 0%,{palette['bottom']} 100%);
  display:grid;grid-template-rows:auto 1fr;padding:{round(base * 0.06)}px {pad}px {round(base * 0.04)}px}}
.blob{{position:absolute;border-radius:50%;background:rgba(255,255,255,.09)}}
.copy{{position:relative;text-align:{align}}}
.eyebrow{{color:{palette['eyebrow']};font-weight:800;letter-spacing:.03em;font-size:{round(base * 0.034)}px;line-height:1.2}}
h1{{color:{palette['title']};font-weight:800;font-size:{round(base * 0.078)}px;line-height:1.08;margin-top:{round(base * 0.014)}px}}
p{{font-size:{round(base * 0.04)}px;line-height:1.3;margin-top:{round(base * 0.016)}px}}
.shot{{position:relative;min-height:0;display:flex;align-items:center;justify-content:center;padding-top:{round(base * 0.045)}px}}
.shot img{{max-width:100%;max-height:100%;display:block;border:{max(4, round(base * 0.007))}px solid rgba(255,255,255,.96);
  border-radius:{round(base * 0.035)}px;box-shadow:0 {round(base * 0.012)}px {round(base * 0.04)}px rgba(10,10,40,.38)}}
</style>
<body>{blobs}
<div class="copy"><div class="eyebrow">{html.escape(eyebrow)}</div><h1>{html.escape(title)}</h1><p>{html.escape(subtitle)}</p></div>
<div class="shot"><img src="{image_uri}"></div>
</body></html>"""


def render(browser, html_text, width, height, output, workdir):
    from PIL import Image
    source = workdir / (output.stem + ".html")
    source.write_text(html_text, encoding="utf-8")
    shot = workdir / (output.stem + "-render.png")
    command = [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
               "--allow-file-access-from-files", "--virtual-time-budget=3000",
               f"--window-size={width},{height}", f"--screenshot={shot}", source.as_uri()]
    subprocess.run(command, check=True, capture_output=True, timeout=120)
    with Image.open(shot) as image:
        if image.size != (width, height):
            raise SystemExit(f"{output}: the browser rendered {image.size}, expected {(width, height)}")
        output.parent.mkdir(parents=True, exist_ok=True)
        # App Store Connect wants opaque screenshots: no alpha channel.
        image.convert("RGB").save(output, optimize=True)


def prepared_capture(raw, landscape, workdir):
    """Returns a capture turned the right way up for the frame."""
    from PIL import Image
    with Image.open(raw) as image:
        rotate = landscape != (image.width > image.height)
        if not rotate:
            return raw
        # A landscape interface on a portrait Simulator display: its top faces the
        # display's right edge (landscapeRight), so turn it counterclockwise.
        turned = workdir / (raw.parent.parent.name + "-" + raw.parent.name + "-" + raw.name)
        image.rotate(90, expand=True).save(turned)
        return turned


def compose(raw_root, out_root, apps):
    browser = find_browser()
    out_root.mkdir(parents=True, exist_ok=True)
    made, missing = [], []
    with tempfile.TemporaryDirectory() as temp:
        workdir = Path(temp)
        for app_name in apps:
            app = CONFIG["apps"][app_name]
            palette = CONFIG["palettes"][app["palette"]]
            for language in app["languages"]:
                for device, sizes in CONFIG["devices"].items():
                    for scene in app["scenes"]:
                        raw = raw_root / app_name / language / device / f"{scene['id']}.png"
                        if not raw.exists():
                            missing.append(raw)
                            continue
                        landscape = orientation(app, scene, device) == "landscape"
                        width, height = sizes["landscape" if landscape else "portrait"]
                        caption = scene["caption"].get(language) or scene["caption"]["en"]
                        capture = prepared_capture(raw, landscape, workdir)
                        output = out_root / app_name / language / device / f"{scene['id']}.png"
                        render(browser, page(width, height, landscape, language, palette, caption, capture.as_uri()),
                               width, height, output, workdir)
                        made.append(output)
                        print(f"{output.relative_to(out_root)}  {width}x{height}")
    write_index(out_root, made)
    for raw in missing:
        print(f"missing capture: {raw}")
    print(f"{len(made)} screenshots written to {out_root}")
    return 1 if not made else 0


def write_index(out_root, made):
    rows = []
    for path in made:
        relative = path.relative_to(out_root).as_posix()
        rows.append(f'<figure><img src="{relative}" loading="lazy"><figcaption>{html.escape(relative)}</figcaption></figure>')
    (out_root / "index.html").write_text(
        "<!doctype html><meta charset='utf-8'><title>App Store screenshots</title>"
        "<style>body{font-family:sans-serif;background:#222;color:#eee;display:flex;flex-wrap:wrap;gap:16px;padding:16px}"
        "figure{margin:0}img{height:420px;display:block}figcaption{font-size:12px;margin-top:4px}</style>"
        + "".join(rows), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    scenes = commands.add_parser("scenes")
    scenes.add_argument("app")
    composer = commands.add_parser("compose")
    composer.add_argument("--raw", type=Path, required=True)
    composer.add_argument("--out", type=Path, required=True)
    composer.add_argument("--apps", nargs="*", default=list(CONFIG["apps"]))
    args = parser.parse_args()
    if args.command == "scenes":
        return print_scenes(args.app)
    return compose(args.raw.resolve(), args.out.resolve(), args.apps)


if __name__ == "__main__":
    sys.exit(main())

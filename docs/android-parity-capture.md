# Android parity captures

Puts each iOS screen beside its Android reference screenshot (`docs/reference/android-ui`, 16 PNGs), on an iPad mini and an iPhone Simulator, at two text sizes. It shows how far a screen is from Android; it does not decide that a screen is done.

## Run it

1. GitHub → Actions → **Android parity captures** → Run workflow. Manual only; pushes never start it.
   - **app**: MinikPlus (Hebrew interface, like the references) or MinikPlusEnglish.
   - **text_sizes**: `simctl ui content_size` names, default `large extra-extra-large` (the default size, and a larger one like the tester's iPad mini). One size halves the run.
   - **references**: e.g. `01 09 16`; empty captures all 16.
   - **iphone** / **ipad**: Simulator names; empty picks the newest iPad mini (744 × 1133 pt, created if the runner has none) and a 6.1-inch iPhone on the same iOS version, else the newest non-Max iPhone.
2. The run builds the app once (Debug, Simulator), boots both Simulators in light mode with a 9:41 status bar, and for each text size launches every scene with `-MinikScreenshotScene <scene>` and takes a screenshot. That is 64 launches, each followed by a 6 to 8 second wait, for all references at two sizes.
3. Download **Android-parity-side-by-side** and open `index.html`:
   - `combined/<id>.jpg`: the reference and every capture in one row, same height.
   - `<ipad|iphone>/<text size>/<id>.jpg`: the reference on the left and one capture on the right, same height, labelled with Simulator, iOS version, text size and scene.
   - `summary.md` (also on the run page) and `summary.json`.

   **Android-parity-raw** holds the raw PNGs (`parity-raw/<device>/<text size>/<id>.png`), `captures.tsv` and `shots.tsv`, the Simulator lists, crash reports (`parity/crashes`) and the build log.

## Reading the result

- Each capture opens a fresh screen. Many references show a later state (Minik's success jump, a picked card, a partly built word, the Soccer "Sorry" result). The note under each image says how the states differ; compare composition, proportions, artwork, controls and type sizes.
- The Points / Current streak / Best streak badges are seeded with 211 / 4 / 13, as in the references, through the `-minik.rewards.v1` launch argument, which lasts only for that launch. If they show 0, the seed was not read; the layout is still comparable.
- The capture job fails (red) when any shot is not clean: the app was not running at capture time (crash; the image is then marked in red), did not launch, gave no screenshot, could not be installed, a Simulator did not boot, simctl rejected a text size, or fewer shots were recorded than devices × sizes × scenes. The side-by-side images are still made for what was captured.

## Mapping

`appstore/parity.json` maps each reference to a scene:

| Reference | Scene |
|---|---|
| 01 word to picture | `language.wordToImage` |
| 02 picture to word | `language.imageToWord` |
| 03 first letter, picture to letter | `language.firstLetterChoices` |
| 04 first letter, letter to picture | `language.firstLetterPictures` |
| 05 word cards | `language.wordCards` |
| 06 build the word | `language.wordBuild` |
| 07 letter pairs | `language.letterPairs` |
| 08 Soccer instructions | `language.soccer`, introduction forced on |
| 09 Soccer gameplay | `language.soccer`, introduction skipped |
| 10 picture memory | `language.wordMemory` |
| 11 alphabet blocks | `language.tower` |
| 12 tic-tac-toe | `language.ticTacToe` |
| 13 learn a letter | `language.learn` |
| 14 activity menu (top) | `menu` |
| 15 activity menu (Games) | `menu.games`, the menu scrolled to its end |
| 16 Parent Area | `parents` |

`MinikActivityHubView.applyStoreScreenshotScene` opens the activity menu (`LanguageMenuView`) for `menu` and `menu.games`; for `menu.games` the menu scrolls to its end once it knows more of the board lies below (`LanguageMenuView.applyStoreScreenshotScroll`). Captures skip the menu's first-visit "more below" hint and spoken prompt, which the references do not show. A reference whose screen no scene opens can still be mapped to the closest scene with `exact: false`.

Fields: `scene` (passed as `-MinikScreenshotScene`), `exact` (false when the scene is only the closest), `wanted` and `wantedScene` (the screen and the scene a closest mapping is waiting for), `wait` (seconds before the screenshot, default `defaultWait`), `arguments` (extra `-key value` launch arguments, no spaces), `note`. `apps` holds each app's language arguments.

## Run parts locally

```
python Scripts/parity-compose.py validate --app MinikPlus --text-sizes "large extra-extra-large"
python Scripts/parity-compose.py scenes --app MinikPlus
python Scripts/parity-compose.py compose --raw <Android-parity-raw>/parity-raw --out build/android-parity
```

`validate` needs only Python. `compose` needs Pillow (`python -m pip install --user pillow`) and works on Windows, macOS and Linux; `--format png` keeps the images lossless, `--height` sets the pair height (default 1200 px).

The app reads `-MinikScreenshotScene` only in `Sources/StoreScreenshotScene.swift` and the hub; normal launches never pass it.

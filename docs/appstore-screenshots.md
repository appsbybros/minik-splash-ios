# App Store screenshots

Framed, captioned screenshots at Apple's required sizes, made from real Simulator captures:

| Device slot in App Store Connect | Portrait | Landscape |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | 2868 × 1320 |
| iPad 13" | 2064 × 2752 | 2752 × 2064 |

Apple scales these down for smaller devices, so no other sizes are needed.

## Make them

1. GitHub → Actions → **App Store screenshots** → Run workflow (all five apps by default, or a space-separated list).
2. The run builds Debug Simulator apps (no ads, no purchases), opens each scene on an iPhone Pro Max and an iPad Pro 13-inch Simulator in every listed language, and captures it with a 9:41 status bar.
3. Download the **AppStore-screenshots** artifact: `<App>/<language>/<iphone|ipad>/NN-scene.png`, plus `index.html` to preview them all. **AppStore-raw-screenshots** holds the unframed captures and build logs.

To re-frame without a new capture (e.g. after editing a caption), download the raw artifact and run locally:

```
python Scripts/appstore-screenshots.py compose --raw <raw artifact>/appstore-raw --out build/appstore-screenshots
```

This needs Pillow (`python -m pip install --user pillow`) and Chrome or Edge (set `CHROME` to pick one).

## Edit

Everything lives in `appstore/screenshots.json`:

- **Captions**: `[eyebrow, title, subtitle]` per language. Do not write "for kids" or "for children": Apple reserves those words for apps in the Kids category.
- **Scenes**: `scene` is passed to the app as `-MinikScreenshotScene` (`home`, `opening`, `progress`, `parents`, `language.<activity>`, `math.<activity>`, `bounce.setup|play|train|help`, `pong.play|guide|rival`). `wait` is seconds before the capture.
- **Ping Pong** captures run offline (`-MinikOfflineSmoke`), so friendly games and tournaments, which need live rooms, are not captured.
- **Orientation**: Bounce is landscape on iPhone (its game only runs in landscape there) and portrait on iPad.
- **Palettes**: background gradient and text colors per app family, matching the Play Store art.

The app hooks (`Sources/StoreScreenshotScene.swift`, the hub, `RetroPongView` and `ios-host.js`) act only when the launch argument is present, which never happens for users. Bounce capture progress is staged in memory and never saved.

## Upload

App Store Connect → the app → the version page → **Previews and Screenshots** → pick the language at the top right → drag the `iphone` images into the 6.9" slot and the `ipad` images into the 13" slot. Up to 10 per slot; the first three show in search results.

The Heebo font (`appstore/fonts`) is under the SIL Open Font License (`OFL-Heebo.txt`).

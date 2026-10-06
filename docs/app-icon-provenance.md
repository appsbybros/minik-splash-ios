# App icon provenance

The two Language app icons are deterministic compositions of the existing
production Android adaptive-icon assets. No replacement branding or generated
artwork is used.

| iOS set | Android source contract |
| --- | --- |
| `MinikPlusAppIcon` | `android/app/src/plus/res/mipmap-anydpi-v26/ic_launcher.xml`: `minik_plus_logo_small.png` over `bg_colorful_back_for_logo.xml` (`#DAE2E1`) |
| `MinikPlusEnglishAppIcon` | the `plus-english-only` flavor has no launcher override, so `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`: `minik_logo333.png` over `bg_card_front_kids2.xml` (`#03A9F4` / `#3F51B5` / `#009688`) |

`Scripts/migrate-android-app-icons.ps1` performs the 1024-by-1024 opaque raster
composition used by the checked-in Xcode asset sets. Apple applies the final
platform mask; rounded corners are not baked into the source.

No established Minik Math or standalone Minik Ping Pong App Store icon was
found in the workspace or Git history. Those two targets intentionally keep the
app-icon build setting empty rather than repurposing unrelated branding.

# Trusted vocabulary assets

The 33 trusted-acquisition rows are complete: 32 national flags and one Africa
silhouette. The exact per-asset source version, source URL, source SHA-256,
output SHA-256, retrieval date, license, and render method are recorded in
`vocabulary-trusted-asset-provenance.tsv`.

## Sources

- National flags use the 4-by-3 SVG set from `flag-icons` commit
  `fe15c16e7463d0c66d6c5730e9d0e832438d98e1` under its MIT license. Each SVG is
  centered without distortion in an otherwise transparent 1024-by-1024 canvas.
- The Africa silhouette uses the `CONTINENT=AFRICA` polygons from Natural Earth
  commit `ca96624a56bd078437bca8184e78163e5039ad19`. Natural Earth places its vector
  map data in the public domain. The polygons are merged visually into one
  simple, child-readable silhouette with no political boundary lines.

The complete `flag-icons` notice and the Natural Earth public-domain notice are
bundled with both Language products in
`Resources/ThirdPartyNotices/VocabularyAssetNotices.txt`.

## Reproduction

The importer expects the pinned source archive and GeoJSON in the existing
workspace staging directory and verifies their complete-file SHA-256 values
before rendering:

```powershell
& .\Scripts\import-trusted-vocabulary-assets.ps1
```

The importer is idempotent. It refuses to overwrite an imageset when a fresh
render differs from the current reviewed output. The vocabulary asset audit
also verifies the outer source files, every selected SVG entry inside the ZIP,
all report hashes, manifest lifecycle state, output names, and decoded PNG
dimensions.

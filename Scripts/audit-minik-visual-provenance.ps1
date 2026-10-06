$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'docs/minik-visual-asset-provenance.tsv'
$errors = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Error "Missing visual provenance manifest: $manifestPath"
    exit 1
}

$rows = @(Import-Csv -LiteralPath $manifestPath -Delimiter "`t")
$requiredColumns = @(
    'ios_asset',
    'android_source_path',
    'android_source_filename',
    'activity_or_use',
    'source_sha256',
    'sharing'
)
$actualColumns = @($rows[0].PSObject.Properties.Name)
foreach ($column in $requiredColumns) {
    if ($column -notin $actualColumns) {
        $errors.Add("Missing provenance column: $column")
    }
}

$duplicateAssets = @($rows | Group-Object ios_asset | Where-Object Count -ne 1)
foreach ($duplicate in $duplicateAssets) {
    $errors.Add("Expected one provenance row for $($duplicate.Name); found $($duplicate.Count).")
}

$python = Get-Command python -ErrorAction SilentlyContinue
$pillowAvailable = $false
if ($null -ne $python) {
    & $python.Source -c 'from PIL import Image' 2>$null
    $pillowAvailable = $LASTEXITCODE -eq 0
}
if (-not $pillowAvailable) {
    $errors.Add('Python Pillow is required for decoded-pixel provenance verification.')
}

$pixelComparison = "from PIL import Image; import sys; a=Image.open(sys.argv[1]).convert('RGBA'); b=Image.open(sys.argv[2]).convert('RGBA'); raise SystemExit(0 if a.size == b.size and a.tobytes() == b.tobytes() else 1)"

foreach ($row in $rows) {
    $sourcePath = Join-Path $repoRoot $row.android_source_path
    $iosPath = Join-Path $repoRoot "Resources/MinikVisuals.xcassets/$($row.ios_asset).imageset/$($row.ios_asset).png"

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $errors.Add("Missing Android source: $sourcePath")
        continue
    }
    if (-not (Test-Path -LiteralPath $iosPath -PathType Leaf)) {
        $errors.Add("Missing iOS image: $iosPath")
        continue
    }
    if ([IO.Path]::GetFileName($sourcePath) -ne $row.android_source_filename) {
        $errors.Add("Source filename mismatch for $($row.ios_asset).")
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
    if ($actualHash -ne $row.source_sha256) {
        $errors.Add("Android source SHA-256 mismatch for $($row.ios_asset).")
    }

    if ($pillowAvailable) {
        & $python.Source -c $pixelComparison $sourcePath $iosPath
        if ($LASTEXITCODE -ne 0) {
            $errors.Add("Decoded pixels differ for $($row.ios_asset).")
        }
    }
}

Write-Output "MINIK_VISUAL_PROVENANCE_ROWS=$($rows.Count)"
Write-Output "MINIK_VISUAL_PROVENANCE_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'MINIK_VISUAL_PROVENANCE_AUDIT_OK'

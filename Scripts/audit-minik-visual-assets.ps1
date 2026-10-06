$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$catalog = Join-Path $repoRoot 'Resources/MinikVisuals.xcassets'
$projectSpec = Join-Path $repoRoot 'project.yml'
$expectedAssets = @(
    'minik_activity_build',
    'minik_activity_build_hebrew',
    'minik_activity_cards',
    'minik_activity_cards_hebrew',
    'minik_activity_choice',
    'minik_activity_first_letter_english',
    'minik_activity_first_letter_hebrew',
    'minik_activity_learn_english',
    'minik_activity_learn_hebrew',
    'minik_activity_memory',
    'minik_activity_mixed',
    'minik_activity_pairs',
    'minik_activity_picture_to_word',
    'minik_activity_soccer',
    'minik_activity_tic_tac_toe',
    'minik_activity_tower',
    'minik_activity_word_to_picture',
    'minik_background',
    'minik_cards_background',
    'minik_close',
    'minik_feedback_success',
    'minik_feedback_try_again',
    'minik_home',
    'minik_logo',
    'minik_language_logo',
    'minik_memory_mascot',
    'minik_memory_scene',
    'minik_soccer_ball',
    'minik_soccer_field',
    'minik_soccer_goal',
    'minik_soccer_goalie',
    'minik_speaker',
    'minik_tower_mascot',
    'minik_tower_sand',
    'minik_tower_sand_pile',
    'minik_tower_scene',
    'minik_tic_tac_toe_mascot',
    'minik_tic_tac_toe_scene',
    'minik_trophy',
    'minik_welcome'
)

$errors = [System.Collections.Generic.List[string]]::new()
$manifestPath = Join-Path $repoRoot 'docs/minik-visual-asset-provenance.tsv'
$manifestRows = @()
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    $errors.Add("Missing visual provenance manifest: $manifestPath")
} else {
    $manifestRows = @(Import-Csv -LiteralPath $manifestPath -Delimiter "`t")
}
foreach ($asset in $expectedAssets) {
    $imageset = Join-Path $catalog "$asset.imageset"
    $contentsPath = Join-Path $imageset 'Contents.json'
    $imagePath = Join-Path $imageset "$asset.png"
    if (-not (Test-Path -LiteralPath $contentsPath -PathType Leaf)) {
        $errors.Add("Missing catalog metadata: $contentsPath")
        continue
    }
    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
        $errors.Add("Missing image: $imagePath")
        continue
    }
    if ((Get-Item -LiteralPath $imagePath).Length -le 0) {
        $errors.Add("Empty image: $imagePath")
    }
    $contents = Get-Content -LiteralPath $contentsPath -Raw | ConvertFrom-Json
    if ($contents.images.Count -ne 1 -or $contents.images[0].filename -ne "$asset.png") {
        $errors.Add("Unexpected image reference: $contentsPath")
    }

    $provenance = @($manifestRows | Where-Object { $_.ios_asset -eq $asset })
    if ($provenance.Count -ne 1) {
        $errors.Add("Expected exactly one provenance row for $asset; found $($provenance.Count).")
    } elseif (-not (Test-Path -LiteralPath (Join-Path $repoRoot $provenance[0].android_source_path) -PathType Leaf)) {
        $errors.Add("Missing Android provenance source for ${asset}: $($provenance[0].android_source_path)")
    }
}

$unexpected = Get-ChildItem -LiteralPath $catalog -Directory -Filter '*.imageset' |
    ForEach-Object { $_.Name -replace '\.imageset$', '' } |
    Where-Object { $_ -notin $expectedAssets }
foreach ($asset in $unexpected) {
    $errors.Add("Unexpected shared visual asset: $asset")
}

$unexpectedProvenance = @($manifestRows | Where-Object { $_.ios_asset -notin $expectedAssets })
foreach ($row in $unexpectedProvenance) {
    $errors.Add("Unexpected provenance asset: $($row.ios_asset)")
}

$projectText = Get-Content -LiteralPath $projectSpec -Raw
if ($projectText -notmatch '(?m)^\s*- path: Resources/MinikVisuals\.xcassets\s*$') {
    $errors.Add('project.yml does not include Resources/MinikVisuals.xcassets.')
}

Write-Output "MINIK_VISUAL_ASSETS_EXPECTED=$($expectedAssets.Count)"
Write-Output "MINIK_VISUAL_ASSET_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'MINIK_VISUAL_ASSET_AUDIT_OK'

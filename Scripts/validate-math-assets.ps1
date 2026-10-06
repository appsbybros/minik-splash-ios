param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $RepositoryRoot 'Resources/MathObjectManifest.json'
$catalogPath = Join-Path $RepositoryRoot 'Resources/MathObjects.xcassets'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$records = @($manifest.objects) + @($manifest.zeroStates) + @($manifest.groupingSupport)
$errors = [System.Collections.Generic.List[string]]::new()

if (@($manifest.objects).Count -ne 100) { $errors.Add('Expected 100 countable objects.') }
if (@($manifest.zeroStates).Count -ne 3) { $errors.Add('Expected 3 zero-state assets.') }
if (@($manifest.groupingSupport).Count -ne 6) { $errors.Add('Expected 6 grouping-support assets.') }

$expectedCategories = @('animals','everyday','food','fruits','nature','school','science-space','toys','treasures','treats')
$actualCategories = @($manifest.objects.category | Sort-Object -Unique)
if (Compare-Object $expectedCategories $actualCategories) {
    $errors.Add('Countable-object category coverage does not match the approved pack.')
}

$duplicates = @($records | Group-Object id | Where-Object Count -gt 1)
foreach ($duplicate in $duplicates) { $errors.Add("Duplicate stable ID: $($duplicate.Name)") }

foreach ($record in $records) {
    if ($record.id -match 'ChatGPT|Image Sep|\s') { $errors.Add("Unstable production ID: $($record.id)") }
    $imageSet = Join-Path $catalogPath ($record.assetName + '.imageset')
    $contentsPath = Join-Path $imageSet 'Contents.json'
    if (-not (Test-Path -LiteralPath $contentsPath)) {
        $errors.Add("Missing Contents.json: $($record.assetName)")
        continue
    }
    try { $contents = Get-Content -LiteralPath $contentsPath -Raw | ConvertFrom-Json } catch {
        $errors.Add("Invalid Contents.json: $($record.assetName)")
        continue
    }
    $filename = @($contents.images | Where-Object { $_.filename })[0].filename
    if (-not $filename -or -not (Test-Path -LiteralPath (Join-Path $imageSet $filename))) {
        $errors.Add("Missing referenced image: $($record.assetName)")
    }
}

$imageSetCount = @(Get-ChildItem -LiteralPath $catalogPath -Directory -Filter '*.imageset').Count
if ($imageSetCount -ne $records.Count) { $errors.Add("Image set count $imageSetCount does not match manifest count $($records.Count).") }

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "MATH_ASSET_ERRORS=0"
Write-Output "MATH_OBJECTS=$(@($manifest.objects).Count)"
Write-Output "MATH_ZERO_STATES=$(@($manifest.zeroStates).Count)"
Write-Output "MATH_GROUPING_SUPPORT=$(@($manifest.groupingSupport).Count)"
Write-Output "MATH_ASSET_CATEGORIES=$($actualCategories.Count)"

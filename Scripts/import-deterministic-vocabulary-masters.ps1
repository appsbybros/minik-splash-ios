param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$MasterRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'artwork-staging\masters')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$catalogRoot = Join-Path $RepositoryRoot 'Resources\LanguageImages.xcassets'
$runtimeManifestPath = Join-Path $RepositoryRoot 'Resources\Vocabulary\vocabulary-image-manifest.tsv'
$documentationManifestPath = Join-Path $RepositoryRoot 'docs\vocabulary-image-manifest.tsv'
$reportPath = Join-Path $RepositoryRoot 'docs\vocabulary-deterministic-master-import.tsv'
$items = @(
    @{ StableKey = 'shapes_cylinder'; AssetKey = 'cylinder' },
    @{ StableKey = 'colors_dark_blue'; AssetKey = 'dark_blue' },
    @{ StableKey = 'colors_ivory'; AssetKey = 'ivory' },
    @{ StableKey = 'colors_khaki'; AssetKey = 'khaki' },
    @{ StableKey = 'colors_light_blue'; AssetKey = 'light_blue' },
    @{ StableKey = 'colors_light_green'; AssetKey = 'light_green' },
    @{ StableKey = 'shapes_parallelogram'; AssetKey = 'parallelogram' },
    @{ StableKey = 'shapes_pyramid'; AssetKey = 'pyramid' }
)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function New-ContentsJson([string]$AssetKey) {
    return @{
        images = @(
            @{ filename = "$AssetKey.png"; idiom = 'universal'; scale = '1x' },
            @{ idiom = 'universal'; scale = '2x' },
            @{ idiom = 'universal'; scale = '3x' }
        )
        info = @{ author = 'xcode'; version = 1 }
    } | ConvertTo-Json -Depth 5
}

$manifestText = [IO.File]::ReadAllText($runtimeManifestPath, [Text.Encoding]::UTF8)
$crlf = [string][char]13 + [char]10
$lf = [string][char]10
$newline = if ($manifestText.Contains($crlf)) { $crlf } else { $lf }
$lines = [System.Collections.Generic.List[string]]::new()
$manifestText.TrimEnd([char]13, [char]10).Split(@($crlf, $lf), [StringSplitOptions]::None) |
    ForEach-Object { $lines.Add($_) }
$header = $lines[0].Split([char]9)
$stableKeyIndex = [Array]::IndexOf($header, 'stableKey')
$iosStatusIndex = [Array]::IndexOf($header, 'iosAssetStatus')
$imageActionIndex = [Array]::IndexOf($header, 'imageAction')
if ($stableKeyIndex -lt 0 -or $iosStatusIndex -lt 0 -or $imageActionIndex -lt 0) {
    throw 'Vocabulary manifest lifecycle columns are missing.'
}

$reportRows = [System.Collections.Generic.List[string]]::new()
$reportRows.Add(@(
    'stableKey', 'assetKey', 'sourcePath', 'sourceBytes', 'sourceSHA256',
    'outputPath', 'outputBytes', 'outputSHA256', 'width', 'height', 'status'
) -join [char]9)

foreach ($item in $items) {
    $sourcePath = Join-Path $MasterRoot "$($item.AssetKey).png"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing deterministic master: $sourcePath"
    }

    $image = [Drawing.Image]::FromFile($sourcePath, $true)
    try {
        if ($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid) {
            throw "Master does not decode as PNG: $sourcePath"
        }
        if ($image.Width -ne 1024 -or $image.Height -ne 1024) {
            throw "Master must be 1024 by 1024: $sourcePath"
        }
        $width = $image.Width
        $height = $image.Height
    } finally {
        $image.Dispose()
    }

    $destinationDirectory = Join-Path $catalogRoot "$($item.AssetKey).imageset"
    $destinationPath = Join-Path $destinationDirectory "$($item.AssetKey).png"
    if (Test-Path -LiteralPath $destinationDirectory) {
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf) -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash -ne
            (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash) {
            throw "Existing imageset differs from the deterministic master: $($item.AssetKey)"
        }
    } else {
        [void](New-Item -ItemType Directory -Path $destinationDirectory)
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
        Write-Utf8NoBom (Join-Path $destinationDirectory 'Contents.json') ((New-ContentsJson $item.AssetKey) + $lf)
    }

    $matchingLine = -1
    for ($index = 1; $index -lt $lines.Count; $index += 1) {
        $fields = $lines[$index].Split([char]9)
        if ($fields[$stableKeyIndex] -eq $item.StableKey) {
            $matchingLine = $index
            if ($fields[$iosStatusIndex] -notin @('missing_ios', 'existing_ios') -or
                $fields[$imageActionIndex] -notin @('create_new', 'reuse_ios')) {
                throw "Unexpected manifest lifecycle for $($item.StableKey)."
            }
            $fields[$iosStatusIndex] = 'existing_ios'
            $fields[$imageActionIndex] = 'reuse_ios'
            $lines[$index] = $fields -join [char]9
            break
        }
    }
    if ($matchingLine -lt 0) {
        throw "Missing manifest row: $($item.StableKey)"
    }

    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
    $outputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash
    if ($sourceHash -ne $outputHash) {
        throw "Imported bytes differ from deterministic master: $($item.AssetKey)"
    }
    $reportRows.Add(@(
        $item.StableKey,
        $item.AssetKey,
        "artwork-staging\masters\$($item.AssetKey).png",
        (Get-Item -LiteralPath $sourcePath).Length,
        $sourceHash,
        "Resources\LanguageImages.xcassets\$($item.AssetKey).imageset\$($item.AssetKey).png",
        (Get-Item -LiteralPath $destinationPath).Length,
        $outputHash,
        $width,
        $height,
        'success'
    ) -join [char]9)
}

$updatedManifest = ($lines -join $newline) + $newline
Write-Utf8NoBom $runtimeManifestPath $updatedManifest
Write-Utf8NoBom $documentationManifestPath $updatedManifest
Write-Utf8NoBom $reportPath (($reportRows -join $lf) + $lf)

Write-Output "VOCABULARY_DETERMINISTIC_MASTERS_IMPORTED=$($items.Count)"

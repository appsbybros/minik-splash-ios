param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$FlagArchivePath,
    [string]$NaturalEarthPath,
    [string]$EdgePath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$flagCommit = 'fe15c16e7463d0c66d6c5730e9d0e832438d98e1'
$naturalEarthCommit = 'ca96624a56bd078437bca8184e78163e5039ad19'
$flagArchiveSHA256 = '3BBFF7E5361EADD7E88F226B70CB6BE90CAF81C655F95AA24A2B8E703D141598'
$naturalEarthSHA256 = '6866C877D39CBA9C357620878839B336D569F8C662D3CFAB4CB1DBE2D39C977F'
$retrievedDate = '2026-09-12'
$workspaceRoot = Split-Path -Parent $RepositoryRoot

if ([string]::IsNullOrWhiteSpace($FlagArchivePath)) {
    $FlagArchivePath = Join-Path $workspaceRoot "artwork-staging\trusted-sources\flag-icons-$flagCommit.zip"
}
if ([string]::IsNullOrWhiteSpace($NaturalEarthPath)) {
    $NaturalEarthPath = Join-Path $workspaceRoot "artwork-staging\trusted-sources\ne_110m_admin_0_countries-$naturalEarthCommit.geojson"
}
if ([string]::IsNullOrWhiteSpace($EdgePath)) {
    $EdgePath = @(
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

$catalogRoot = Join-Path $RepositoryRoot 'Resources\LanguageImages.xcassets'
$runtimeManifestPath = Join-Path $RepositoryRoot 'Resources\Vocabulary\vocabulary-image-manifest.tsv'
$documentationManifestPath = Join-Path $RepositoryRoot 'docs\vocabulary-image-manifest.tsv'
$reportPath = Join-Path $RepositoryRoot 'docs\vocabulary-trusted-asset-provenance.tsv'
$flags = @(
    @{ StableKey = 'countries_argentina'; AssetKey = 'argentina'; Code = 'ar' },
    @{ StableKey = 'countries_australia'; AssetKey = 'australia'; Code = 'au' },
    @{ StableKey = 'countries_belgium'; AssetKey = 'belgium'; Code = 'be' },
    @{ StableKey = 'countries_brazil'; AssetKey = 'brazil'; Code = 'br' },
    @{ StableKey = 'countries_bulgaria'; AssetKey = 'bulgaria'; Code = 'bg' },
    @{ StableKey = 'countries_chile'; AssetKey = 'chile'; Code = 'cl' },
    @{ StableKey = 'countries_cyprus'; AssetKey = 'cyprus'; Code = 'cy' },
    @{ StableKey = 'countries_czech_republic'; AssetKey = 'czech_republic'; Code = 'cz' },
    @{ StableKey = 'countries_denmark'; AssetKey = 'denmark'; Code = 'dk' },
    @{ StableKey = 'countries_egypt'; AssetKey = 'egypt'; Code = 'eg' },
    @{ StableKey = 'countries_finland'; AssetKey = 'finland'; Code = 'fi' },
    @{ StableKey = 'countries_germany'; AssetKey = 'germany'; Code = 'de' },
    @{ StableKey = 'countries_greece'; AssetKey = 'greece'; Code = 'gr' },
    @{ StableKey = 'countries_hungary'; AssetKey = 'hungary'; Code = 'hu' },
    @{ StableKey = 'countries_israel'; AssetKey = 'israel'; Code = 'il' },
    @{ StableKey = 'countries_italy'; AssetKey = 'italy'; Code = 'it' },
    @{ StableKey = 'countries_liechtenstein'; AssetKey = 'liechtenstein'; Code = 'li' },
    @{ StableKey = 'countries_luxembourg'; AssetKey = 'luxembourg'; Code = 'lu' },
    @{ StableKey = 'countries_monaco'; AssetKey = 'monaco'; Code = 'mc' },
    @{ StableKey = 'countries_netherlands'; AssetKey = 'netherlands'; Code = 'nl' },
    @{ StableKey = 'countries_norway'; AssetKey = 'norway'; Code = 'no' },
    @{ StableKey = 'countries_poland'; AssetKey = 'poland'; Code = 'pl' },
    @{ StableKey = 'countries_portugal'; AssetKey = 'portugal'; Code = 'pt' },
    @{ StableKey = 'countries_romania'; AssetKey = 'romania'; Code = 'ro' },
    @{ StableKey = 'countries_russia'; AssetKey = 'russia'; Code = 'ru' },
    @{ StableKey = 'countries_san_marino'; AssetKey = 'san_marino'; Code = 'sm' },
    @{ StableKey = 'countries_spain'; AssetKey = 'spain'; Code = 'es' },
    @{ StableKey = 'countries_sweden'; AssetKey = 'sweden'; Code = 'se' },
    @{ StableKey = 'countries_switzerland'; AssetKey = 'switzerland'; Code = 'ch' },
    @{ StableKey = 'countries_united_kingdom'; AssetKey = 'united_kingdom'; Code = 'gb' },
    @{ StableKey = 'countries_united_states'; AssetKey = 'united_states'; Code = 'us' },
    @{ StableKey = 'countries_uruguay'; AssetKey = 'uruguay'; Code = 'uy' }
)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Get-RelativeWorkspacePath([string]$Path) {
    $rootURI = [Uri](([IO.Path]::GetFullPath($workspaceRoot).TrimEnd('\') + '\'))
    $pathURI = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($rootURI.MakeRelativeUri($pathURI).ToString()).Replace('/', '\')
}

function Get-RelativeRepositoryPath([string]$Path) {
    $rootURI = [Uri](([IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\') + '\'))
    $pathURI = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($rootURI.MakeRelativeUri($pathURI).ToString()).Replace('/', '\')
}

function Get-FileSHA256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
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

function Assert-PNG([string]$Path) {
    $image = [Drawing.Image]::FromFile($Path, $true)
    try {
        if ($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
            $image.Width -ne 1024 -or $image.Height -ne 1024) {
            throw "Expected a decoded 1024 by 1024 PNG: $Path"
        }
    } finally {
        $image.Dispose()
    }
}

function Invoke-EdgeScreenshot([string]$HtmlPath, [string]$OutputPath, [int]$Width, [int]$Height, [string]$ProfilePath) {
    $arguments = @(
        '--headless=new',
        '--disable-gpu',
        '--no-first-run',
        '--disable-background-networking',
        '--disable-crash-reporter',
        '--hide-scrollbars',
        '--force-device-scale-factor=1',
        "--window-size=$Width,$Height",
        '--default-background-color=00000000',
        "--user-data-dir=$ProfilePath",
        "--screenshot=$OutputPath",
        "file:///$($HtmlPath.Replace('\', '/'))"
    )
    $process = Start-Process -FilePath $EdgePath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw "Microsoft Edge failed to render $HtmlPath (exit $($process.ExitCode))."
    }
}

function Save-Imageset([string]$AssetKey, [string]$RenderedPath) {
    Assert-PNG $RenderedPath
    $destinationDirectory = Join-Path $catalogRoot "$AssetKey.imageset"
    $destinationPath = Join-Path $destinationDirectory "$AssetKey.png"
    if (Test-Path -LiteralPath $destinationDirectory) {
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf) -or
            (Get-FileSHA256 $destinationPath) -ne (Get-FileSHA256 $RenderedPath)) {
            throw "Existing imageset differs from the trusted render: $AssetKey"
        }
    } else {
        [void](New-Item -ItemType Directory -Path $destinationDirectory)
        Copy-Item -LiteralPath $RenderedPath -Destination $destinationPath
        Write-Utf8NoBom (Join-Path $destinationDirectory 'Contents.json') ((New-ContentsJson $AssetKey) + "`n")
    }
    return $destinationPath
}

foreach ($requiredPath in @($FlagArchivePath, $NaturalEarthPath, $EdgePath)) {
    if ([string]::IsNullOrWhiteSpace($requiredPath) -or -not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required trusted-asset input is missing: $requiredPath"
    }
}
if ((Get-FileSHA256 $FlagArchivePath) -ne $flagArchiveSHA256) {
    throw 'The flag-icons archive does not match the pinned SHA-256.'
}
if ((Get-FileSHA256 $NaturalEarthPath) -ne $naturalEarthSHA256) {
    throw 'The Natural Earth GeoJSON does not match the pinned SHA-256.'
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "minik-trusted-assets-$([Guid]::NewGuid().ToString('N'))"
[void](New-Item -ItemType Directory -Path $temporaryRoot)
try {
    $extractedRoot = Join-Path $temporaryRoot 'flag-icons'
    [IO.Compression.ZipFile]::ExtractToDirectory($FlagArchivePath, $extractedRoot)
    $flagRoot = Get-ChildItem -LiteralPath $extractedRoot -Directory | Select-Object -First 1 -ExpandProperty FullName
    if ([string]::IsNullOrWhiteSpace($flagRoot)) {
        throw 'The flag-icons archive has no root directory.'
    }

    $reportRows = [System.Collections.Generic.List[string]]::new()
    $reportRows.Add(@(
        'stableKey', 'assetKey', 'provider', 'sourceVersion', 'sourceContainerPath',
        'sourceContainerBytes', 'sourceContainerSHA256', 'sourceEntry', 'sourceBytes',
        'sourceSHA256', 'sourceURL', 'license', 'licenseURL', 'retrievedDate',
        'outputPath', 'outputBytes', 'outputSHA256', 'width', 'height', 'renderMethod', 'status'
    ) -join [char]9)

    for ($batchStart = 0; $batchStart -lt $flags.Count; $batchStart += 16) {
        $batch = @($flags[$batchStart..([Math]::Min($batchStart + 15, $flags.Count - 1))])
        $cells = [System.Collections.Generic.List[string]]::new()
        foreach ($flag in $batch) {
            $sourcePath = Join-Path $flagRoot "flags\4x3\$($flag.Code).svg"
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                throw "Missing flag-icons source: $sourcePath"
            }
            $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
            $base64 = [Convert]::ToBase64String($sourceBytes)
            $cells.Add("<div class=`"cell`"><img alt=`"`" src=`"data:image/svg+xml;base64,$base64`"></div>")
        }
        while ($cells.Count -lt 16) {
            $cells.Add('<div class="cell"></div>')
        }
        $html = @"
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:4096px;height:4096px;background:transparent;overflow:hidden}
body{display:grid;grid-template-columns:repeat(4,1024px);grid-template-rows:repeat(4,1024px)}
.cell{width:1024px;height:1024px;display:flex;align-items:center;justify-content:center}
img{display:block;width:800px;height:600px;object-fit:contain}
</style></head><body>$($cells -join '')</body></html>
"@
        $htmlPath = Join-Path $temporaryRoot "flags-$batchStart.html"
        $sheetPath = Join-Path $temporaryRoot "flags-$batchStart.png"
        Write-Utf8NoBom $htmlPath $html
        Invoke-EdgeScreenshot $htmlPath $sheetPath 4096 4096 (Join-Path $temporaryRoot "edge-profile-$batchStart")

        $sheet = [Drawing.Bitmap]::FromFile($sheetPath, $true)
        try {
            if ($sheet.Width -ne 4096 -or $sheet.Height -ne 4096) {
                throw "Unexpected flag render sheet dimensions: $($sheet.Width)x$($sheet.Height)"
            }
            for ($index = 0; $index -lt $batch.Count; $index += 1) {
                $flag = $batch[$index]
                $rectangle = [Drawing.Rectangle]::new(($index % 4) * 1024, [Math]::Floor($index / 4) * 1024, 1024, 1024)
                $renderedPath = Join-Path $temporaryRoot "$($flag.AssetKey).png"
                $crop = $sheet.Clone($rectangle, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
                try {
                    $crop.Save($renderedPath, [Drawing.Imaging.ImageFormat]::Png)
                } finally {
                    $crop.Dispose()
                }
                $destinationPath = Save-Imageset $flag.AssetKey $renderedPath
                $sourcePath = Join-Path $flagRoot "flags\4x3\$($flag.Code).svg"
                $reportRows.Add(@(
                    $flag.StableKey,
                    $flag.AssetKey,
                    'flag-icons',
                    $flagCommit,
                    (Get-RelativeWorkspacePath $FlagArchivePath),
                    (Get-Item -LiteralPath $FlagArchivePath).Length,
                    $flagArchiveSHA256,
                    "flags/4x3/$($flag.Code).svg",
                    (Get-Item -LiteralPath $sourcePath).Length,
                    (Get-FileSHA256 $sourcePath),
                    "https://raw.githubusercontent.com/lipis/flag-icons/$flagCommit/flags/4x3/$($flag.Code).svg",
                    'MIT',
                    "https://raw.githubusercontent.com/lipis/flag-icons/$flagCommit/LICENSE",
                    $retrievedDate,
                    (Get-RelativeRepositoryPath $destinationPath),
                    (Get-Item -LiteralPath $destinationPath).Length,
                    (Get-FileSHA256 $destinationPath),
                    1024,
                    1024,
                    'pinned SVG rendered by Microsoft Edge into a centered 800x600 transparent canvas',
                    'success'
                ) -join [char]9)
            }
        } finally {
            $sheet.Dispose()
        }
    }

    $geoJSON = Get-Content -LiteralPath $NaturalEarthPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $rings = [System.Collections.Generic.List[object]]::new()
    foreach ($feature in @($geoJSON.features | Where-Object { $_.properties.CONTINENT -eq 'Africa' })) {
        if ($feature.geometry.type -eq 'Polygon') {
            foreach ($ring in $feature.geometry.coordinates) {
                $rings.Add([object]$ring)
            }
        } elseif ($feature.geometry.type -eq 'MultiPolygon') {
            foreach ($polygon in $feature.geometry.coordinates) {
                foreach ($ring in $polygon) {
                    $rings.Add([object]$ring)
                }
            }
        } else {
            throw "Unsupported Natural Earth geometry type: $($feature.geometry.type)"
        }
    }
    if ($rings.Count -eq 0) {
        throw 'Natural Earth contains no African geometry.'
    }

    $minimumX = [double]::PositiveInfinity
    $maximumX = [double]::NegativeInfinity
    $minimumY = [double]::PositiveInfinity
    $maximumY = [double]::NegativeInfinity
    foreach ($ring in $rings) {
        foreach ($point in $ring) {
            $minimumX = [Math]::Min($minimumX, [double]$point[0])
            $maximumX = [Math]::Max($maximumX, [double]$point[0])
            $minimumY = [Math]::Min($minimumY, [double]$point[1])
            $maximumY = [Math]::Max($maximumY, [double]$point[1])
        }
    }
    $scale = [Math]::Min(800.0 / ($maximumX - $minimumX), 800.0 / ($maximumY - $minimumY))
    $left = (1024.0 - (($maximumX - $minimumX) * $scale)) / 2.0
    $top = (1024.0 - (($maximumY - $minimumY) * $scale)) / 2.0
    $pathData = [Text.StringBuilder]::new()
    foreach ($ring in $rings) {
        for ($pointIndex = 0; $pointIndex -lt $ring.Count; $pointIndex += 1) {
            $x = $left + (([double]$ring[$pointIndex][0] - $minimumX) * $scale)
            $y = $top + (($maximumY - [double]$ring[$pointIndex][1]) * $scale)
            $command = if ($pointIndex -eq 0) { 'M' } else { 'L' }
            [void]$pathData.AppendFormat([Globalization.CultureInfo]::InvariantCulture, '{0}{1:F2},{2:F2}', $command, $x, $y)
        }
        [void]$pathData.Append('Z')
    }
    $africaSVG = "<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 1024 1024`"><path d=`"$pathData`" fill=`"#15A89B`" fill-rule=`"evenodd`"/></svg>"
    $africaBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($africaSVG))
    $africaHTML = @"
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:1024px;height:1024px;background:transparent;overflow:hidden}
body{display:flex;align-items:center;justify-content:center}img{display:block;width:1024px;height:1024px}
</style></head><body><img alt="" src="data:image/svg+xml;base64,$africaBase64"></body></html>
"@
    $africaHTMLPath = Join-Path $temporaryRoot 'africa.html'
    $africaRenderedPath = Join-Path $temporaryRoot 'africa.png'
    Write-Utf8NoBom $africaHTMLPath $africaHTML
    Invoke-EdgeScreenshot $africaHTMLPath $africaRenderedPath 1024 1024 (Join-Path $temporaryRoot 'edge-profile-africa')
    $africaDestinationPath = Save-Imageset 'africa' $africaRenderedPath
    $reportRows.Add(@(
        'geography_africa',
        'africa',
        'Natural Earth',
        $naturalEarthCommit,
        (Get-RelativeWorkspacePath $NaturalEarthPath),
        (Get-Item -LiteralPath $NaturalEarthPath).Length,
        $naturalEarthSHA256,
        'features where CONTINENT=AFRICA',
        (Get-Item -LiteralPath $NaturalEarthPath).Length,
        $naturalEarthSHA256,
        "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/$naturalEarthCommit/geojson/ne_110m_admin_0_countries.geojson",
        'Public Domain',
        'https://www.naturalearthdata.com/about/terms-of-use/',
        $retrievedDate,
        (Get-RelativeRepositoryPath $africaDestinationPath),
        (Get-Item -LiteralPath $africaDestinationPath).Length,
        (Get-FileSHA256 $africaDestinationPath),
        1024,
        1024,
        'African Natural Earth polygons merged into a centered teal silhouette and rendered by Microsoft Edge',
        'success'
    ) -join [char]9)

    $manifestText = [IO.File]::ReadAllText($runtimeManifestPath, [Text.Encoding]::UTF8)
    $newline = if ($manifestText.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [System.Collections.Generic.List[string]]::new()
    $manifestText.TrimEnd([char]13, [char]10).Split(@("`r`n", "`n"), [StringSplitOptions]::None) |
        ForEach-Object { $lines.Add($_) }
    $header = $lines[0].Split([char]9)
    $stableKeyIndex = [Array]::IndexOf($header, 'stableKey')
    $iosStatusIndex = [Array]::IndexOf($header, 'iosAssetStatus')
    $imageActionIndex = [Array]::IndexOf($header, 'imageAction')
    $trustedKeys = @($flags | ForEach-Object StableKey) + @('geography_africa')
    foreach ($stableKey in $trustedKeys) {
        $found = $false
        for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex += 1) {
            $fields = $lines[$lineIndex].Split([char]9)
            if ($fields[$stableKeyIndex] -ne $stableKey) {
                continue
            }
            if ($fields[$iosStatusIndex] -notin @('missing_ios', 'existing_ios') -or
                $fields[$imageActionIndex] -notin @('trusted_acquire', 'reuse_ios')) {
                throw "Unexpected trusted manifest lifecycle for $stableKey."
            }
            $fields[$iosStatusIndex] = 'existing_ios'
            $fields[$imageActionIndex] = 'reuse_ios'
            $lines[$lineIndex] = $fields -join [char]9
            $found = $true
            break
        }
        if (-not $found) {
            throw "Missing trusted manifest row: $stableKey"
        }
    }

    $updatedManifest = ($lines -join $newline) + $newline
    Write-Utf8NoBom $runtimeManifestPath $updatedManifest
    Write-Utf8NoBom $documentationManifestPath $updatedManifest
    Write-Utf8NoBom $reportPath (($reportRows -join "`n") + "`n")
    Write-Output "VOCABULARY_TRUSTED_ASSETS_IMPORTED=$($reportRows.Count - 1)"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
        $temporaryPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\minik-trusted-assets-'
        if (-not $resolvedTemporaryRoot.StartsWith($temporaryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove unexpected temporary path: $resolvedTemporaryRoot"
        }
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}

[CmdletBinding()]
param(
    [string]$MagickPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Resolve-MagickExecutable {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        Assert-Condition (Test-Path -LiteralPath $RequestedPath -PathType Leaf) (
            "ImageMagick executable does not exist: {0}" -f $RequestedPath
        )
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    $command = Get-Command magick.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $candidates.Add($command.Source)
    }

    $whereResults = @(& where.exe magick 2>$null)
    foreach ($whereResult in $whereResults) {
        if (-not [string]::IsNullOrWhiteSpace($whereResult)) {
            $candidates.Add($whereResult)
        }
    }

    $installationRoots = [System.Collections.Generic.List[string]]::new()
    foreach ($basePath in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not [string]::IsNullOrWhiteSpace($basePath) -and (Test-Path -LiteralPath $basePath)) {
            foreach ($directory in @(Get-ChildItem -LiteralPath $basePath -Directory -Filter "ImageMagick*" -ErrorAction SilentlyContinue)) {
                $installationRoots.Add($directory.FullName)
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        foreach ($basePath in @($env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA "Programs"))) {
            if (Test-Path -LiteralPath $basePath) {
                foreach ($directory in @(Get-ChildItem -LiteralPath $basePath -Directory -Filter "ImageMagick*" -ErrorAction SilentlyContinue)) {
                    $installationRoots.Add($directory.FullName)
                }
            }
        }
    }

    foreach ($root in @($installationRoots | Sort-Object -Unique)) {
        foreach ($candidate in @(Get-ChildItem -LiteralPath $root -File -Filter "magick.exe" -Recurse -ErrorAction SilentlyContinue)) {
            $candidates.Add($candidate.FullName)
        }
    }

    $resolvedCandidates = @(
        $candidates |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
            ForEach-Object { (Resolve-Path -LiteralPath $_).Path } |
            Sort-Object -Unique
    )
    Assert-Condition ($resolvedCandidates.Count -gt 0) (
        "ImageMagick magick.exe was not found in PATH or targeted installation directories. Pass -MagickPath explicitly."
    )
    return $resolvedCandidates[0]
}

function Test-HasAlphaChannel {
    param([string]$Channels)

    return $Channels -match "(?i)alpha|rgba|cmyka|graya|\bya\b"
}

function Get-ImageInfo {
    param(
        [string]$Executable,
        [string]$Path
    )

    $output = @(
        & $Executable identify -quiet -format "%m`t%w`t%h`t%[channels]`t%[opaque]" $Path 2>&1
    )
    Assert-Condition ($LASTEXITCODE -eq 0) (
        "ImageMagick could not decode {0}: {1}" -f $Path, ($output -join " ")
    )

    $value = ($output -join "").Trim()
    $parts = $value.Split([char]"`t")
    Assert-Condition ($parts.Count -eq 5) ("Unexpected ImageMagick metadata for {0}: {1}" -f $Path, $value)

    $width = 0
    $height = 0
    Assert-Condition ([int]::TryParse($parts[1], [ref]$width)) ("Invalid image width for {0}" -f $Path)
    Assert-Condition ([int]::TryParse($parts[2], [ref]$height)) ("Invalid image height for {0}" -f $Path)
    Assert-Condition ($width -gt 0 -and $height -gt 0) ("Non-positive image dimensions for {0}" -f $Path)

    $opaque = $false
    Assert-Condition ([bool]::TryParse($parts[4], [ref]$opaque)) ("Invalid opacity metadata for {0}" -f $Path)

    return [pscustomobject]@{
        Format = $parts[0].ToUpperInvariant()
        Width = $width
        Height = $height
        Channels = $parts[3]
        HasAlpha = Test-HasAlphaChannel $parts[3]
        HasTransparency = -not $opaque
    }
}

function Convert-ToPng {
    param(
        [string]$Executable,
        [string]$SourcePath,
        [string]$DestinationPath
    )

    $output = @(
        & $Executable $SourcePath -define png:exclude-chunks=date,time $DestinationPath 2>&1
    )
    Assert-Condition ($LASTEXITCODE -eq 0) (
        "ImageMagick conversion failed for {0}: {1}" -f $SourcePath, ($output -join " ")
    )
}

function New-ContentsJson {
    param([string]$AssetKey)

    return (@(
        "{",
        "  `"images`" : [",
        "    {",
        "      `"filename`" : `"$AssetKey.png`",",
        "      `"idiom`" : `"universal`",",
        "      `"scale`" : `"1x`"",
        "    },",
        "    {",
        "      `"idiom`" : `"universal`",",
        "      `"scale`" : `"2x`"",
        "    },",
        "    {",
        "      `"idiom`" : `"universal`",",
        "      `"scale`" : `"3x`"",
        "    }",
        "  ],",
        "  `"info`" : {",
        "    `"author`" : `"xcode`",",
        "    `"version`" : 1",
        "  }",
        "}"
    ) -join "`n") + "`n"
}

function Assert-ContentsJson {
    param(
        [string]$Path,
        [string]$AssetKey
    )

    $json = Get-Content -Raw -Encoding utf8 -LiteralPath $Path | ConvertFrom-Json
    $images = @($json.images)
    Assert-Condition ($images.Count -eq 3) ("Contents.json must contain exactly three image slots: {0}" -f $Path)
    Assert-Condition ($images[0].filename -eq ("{0}.png" -f $AssetKey)) ("Incorrect 1x filename in {0}" -f $Path)
    Assert-Condition ($images[0].idiom -eq "universal" -and $images[0].scale -eq "1x") ("Incorrect 1x slot in {0}" -f $Path)
    Assert-Condition ($images[1].idiom -eq "universal" -and $images[1].scale -eq "2x") ("Incorrect 2x slot in {0}" -f $Path)
    Assert-Condition ($images[2].idiom -eq "universal" -and $images[2].scale -eq "3x") ("Incorrect 3x slot in {0}" -f $Path)
    $secondFilename = $images[1].PSObject.Properties["filename"]
    $thirdFilename = $images[2].PSObject.Properties["filename"]
    Assert-Condition ($null -eq $secondFilename -and $null -eq $thirdFilename) ("2x and 3x slots must be empty in {0}" -f $Path)
    Assert-Condition ($json.info.author -eq "xcode" -and $json.info.version -eq 1) ("Incorrect Contents.json metadata in {0}" -f $Path)
}

function Get-ActionCount {
    param(
        [object[]]$Rows,
        [string]$Action
    )

    return @($Rows | Where-Object { $_.imageAction -eq $Action }).Count
}

function Assert-LifecycleCounts {
    param(
        [object[]]$Rows,
        [int]$ReuseIOS,
        [int]$MigrateAndroid,
        [int]$TrustedAcquire,
        [int]$CreateNew
    )

    Assert-Condition ($Rows.Count -eq 543) ("Expected 543 manifest rows, found {0}." -f $Rows.Count)
    Assert-Condition ((Get-ActionCount $Rows "reuse_ios") -eq $ReuseIOS) "Unexpected reuse_ios count."
    Assert-Condition ((Get-ActionCount $Rows "migrate_android") -eq $MigrateAndroid) "Unexpected migrate_android count."
    Assert-Condition ((Get-ActionCount $Rows "trusted_acquire") -eq $TrustedAcquire) "Unexpected trusted_acquire count."
    Assert-Condition ((Get-ActionCount $Rows "create_new") -eq $CreateNew) "Unexpected create_new count."
}

function Convert-ToReportField {
    param([object]$Value)

    $text = [string]$Value
    Assert-Condition (-not ($text.Contains("`t") -or $text.Contains("`r") -or $text.Contains("`n"))) "TSV report field contains a tab or newline."
    return $text
}

function New-ReportText {
    param([object[]]$Rows)

    $columns = @(
        "stableKey",
        "assetKey",
        "androidSourcePath",
        "sourceFormat",
        "sourceWidth",
        "sourceHeight",
        "sourceHasAlpha",
        "sourceHasTransparency",
        "outputPath",
        "outputWidth",
        "outputHeight",
        "outputHasAlpha",
        "outputHasTransparency",
        "sourceBytes",
        "outputBytes",
        "status"
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($columns -join "`t")

    foreach ($row in $Rows) {
        $values = foreach ($column in $columns) {
            Convert-ToReportField $row.$column
        }
        $lines.Add($values -join "`t")
    }

    return ($lines -join "`r`n") + "`r`n"
}

function New-TransitionedManifestText {
    param(
        [string]$OriginalText,
        [System.Collections.Generic.HashSet[string]]$MigratedStableKeys
    )

    $newline = if ($OriginalText.Contains("`r`n")) { "`r`n" } else { "`n" }
    $hasTerminalNewline = $OriginalText.EndsWith("`n")
    $lines = @($OriginalText -split "`r?`n")
    if ($hasTerminalNewline -and $lines.Count -gt 0 -and $lines[-1] -eq "") {
        $lines = @($lines[0..($lines.Count - 2)])
    }

    Assert-Condition ($lines.Count -eq 544) ("Expected manifest header plus 543 rows, found {0} lines." -f $lines.Count)
    $header = $lines[0].Split([char[]]@("`t"), [System.StringSplitOptions]::None)
    $stableKeyIndex = [Array]::IndexOf($header, "stableKey")
    $iosStatusIndex = [Array]::IndexOf($header, "iosAssetStatus")
    $imageActionIndex = [Array]::IndexOf($header, "imageAction")
    Assert-Condition ($stableKeyIndex -ge 0 -and $iosStatusIndex -ge 0 -and $imageActionIndex -ge 0) "Manifest transition columns are missing."

    $changed = 0
    $outputLines = [System.Collections.Generic.List[string]]::new()
    $outputLines.Add($lines[0])
    foreach ($line in $lines[1..($lines.Count - 1)]) {
        $fields = $line.Split([char[]]@("`t"), [System.StringSplitOptions]::None)
        Assert-Condition ($fields.Count -gt $imageActionIndex -and $fields.Count -le $header.Count) ("Manifest field count mismatch for line: {0}" -f $line)
        if ($MigratedStableKeys.Contains($fields[$stableKeyIndex])) {
            Assert-Condition ($fields[$iosStatusIndex] -eq "missing_ios") ("Unexpected pre-transition iOS status for {0}." -f $fields[$stableKeyIndex])
            Assert-Condition ($fields[$imageActionIndex] -eq "migrate_android") ("Unexpected pre-transition action for {0}." -f $fields[$stableKeyIndex])
            $fields[$iosStatusIndex] = "existing_ios"
            $fields[$imageActionIndex] = "reuse_ios"
            $changed += 1
        }
        $outputLines.Add($fields -join "`t")
    }

    Assert-Condition ($changed -eq 397) ("Expected to transition 397 rows, changed {0}." -f $changed)
    $result = $outputLines -join $newline
    if ($hasTerminalNewline) {
        $result += $newline
    }
    return $result
}

function Assert-CompletedMigration {
    param(
        [string]$Executable,
        [object[]]$ManifestRows,
        [string]$ReportPath,
        [string]$AssetCatalogPath
    )

    Assert-LifecycleCounts $ManifestRows 409 0 33 101
    Assert-Condition (Test-Path -LiteralPath $ReportPath -PathType Leaf) "Completed lifecycle has no migration report."
    $reportRows = @(Import-Csv -Delimiter "`t" -LiteralPath $ReportPath)
    Assert-Condition ($reportRows.Count -eq 397) ("Expected 397 report rows, found {0}." -f $reportRows.Count)

    $reportAssetKeys = @($reportRows | ForEach-Object { $_.assetKey.ToLowerInvariant() })
    Assert-Condition (($reportAssetKeys | Sort-Object -Unique).Count -eq 397) "Migration report contains duplicate asset keys."
    $manifestByStableKey = @{}
    foreach ($row in $ManifestRows) {
        $manifestByStableKey[$row.stableKey] = $row
    }

    foreach ($row in $reportRows) {
        Assert-Condition ($manifestByStableKey.ContainsKey($row.stableKey)) ("Report stableKey is absent from manifest: {0}" -f $row.stableKey)
        $manifestRow = $manifestByStableKey[$row.stableKey]
        Assert-Condition ($manifestRow.assetKey -eq $row.assetKey) ("Report assetKey mismatch for {0}." -f $row.stableKey)
        Assert-Condition ($manifestRow.iosAssetStatus -eq "existing_ios" -and $manifestRow.imageAction -eq "reuse_ios") ("Report row is not ready in the manifest: {0}" -f $row.stableKey)

        $destinationDirectory = Join-Path $AssetCatalogPath ("{0}.imageset" -f $row.assetKey)
        $pngPath = Join-Path $destinationDirectory ("{0}.png" -f $row.assetKey)
        $contentsPath = Join-Path $destinationDirectory "Contents.json"
        Assert-Condition (Test-Path -LiteralPath $pngPath -PathType Leaf) ("Missing migrated PNG: {0}" -f $pngPath)
        Assert-Condition (Test-Path -LiteralPath $contentsPath -PathType Leaf) ("Missing Contents.json: {0}" -f $contentsPath)
        Assert-ContentsJson $contentsPath $row.assetKey

        $info = Get-ImageInfo $Executable $pngPath
        Assert-Condition ($info.Format -eq "PNG") ("Migrated result is not PNG: {0}" -f $pngPath)
        Assert-Condition ($info.Width -eq [int]$row.outputWidth -and $info.Height -eq [int]$row.outputHeight) ("Migrated dimensions differ from report: {0}" -f $row.assetKey)
        Assert-Condition ($info.HasAlpha -eq [bool]::Parse($row.outputHasAlpha)) ("Migrated alpha state differs from report: {0}" -f $row.assetKey)
        Assert-Condition ($info.HasTransparency -eq [bool]::Parse($row.outputHasTransparency)) ("Migrated transparency differs from report: {0}" -f $row.assetKey)
    }

    $sourceBytes = [int64]0
    $outputBytes = [int64]0
    foreach ($row in $reportRows) {
        $sourceBytes += [int64]$row.sourceBytes
        $outputBytes += [int64]$row.outputBytes
    }
    $ratio = [double]$outputBytes / [double]$sourceBytes
    Write-Output ("No migrate_android rows remain. Validated completed 397-row migration; no files were written.")
    Write-Output ("Aggregate source bytes: {0}" -f $sourceBytes)
    Write-Output ("Aggregate output bytes: {0}" -f $outputBytes)
    Write-Output ("Output/source ratio: {0:N6}" -f $ratio)
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$iosRoot = Split-Path -Parent $scriptDirectory
$workspaceRoot = Split-Path -Parent $iosRoot
$docsManifestPath = Join-Path $iosRoot "docs\vocabulary-image-manifest.tsv"
$runtimeManifestPath = Join-Path $iosRoot "Resources\Vocabulary\vocabulary-image-manifest.tsv"
$reportPath = Join-Path $iosRoot "docs\vocabulary-android-asset-migration.tsv"
$assetCatalogPath = Join-Path $iosRoot "Resources\LanguageImages.xcassets"
$androidDrawablePath = Join-Path $workspaceRoot "android\app\src\main\res\drawable"
$resolvedMagickPath = Resolve-MagickExecutable $MagickPath

$versionOutput = @(& $resolvedMagickPath -version 2>&1)
Assert-Condition ($LASTEXITCODE -eq 0) ("ImageMagick version check failed: {0}" -f ($versionOutput -join " "))
Write-Output ("ImageMagick: {0}" -f $resolvedMagickPath)
Write-Output $versionOutput[0]

Assert-Condition (Test-Path -LiteralPath $docsManifestPath -PathType Leaf) "Documentation manifest is missing."
Assert-Condition (Test-Path -LiteralPath $runtimeManifestPath -PathType Leaf) "Runtime manifest is missing."
Assert-Condition (Test-Path -LiteralPath $androidDrawablePath -PathType Container) "Android drawable directory is missing."
Assert-Condition (Test-Path -LiteralPath $assetCatalogPath -PathType Container) "iOS asset catalog is missing."

$docsManifestBytes = [System.IO.File]::ReadAllBytes($docsManifestPath)
$runtimeManifestBytes = [System.IO.File]::ReadAllBytes($runtimeManifestPath)
Assert-Condition ([System.Linq.Enumerable]::SequenceEqual($docsManifestBytes, $runtimeManifestBytes)) "Documentation and runtime manifests are not byte-identical."
$manifestText = [System.Text.Encoding]::UTF8.GetString($docsManifestBytes)
$manifestRows = @(Import-Csv -Delimiter "`t" -LiteralPath $docsManifestPath)
Assert-Condition ($manifestRows.Count -eq 543) ("Expected 543 manifest rows, found {0}." -f $manifestRows.Count)

$migrationRows = @($manifestRows | Where-Object { $_.imageAction -eq "migrate_android" })
if ($migrationRows.Count -eq 0) {
    Assert-CompletedMigration $resolvedMagickPath $manifestRows $reportPath $assetCatalogPath
    return
}

Assert-LifecycleCounts $manifestRows 12 397 33 101
Assert-Condition ($migrationRows.Count -eq 397) ("Expected 397 migration rows, found {0}." -f $migrationRows.Count)
Assert-Condition (@($migrationRows | Where-Object { $_.iosAssetStatus -ne "missing_ios" -or $_.androidAssetStatus -ne "existing_android" }).Count -eq 0) "Migration rows have invalid pre-transition statuses."

$duplicateManifestKeys = @(
    $manifestRows |
        Group-Object { $_.assetKey.ToLowerInvariant() } |
        Where-Object { $_.Count -gt 1 }
)
Assert-Condition ($duplicateManifestKeys.Count -eq 0) "Manifest contains case-insensitive duplicate asset keys."

$drawableLookup = @{}
foreach ($file in @(Get-ChildItem -LiteralPath $androidDrawablePath -File)) {
    $key = $file.BaseName.ToLowerInvariant()
    if (-not $drawableLookup.ContainsKey($key)) {
        $drawableLookup[$key] = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    }
    $drawableLookup[$key].Add($file)
}

$preflightRows = [System.Collections.Generic.List[object]]::new()
$existingImageSetNames = @(
    Get-ChildItem -LiteralPath $assetCatalogPath -Directory -Filter "*.imageset" |
        ForEach-Object { $_.BaseName.ToLowerInvariant() }
)
$existingImageSetLookup = @{}
foreach ($name in $existingImageSetNames) {
    $existingImageSetLookup[$name] = $true
}

foreach ($row in $migrationRows) {
    Assert-Condition ($row.assetKey -match "^[a-z0-9_]+$") ("Unsafe manifest assetKey: {0}" -f $row.assetKey)
    $lookupKey = $row.assetKey.ToLowerInvariant()
    Assert-Condition ($drawableLookup.ContainsKey($lookupKey)) ("Missing Android drawable for assetKey: {0}" -f $row.assetKey)
    $matches = @($drawableLookup[$lookupKey])
    Assert-Condition ($matches.Count -eq 1) ("Ambiguous Android drawable for assetKey {0}: {1}" -f $row.assetKey, (($matches.Name) -join ", "))
    $sourceFile = $matches[0]
    $extension = $sourceFile.Extension.ToLowerInvariant()
    Assert-Condition ($extension -eq ".webp" -or $extension -eq ".png") ("Unsupported Android asset for {0}: {1}" -f $row.assetKey, $sourceFile.Name)
    Assert-Condition (-not $existingImageSetLookup.ContainsKey($lookupKey)) ("Destination imageset already exists before migration: {0}.imageset" -f $row.assetKey)

    $sourceInfo = Get-ImageInfo $resolvedMagickPath $sourceFile.FullName
    Assert-Condition ($sourceInfo.Format -eq "WEBP" -or $sourceInfo.Format -eq "PNG") ("Unsupported decoded source format for {0}: {1}" -f $row.assetKey, $sourceInfo.Format)
    $preflightRows.Add([pscustomobject]@{
        ManifestRow = $row
        SourceFile = $sourceFile
        SourceInfo = $sourceInfo
    })
}

Assert-Condition ($preflightRows.Count -eq 397) ("Preflight resolved {0} assets instead of 397." -f $preflightRows.Count)
$sourceFormatGroups = @($preflightRows | Group-Object { $_.SourceInfo.Format } | Sort-Object Name)
Write-Output "Preflight: 397 resolved, 0 missing, 0 ambiguous, 0 case collisions, 0 unsupported."
foreach ($group in $sourceFormatGroups) {
    Write-Output ("Source format {0}: {1}" -f $group.Name, $group.Count)
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$stagingRoot = Join-Path $tempBase ("minik-vocabulary-migration-{0}" -f [Guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $stagingRoot
$createdDestinations = [System.Collections.Generic.List[string]]::new()
$migrationSucceeded = $false
$reportExisted = Test-Path -LiteralPath $reportPath -PathType Leaf
$originalReportBytes = if ($reportExisted) { [System.IO.File]::ReadAllBytes($reportPath) } else { $null }

try {
    $reportRows = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($preflight in $preflightRows) {
        $index += 1
        $row = $preflight.ManifestRow
        $assetKey = $row.assetKey
        $stageDirectory = Join-Path $stagingRoot ("{0}.imageset" -f $assetKey)
        $null = New-Item -ItemType Directory -Path $stageDirectory
        $stagePngPath = Join-Path $stageDirectory ("{0}.png" -f $assetKey)
        $stageContentsPath = Join-Path $stageDirectory "Contents.json"

        Convert-ToPng $resolvedMagickPath $preflight.SourceFile.FullName $stagePngPath
        Write-Utf8NoBom $stageContentsPath (New-ContentsJson $assetKey)

        $outputInfo = Get-ImageInfo $resolvedMagickPath $stagePngPath
        Assert-Condition ($outputInfo.Format -eq "PNG") ("Output is not PNG for {0}." -f $assetKey)
        Assert-Condition ($outputInfo.Width -eq $preflight.SourceInfo.Width -and $outputInfo.Height -eq $preflight.SourceInfo.Height) ("Dimensions changed for {0}." -f $assetKey)
        Assert-Condition ($outputInfo.HasAlpha -eq $preflight.SourceInfo.HasAlpha) ("Alpha-channel semantics changed for {0}." -f $assetKey)
        Assert-Condition ($outputInfo.HasTransparency -eq $preflight.SourceInfo.HasTransparency) ("Transparency semantics changed for {0}." -f $assetKey)
        Assert-ContentsJson $stageContentsPath $assetKey

        $sourceRelativePath = $preflight.SourceFile.FullName.Substring($workspaceRoot.Length + 1)
        $outputRelativePath = (Join-Path "Resources\LanguageImages.xcassets" ("{0}.imageset\{0}.png" -f $assetKey))
        $reportRows.Add([pscustomobject]@{
            stableKey = $row.stableKey
            assetKey = $assetKey
            androidSourcePath = $sourceRelativePath
            sourceFormat = $preflight.SourceInfo.Format
            sourceWidth = $preflight.SourceInfo.Width
            sourceHeight = $preflight.SourceInfo.Height
            sourceHasAlpha = $preflight.SourceInfo.HasAlpha
            sourceHasTransparency = $preflight.SourceInfo.HasTransparency
            outputPath = $outputRelativePath
            outputWidth = $outputInfo.Width
            outputHeight = $outputInfo.Height
            outputHasAlpha = $outputInfo.HasAlpha
            outputHasTransparency = $outputInfo.HasTransparency
            sourceBytes = $preflight.SourceFile.Length
            outputBytes = (Get-Item -LiteralPath $stagePngPath).Length
            status = "success"
        })

        if ($index % 25 -eq 0 -or $index -eq 397) {
            Write-Output ("Converted and staged {0}/397." -f $index)
        }
    }

    Assert-Condition ($reportRows.Count -eq 397) ("Expected 397 staged report rows, found {0}." -f $reportRows.Count)
    $stagedImageSets = @(Get-ChildItem -LiteralPath $stagingRoot -Directory -Filter "*.imageset")
    Assert-Condition ($stagedImageSets.Count -eq 397) ("Expected 397 staged imagesets, found {0}." -f $stagedImageSets.Count)

    foreach ($preflight in $preflightRows) {
        $assetKey = $preflight.ManifestRow.assetKey
        $stageDirectory = Join-Path $stagingRoot ("{0}.imageset" -f $assetKey)
        $destinationDirectory = Join-Path $assetCatalogPath ("{0}.imageset" -f $assetKey)
        Assert-Condition (-not (Test-Path -LiteralPath $destinationDirectory)) ("Destination appeared after preflight: {0}" -f $destinationDirectory)
        $null = New-Item -ItemType Directory -Path $destinationDirectory
        $createdDestinations.Add($destinationDirectory)
        Copy-Item -LiteralPath (Join-Path $stageDirectory ("{0}.png" -f $assetKey)) -Destination $destinationDirectory
        Copy-Item -LiteralPath (Join-Path $stageDirectory "Contents.json") -Destination $destinationDirectory
    }

    Assert-Condition ($createdDestinations.Count -eq 397) ("Expected 397 created imagesets, created {0}." -f $createdDestinations.Count)
    $createdNames = @($createdDestinations | ForEach-Object { (Split-Path -Leaf $_).ToLowerInvariant() })
    Assert-Condition (($createdNames | Sort-Object -Unique).Count -eq 397) "Duplicate migrated destination directories were created."

    foreach ($preflight in $preflightRows) {
        $assetKey = $preflight.ManifestRow.assetKey
        $destinationDirectory = Join-Path $assetCatalogPath ("{0}.imageset" -f $assetKey)
        Assert-Condition ((Split-Path -Leaf $destinationDirectory) -eq ("{0}.imageset" -f $assetKey)) ("Destination directory does not match assetKey: {0}" -f $assetKey)
        $pngPath = Join-Path $destinationDirectory ("{0}.png" -f $assetKey)
        $contentsPath = Join-Path $destinationDirectory "Contents.json"
        Assert-Condition (Test-Path -LiteralPath $pngPath -PathType Leaf) ("Missing project PNG for {0}." -f $assetKey)
        Assert-Condition (Test-Path -LiteralPath $contentsPath -PathType Leaf) ("Missing project Contents.json for {0}." -f $assetKey)
        Assert-ContentsJson $contentsPath $assetKey
        $projectInfo = Get-ImageInfo $resolvedMagickPath $pngPath
        Assert-Condition ($projectInfo.Format -eq "PNG") ("Project output is not PNG for {0}." -f $assetKey)
        Assert-Condition ($projectInfo.Width -eq $preflight.SourceInfo.Width -and $projectInfo.Height -eq $preflight.SourceInfo.Height) ("Project dimensions changed for {0}." -f $assetKey)
        Assert-Condition ($projectInfo.HasAlpha -eq $preflight.SourceInfo.HasAlpha) ("Project alpha-channel semantics changed for {0}." -f $assetKey)
        Assert-Condition ($projectInfo.HasTransparency -eq $preflight.SourceInfo.HasTransparency) ("Project transparency semantics changed for {0}." -f $assetKey)
    }
    Write-Output "Project validation: 397/397 passed."

    Write-Utf8NoBom $reportPath (New-ReportText $reportRows)
    $writtenReportRows = @(Import-Csv -Delimiter "`t" -LiteralPath $reportPath)
    Assert-Condition ($writtenReportRows.Count -eq 397) ("Written migration report has {0} rows instead of 397." -f $writtenReportRows.Count)
    Assert-Condition (@($writtenReportRows | Where-Object { $_.status -ne "success" }).Count -eq 0) "Migration report contains a non-success row."

    $migratedStableKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($row in $migrationRows) {
        Assert-Condition ($migratedStableKeys.Add($row.stableKey)) ("Duplicate migrated stableKey: {0}" -f $row.stableKey)
    }
    $transitionedManifestText = New-TransitionedManifestText $manifestText $migratedStableKeys
    try {
        Write-Utf8NoBom $docsManifestPath $transitionedManifestText
        Write-Utf8NoBom $runtimeManifestPath $transitionedManifestText
    } catch {
        [System.IO.File]::WriteAllBytes($docsManifestPath, $docsManifestBytes)
        [System.IO.File]::WriteAllBytes($runtimeManifestPath, $runtimeManifestBytes)
        throw
    }

    $finalDocsBytes = [System.IO.File]::ReadAllBytes($docsManifestPath)
    $finalRuntimeBytes = [System.IO.File]::ReadAllBytes($runtimeManifestPath)
    Assert-Condition ([System.Linq.Enumerable]::SequenceEqual($finalDocsBytes, $finalRuntimeBytes)) "Final documentation and runtime manifests are not byte-identical."
    $finalRows = @(Import-Csv -Delimiter "`t" -LiteralPath $docsManifestPath)
    Assert-LifecycleCounts $finalRows 409 0 33 101

    $sourceBytes = [int64]0
    $outputBytes = [int64]0
    foreach ($row in $reportRows) {
        $sourceBytes += [int64]$row.sourceBytes
        $outputBytes += [int64]$row.outputBytes
    }
    $difference = $outputBytes - $sourceBytes
    $ratio = [double]$outputBytes / [double]$sourceBytes
    Write-Output "Manifest transition: reuse_ios=409, migrate_android=0, trusted_acquire=33, create_new=101."
    Write-Output ("Aggregate source bytes: {0}" -f $sourceBytes)
    Write-Output ("Aggregate output bytes: {0}" -f $outputBytes)
    Write-Output ("Byte difference: {0}" -f $difference)
    Write-Output ("Output/source ratio: {0:N6}" -f $ratio)
    $migrationSucceeded = $true
} catch {
    $originalFailure = $_
    if (-not $migrationSucceeded) {
        try {
            $currentDocsBytes = [System.IO.File]::ReadAllBytes($docsManifestPath)
            if (-not [System.Linq.Enumerable]::SequenceEqual($currentDocsBytes, $docsManifestBytes)) {
                [System.IO.File]::WriteAllBytes($docsManifestPath, $docsManifestBytes)
            }
            $currentRuntimeBytes = [System.IO.File]::ReadAllBytes($runtimeManifestPath)
            if (-not [System.Linq.Enumerable]::SequenceEqual($currentRuntimeBytes, $runtimeManifestBytes)) {
                [System.IO.File]::WriteAllBytes($runtimeManifestPath, $runtimeManifestBytes)
            }
            if ($reportExisted) {
                $currentReportBytes = if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
                    [System.IO.File]::ReadAllBytes($reportPath)
                } else {
                    [byte[]]@()
                }
                if (-not [System.Linq.Enumerable]::SequenceEqual($currentReportBytes, $originalReportBytes)) {
                    [System.IO.File]::WriteAllBytes($reportPath, $originalReportBytes)
                }
            } elseif (Test-Path -LiteralPath $reportPath -PathType Leaf) {
                Remove-Item -LiteralPath $reportPath -Force
            }
        } catch {
            Write-Warning ("Rollback could not restore a documentation file: {0}" -f $_.Exception.Message)
        }

        $assetCatalogRoot = [System.IO.Path]::GetFullPath($assetCatalogPath).TrimEnd("\") + "\"
        foreach ($destination in $createdDestinations) {
            $resolvedDestination = [System.IO.Path]::GetFullPath($destination)
            Assert-Condition ($resolvedDestination.StartsWith($assetCatalogRoot, [System.StringComparison]::OrdinalIgnoreCase)) ("Refusing rollback outside asset catalog: {0}" -f $resolvedDestination)
            if (Test-Path -LiteralPath $resolvedDestination -PathType Container) {
                [System.IO.Directory]::Delete($resolvedDestination, $true)
            }
        }
    }
    throw $originalFailure
} finally {
    $resolvedStagingRoot = [System.IO.Path]::GetFullPath($stagingRoot)
    Assert-Condition ($resolvedStagingRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) ("Refusing to remove staging directory outside system temp: {0}" -f $resolvedStagingRoot)
    if (Test-Path -LiteralPath $resolvedStagingRoot -PathType Container) {
        [System.IO.Directory]::Delete($resolvedStagingRoot, $true)
    }
}

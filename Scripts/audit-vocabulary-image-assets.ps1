$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $repoRoot
$runtimeManifestPath = Join-Path $repoRoot 'Resources\Vocabulary\vocabulary-image-manifest.tsv'
$documentationManifestPath = Join-Path $repoRoot 'docs\vocabulary-image-manifest.tsv'
$migrationReportPath = Join-Path $repoRoot 'docs\vocabulary-android-asset-migration.tsv'
$deterministicReportPath = Join-Path $repoRoot 'docs\vocabulary-deterministic-master-import.tsv'
$trustedReportPath = Join-Path $repoRoot 'docs\vocabulary-trusted-asset-provenance.tsv'
$knownFixReportPath = Join-Path $repoRoot 'docs\vocabulary-known-fix-provenance.tsv'
$generatedReportPath = Join-Path $repoRoot 'docs\vocabulary-generated-asset-provenance.tsv'
$trustedNoticePath = Join-Path $repoRoot 'Resources\ThirdPartyNotices\VocabularyAssetNotices.txt'
$catalogPath = Join-Path $repoRoot 'Resources\LanguageImages.xcassets'
$errors = [System.Collections.Generic.List[string]]::new()

function Add-AuditError {
    param([string]$Message)

    $errors.Add($Message)
}

function Resolve-ContainedPath {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Description
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description escapes its allowed root: $RelativePath"
    }
    return $resolvedPath
}

function Get-WebPDimensions {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if (
        $bytes.Length -lt 30 -or
        [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne 'RIFF' -or
        [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4) -ne 'WEBP'
    ) {
        throw "Invalid WebP header: $Path"
    }

    $chunk = [System.Text.Encoding]::ASCII.GetString($bytes, 12, 4)
    switch ($chunk) {
        'VP8X' {
            $width = 1 + [int]$bytes[24] + ([int]$bytes[25] * 256) + ([int]$bytes[26] * 65536)
            $height = 1 + [int]$bytes[27] + ([int]$bytes[28] * 256) + ([int]$bytes[29] * 65536)
        }
        'VP8L' {
            if ($bytes[20] -ne 0x2f) {
                throw "Invalid VP8L signature: $Path"
            }
            $width = 1 + [int]$bytes[21] + (([int]$bytes[22] -band 0x3f) * 256)
            $height = 1 + ([int]$bytes[22] -shr 6) + ([int]$bytes[23] * 4) + (([int]$bytes[24] -band 0x0f) * 1024)
        }
        'VP8 ' {
            if ($bytes[23] -ne 0x9d -or $bytes[24] -ne 0x01 -or $bytes[25] -ne 0x2a) {
                throw "Invalid VP8 signature: $Path"
            }
            $width = ([int]$bytes[26] + ([int]$bytes[27] * 256)) -band 0x3fff
            $height = ([int]$bytes[28] + ([int]$bytes[29] * 256)) -band 0x3fff
        }
        default {
            throw "Unsupported WebP chunk '$chunk': $Path"
        }
    }

    if ($width -le 0 -or $height -le 0) {
        throw "Non-positive WebP dimensions: $Path"
    }
    return [pscustomobject]@{ Width = $width; Height = $height }
}

function Get-DecodedDimensions {
    param([string]$Path)

    $image = [System.Drawing.Image]::FromFile($Path, $true)
    try {
        return [pscustomobject]@{
            Width = $image.Width
            Height = $image.Height
            Format = $image.RawFormat.Guid
            HasAlpha = (($image.Flags -band [System.Drawing.Imaging.ImageFlags]::HasAlpha) -ne 0)
        }
    } finally {
        $image.Dispose()
    }
}

function Get-PngAlphaRange {
    param([string]$Path)

    return [VocabularyAuditPngInspector]::Inspect($Path)
}

foreach ($requiredPath in @(
    $runtimeManifestPath,
    $documentationManifestPath,
    $migrationReportPath,
    $deterministicReportPath,
    $trustedReportPath,
    $knownFixReportPath,
    $generatedReportPath,
    $trustedNoticePath,
    $catalogPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        Add-AuditError "Missing required vocabulary artifact: $requiredPath"
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class VocabularyAuditPngInspector
{
    public static int[] Inspect(string path)
    {
        using (var source = new Bitmap(path))
        using (var bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb))
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.DrawImageUnscaled(source, 0, 0);
            var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            var data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try
            {
                int byteCount = Math.Abs(data.Stride) * bitmap.Height;
                var pixels = new byte[byteCount];
                Marshal.Copy(data.Scan0, pixels, 0, byteCount);
                int minimum = 255;
                int maximum = 0;
                for (int y = 0; y < bitmap.Height; y++)
                {
                    int row = y * Math.Abs(data.Stride);
                    for (int x = 0; x < bitmap.Width; x++)
                    {
                        int alpha = pixels[row + x * 4 + 3];
                        if (alpha < minimum) minimum = alpha;
                        if (alpha > maximum) maximum = alpha;
                    }
                }
                return new[] { bitmap.Width, bitmap.Height, minimum, maximum };
            }
            finally
            {
                bitmap.UnlockBits(data);
            }
        }
    }
}
"@

$runtimeManifestBytes = [System.IO.File]::ReadAllBytes($runtimeManifestPath)
$documentationManifestBytes = [System.IO.File]::ReadAllBytes($documentationManifestPath)
if (-not [System.Linq.Enumerable]::SequenceEqual($runtimeManifestBytes, $documentationManifestBytes)) {
    Add-AuditError 'Runtime and documentation vocabulary manifests are not byte-identical.'
}

$manifestRows = @(Import-Csv -Delimiter "`t" -LiteralPath $runtimeManifestPath)
$reportRows = @(Import-Csv -Delimiter "`t" -LiteralPath $migrationReportPath)
$deterministicRows = @(Import-Csv -Delimiter "`t" -LiteralPath $deterministicReportPath)
$trustedRows = @(Import-Csv -Delimiter "`t" -LiteralPath $trustedReportPath)
$knownFixRows = @(Import-Csv -Delimiter "`t" -LiteralPath $knownFixReportPath)
$generatedRows = @(Import-Csv -Delimiter "`t" -LiteralPath $generatedReportPath)

if ($manifestRows.Count -ne 543) {
    Add-AuditError "Expected 543 manifest rows; found $($manifestRows.Count)."
}
if ($reportRows.Count -ne 397) {
    Add-AuditError "Expected 397 Android migration report rows; found $($reportRows.Count)."
}

$actionCounts = @{}
foreach ($action in @('reuse_ios', 'migrate_android', 'trusted_acquire', 'create_new')) {
    $actionCounts[$action] = @($manifestRows | Where-Object imageAction -eq $action).Count
}
if ($actionCounts['reuse_ios'] -ne 543) {
    Add-AuditError "Expected 543 reuse_ios rows; found $($actionCounts['reuse_ios'])."
}
if ($actionCounts['migrate_android'] -ne 0) {
    Add-AuditError "Expected zero migrate_android rows; found $($actionCounts['migrate_android'])."
}
if ($actionCounts['trusted_acquire'] -ne 0) {
    Add-AuditError "Expected zero trusted_acquire rows; found $($actionCounts['trusted_acquire'])."
}
if ($actionCounts['create_new'] -ne 0) {
    Add-AuditError "Expected zero create_new rows; found $($actionCounts['create_new'])."
}
if ($deterministicRows.Count -ne 8) {
    Add-AuditError "Expected 8 deterministic master rows; found $($deterministicRows.Count)."
}
if ($trustedRows.Count -ne 33) {
    Add-AuditError "Expected 33 trusted asset rows; found $($trustedRows.Count)."
}
if ($knownFixRows.Count -ne 2) {
    Add-AuditError "Expected 2 known artwork correction rows; found $($knownFixRows.Count)."
}
if ($generatedRows.Count -ne 93) {
    Add-AuditError "Expected 93 generated artwork rows; found $($generatedRows.Count)."
}
if (@($generatedRows | Group-Object stableKey | Where-Object Count -gt 1).Count -gt 0) {
    Add-AuditError 'Generated asset report contains duplicate stable keys.'
}
if (@($generatedRows | Group-Object generationOutputID | Where-Object Count -gt 1).Count -gt 0) {
    Add-AuditError 'Generated asset report contains duplicate generation output IDs.'
}
if (@($generatedRows | Group-Object outputSHA256 | Where-Object Count -gt 1).Count -gt 0) {
    Add-AuditError 'Generated asset report contains duplicate output hashes.'
}
if (@($trustedRows | Group-Object stableKey | Where-Object Count -gt 1).Count -gt 0) {
    Add-AuditError 'Trusted asset report contains duplicate stable keys.'
}
$trustedNotice = Get-Content -LiteralPath $trustedNoticePath -Raw -Encoding UTF8
if ($trustedNotice -notmatch 'Copyright \(c\) 2013 Panayiotis Lipiridis' -or
    $trustedNotice -notmatch 'Natural Earth' -or
    $trustedNotice -notmatch 'public domain') {
    Add-AuditError 'Vocabulary asset notices do not preserve the required source/license statements.'
}

foreach ($duplicate in @($manifestRows | Group-Object stableKey | Where-Object Count -gt 1)) {
    Add-AuditError "Duplicate manifest stableKey: $($duplicate.Name)"
}
foreach ($duplicate in @($manifestRows | Group-Object { $_.assetKey.ToLowerInvariant() } | Where-Object Count -gt 1)) {
    Add-AuditError "Case-insensitive duplicate manifest assetKey: $($duplicate.Name)"
}
foreach ($row in $manifestRows) {
    if ([string]::IsNullOrWhiteSpace($row.english)) {
        Add-AuditError "Blank English vocabulary text: $($row.stableKey)"
    }
    if ([string]::IsNullOrWhiteSpace($row.hebrew)) {
        Add-AuditError "Blank Hebrew vocabulary text: $($row.stableKey)"
    }
    if ($row.assetKey -notmatch '^[a-z0-9_]+$') {
        Add-AuditError "Unsafe vocabulary assetKey: $($row.assetKey)"
    }

    $imageSetPath = Join-Path $catalogPath "$($row.assetKey).imageset"
    if ($row.iosAssetStatus -eq 'existing_ios' -and $row.imageAction -eq 'reuse_ios') {
        if (-not (Test-Path -LiteralPath $imageSetPath -PathType Container)) {
            Add-AuditError "Ready manifest row has no imageset: $($row.assetKey)"
        } else {
            $contentsPath = Join-Path $imageSetPath 'Contents.json'
            if (-not (Test-Path -LiteralPath $contentsPath -PathType Leaf)) {
                Add-AuditError "Ready imageset has no Contents.json: $($row.assetKey)"
            } else {
                try {
                    $contents = Get-Content -Raw -Encoding utf8 -LiteralPath $contentsPath | ConvertFrom-Json
                    $referencedFiles = @($contents.images | Where-Object { -not [string]::IsNullOrWhiteSpace($_.filename) })
                    if ($referencedFiles.Count -ne 1) {
                        Add-AuditError "Ready imageset must reference exactly one file: $($row.assetKey)"
                    } elseif (-not (Test-Path -LiteralPath (Join-Path $imageSetPath $referencedFiles[0].filename) -PathType Leaf)) {
                        Add-AuditError "Ready imageset references a missing file: $($row.assetKey)"
                    }
                } catch {
                    Add-AuditError "Invalid Contents.json for $($row.assetKey): $($_.Exception.Message)"
                }
            }
        }
    } elseif (Test-Path -LiteralPath $imageSetPath) {
        Add-AuditError "Unresolved manifest row unexpectedly has an imageset: $($row.assetKey)"
    }
}

$manifestByStableKey = @{}
foreach ($row in $manifestRows) {
    $manifestByStableKey[$row.stableKey] = $row
}
$knownFixAssetKeys = @($knownFixRows | ForEach-Object assetKey)

$outputHashes = [System.Collections.Generic.List[object]]::new()
$sourceHashesByAsset = @{}
$decodedPNGCount = 0
$webPSourceCount = 0
$pngSourceCount = 0

foreach ($row in $reportRows) {
    try {
        $isKnownFix = $knownFixAssetKeys -contains $row.assetKey
        if ($row.status -ne 'success') {
            throw 'migration status is not success'
        }
        if (-not $manifestByStableKey.ContainsKey($row.stableKey)) {
            throw 'stableKey is absent from the manifest'
        }
        $manifestRow = $manifestByStableKey[$row.stableKey]
        if (
            $manifestRow.assetKey -ne $row.assetKey -or
            $manifestRow.iosAssetStatus -ne 'existing_ios' -or
            $manifestRow.imageAction -ne 'reuse_ios'
        ) {
            throw 'manifest lifecycle or asset mapping differs from the migration report'
        }

        $sourcePath = Resolve-ContainedPath $workspaceRoot $row.androidSourcePath 'Android provenance path'
        $outputPath = Resolve-ContainedPath $repoRoot $row.outputPath 'iOS output path'
        $expectedOutputPath = Join-Path $catalogPath "$($row.assetKey).imageset\$($row.assetKey).png"
        if ($outputPath -ne [System.IO.Path]::GetFullPath($expectedOutputPath)) {
            throw 'reported output path does not match the asset key'
        }
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw 'Android provenance source is missing'
        }
        if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw 'migrated PNG is missing'
        }
        if ((Get-Item -LiteralPath $sourcePath).Length -ne [int64]$row.sourceBytes) {
            throw 'Android source byte count differs from the migration report'
        }
        if (-not $isKnownFix -and (Get-Item -LiteralPath $outputPath).Length -ne [int64]$row.outputBytes) {
            throw 'migrated PNG byte count differs from the migration report'
        }

        if ($row.sourceFormat -eq 'WEBP') {
            $sourceDimensions = Get-WebPDimensions $sourcePath
            $webPSourceCount += 1
        } elseif ($row.sourceFormat -eq 'PNG') {
            $sourceDimensions = Get-DecodedDimensions $sourcePath
            $pngSourceCount += 1
        } else {
            throw "unsupported reported source format: $($row.sourceFormat)"
        }
        if (
            $sourceDimensions.Width -ne [int]$row.sourceWidth -or
            $sourceDimensions.Height -ne [int]$row.sourceHeight
        ) {
            throw 'Android source dimensions differ from the migration report'
        }

        $outputDimensions = Get-DecodedDimensions $outputPath
        if ($outputDimensions.Format -ne [System.Drawing.Imaging.ImageFormat]::Png.Guid) {
            throw 'migrated output does not decode as PNG'
        }
        if (-not $isKnownFix -and (
            $outputDimensions.Width -ne [int]$row.outputWidth -or
            $outputDimensions.Height -ne [int]$row.outputHeight -or
            $outputDimensions.Width -ne $sourceDimensions.Width -or
            $outputDimensions.Height -ne $sourceDimensions.Height
        )) {
            throw 'migrated PNG dimensions differ from source/report dimensions'
        }
        $decodedPNGCount += 1

        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
        $outputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash
        $sourceHashesByAsset[$row.assetKey] = $sourceHash
        $outputHashes.Add([pscustomobject]@{ AssetKey = $row.assetKey; Hash = $outputHash })
    } catch {
        Add-AuditError "$($row.assetKey): $($_.Exception.Message)"
    }
}

$decodedDeterministicPNGCount = 0
foreach ($row in $deterministicRows) {
    try {
        if ($row.status -ne 'success') {
            throw 'import status is not success'
        }
        if (-not $manifestByStableKey.ContainsKey($row.stableKey)) {
            throw 'stableKey is absent from the manifest'
        }
        $manifestRow = $manifestByStableKey[$row.stableKey]
        if ($manifestRow.assetKey -ne $row.assetKey -or
            $manifestRow.iosAssetStatus -ne 'existing_ios' -or
            $manifestRow.imageAction -ne 'reuse_ios') {
            throw 'manifest lifecycle or asset mapping differs from the deterministic report'
        }
        $sourcePath = Resolve-ContainedPath $workspaceRoot $row.sourcePath 'Deterministic master path'
        $outputPath = Resolve-ContainedPath $repoRoot $row.outputPath 'Deterministic iOS output path'
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw 'source or output is missing'
        }
        if ((Get-Item -LiteralPath $sourcePath).Length -ne [int64]$row.sourceBytes -or
            (Get-Item -LiteralPath $outputPath).Length -ne [int64]$row.outputBytes) {
            throw 'source or output byte count differs from the report'
        }
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
        $outputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash
        if ($sourceHash -ne $row.sourceSHA256 -or $outputHash -ne $row.outputSHA256 -or
            $sourceHash -ne $outputHash) {
            throw 'source/output SHA-256 does not match the report'
        }
        $outputInfo = Get-DecodedDimensions $outputPath
        if ($outputInfo.Format -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
            $outputInfo.Width -ne [int]$row.width -or
            $outputInfo.Height -ne [int]$row.height) {
            throw 'output PNG decode or dimensions differ from the report'
        }
        $decodedDeterministicPNGCount += 1
    } catch {
        Add-AuditError "$($row.assetKey): $($_.Exception.Message)"
    }
}

$decodedTrustedPNGCount = 0
foreach ($row in $trustedRows) {
    try {
        if ($row.status -ne 'success') {
            throw 'trusted acquisition status is not success'
        }
        if (-not $manifestByStableKey.ContainsKey($row.stableKey)) {
            throw 'stableKey is absent from the manifest'
        }
        $manifestRow = $manifestByStableKey[$row.stableKey]
        if ($manifestRow.assetKey -ne $row.assetKey -or
            $manifestRow.iosAssetStatus -ne 'existing_ios' -or
            $manifestRow.imageAction -ne 'reuse_ios' -or
            $manifestRow.androidAssetStatus -ne 'trusted_external') {
            throw 'manifest lifecycle or asset mapping differs from the trusted report'
        }
        if ($row.provider -notin @('flag-icons', 'Natural Earth') -or
            $row.license -notin @('MIT', 'Public Domain') -or
            $row.sourceURL -notmatch '^https://' -or $row.licenseURL -notmatch '^https://') {
            throw 'trusted provider, license, or provenance URL is invalid'
        }

        $sourceContainerPath = Resolve-ContainedPath $workspaceRoot $row.sourceContainerPath 'Trusted source container path'
        $outputPath = Resolve-ContainedPath $repoRoot $row.outputPath 'Trusted iOS output path'
        $expectedOutputPath = [IO.Path]::GetFullPath((Join-Path $catalogPath "$($row.assetKey).imageset\$($row.assetKey).png"))
        if ($outputPath -ne $expectedOutputPath) {
            throw 'reported output path does not match the asset key'
        }
        if (-not (Test-Path -LiteralPath $sourceContainerPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw 'trusted source container or output is missing'
        }
        if ((Get-Item -LiteralPath $sourceContainerPath).Length -ne [int64]$row.sourceContainerBytes -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceContainerPath).Hash -ne $row.sourceContainerSHA256) {
            throw 'trusted source container size or SHA-256 differs from the report'
        }

        if ([IO.Path]::GetExtension($sourceContainerPath) -eq '.zip') {
            $archive = [IO.Compression.ZipFile]::OpenRead($sourceContainerPath)
            try {
                $suffix = '/' + $row.sourceEntry.Replace('\', '/')
                $entries = @($archive.Entries | Where-Object { $_.FullName.Replace('\', '/').EndsWith($suffix, [StringComparison]::Ordinal) })
                if ($entries.Count -ne 1) {
                    throw "expected exactly one archive entry ending in $suffix"
                }
                if ($entries[0].Length -ne [int64]$row.sourceBytes) {
                    throw 'trusted archive entry byte count differs from the report'
                }
                $stream = $entries[0].Open()
                try {
                    $hasher = [Security.Cryptography.SHA256]::Create()
                    try {
                        $entryHash = ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '')
                    } finally {
                        $hasher.Dispose()
                    }
                } finally {
                    $stream.Dispose()
                }
                if ($entryHash -ne $row.sourceSHA256) {
                    throw 'trusted archive entry SHA-256 differs from the report'
                }
            } finally {
                $archive.Dispose()
            }
        } elseif ((Get-Item -LiteralPath $sourceContainerPath).Length -ne [int64]$row.sourceBytes -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceContainerPath).Hash -ne $row.sourceSHA256) {
            throw 'trusted direct source size or SHA-256 differs from the report'
        }

        if ((Get-Item -LiteralPath $outputPath).Length -ne [int64]$row.outputBytes -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash -ne $row.outputSHA256) {
            throw 'trusted output size or SHA-256 differs from the report'
        }
        $outputInfo = Get-DecodedDimensions $outputPath
        if ($outputInfo.Format -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
            $outputInfo.Width -ne [int]$row.width -or $outputInfo.Height -ne [int]$row.height -or
            $outputInfo.Width -ne 1024 -or $outputInfo.Height -ne 1024) {
            throw 'trusted output must decode as a 1024 by 1024 PNG'
        }
        $decodedTrustedPNGCount += 1
    } catch {
        Add-AuditError "$($row.assetKey): $($_.Exception.Message)"
    }
}

$decodedKnownFixPNGCount = 0
foreach ($row in $knownFixRows) {
    try {
        if ($row.status -ne 'success' -or $row.generationTool -ne 'OpenAI built-in image_gen') {
            throw 'known-fix status or generation tool is invalid'
        }
        if (-not $manifestByStableKey.ContainsKey($row.stableKey)) {
            throw 'stableKey is absent from the manifest'
        }
        $manifestRow = $manifestByStableKey[$row.stableKey]
        if ($manifestRow.assetKey -ne $row.assetKey -or
            $manifestRow.iosAssetStatus -ne 'existing_ios' -or
            $manifestRow.imageAction -ne 'reuse_ios') {
            throw 'manifest lifecycle or asset mapping differs from the known-fix report'
        }
        if ($row.assetKey -notin @('dehumidifier', 'helix') -or
            $row.promptSource -ne 'artwork-staging\known-fix-generation-prompts.md' -or
            [string]::IsNullOrWhiteSpace($row.generationOutputID)) {
            throw 'known-fix identity or prompt provenance is invalid'
        }

        $sourcePath = Resolve-ContainedPath $workspaceRoot $row.sourcePath 'Known-fix master path'
        $outputPath = Resolve-ContainedPath $repoRoot $row.outputPath 'Known-fix iOS output path'
        $expectedOutputPath = [IO.Path]::GetFullPath((Join-Path $catalogPath "$($row.assetKey).imageset\$($row.assetKey).png"))
        if ($outputPath -ne $expectedOutputPath -or
            -not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw 'known-fix source/output path is missing or inconsistent'
        }
        if ((Get-Item -LiteralPath $sourcePath).Length -ne [int64]$row.sourceBytes -or
            (Get-Item -LiteralPath $outputPath).Length -ne [int64]$row.outputBytes) {
            throw 'known-fix source/output byte count differs from the report'
        }
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
        $outputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash
        if ($sourceHash -ne $row.sourceSHA256 -or $outputHash -ne $row.outputSHA256 -or
            $sourceHash -ne $outputHash) {
            throw 'known-fix source/output SHA-256 differs from the report'
        }
        $outputInfo = Get-DecodedDimensions $outputPath
        if ($outputInfo.Format -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
            $outputInfo.Width -ne [int]$row.width -or $outputInfo.Height -ne [int]$row.height -or
            $outputInfo.Width -lt 1024 -or $outputInfo.Height -lt 1024 -or
            -not $outputInfo.HasAlpha -or $row.hasAlpha -ne 'True') {
            throw 'known-fix output PNG dimensions or alpha declaration is invalid'
        }
        $decodedKnownFixPNGCount += 1
    } catch {
        Add-AuditError "$($row.assetKey): $($_.Exception.Message)"
    }
}

$decodedGeneratedPNGCount = 0
foreach ($row in $generatedRows) {
    try {
        if ($row.status -ne 'success' -or
            $row.generationTool -ne 'OpenAI built-in image_gen' -or
            $row.reviewStatus -ne 'visually_reviewed') {
            throw 'generated status, tool, or visual-review state is invalid'
        }
        if ($row.generationOutputID -notmatch '^exec-[0-9a-f-]+$' -or
            $row.promptSource -notmatch '^artwork-staging\\generation-sheets\\generation_[0-9]{3}-prompt\.md$' -or
            $row.promptSection -notmatch '^Cell [0-9]+$' -or
            $row.generatedDate -notmatch '^2026-09-(12|13)$') {
            throw 'generated prompt or output provenance is invalid'
        }
        if (-not $manifestByStableKey.ContainsKey($row.stableKey)) {
            throw 'stableKey is absent from the manifest'
        }
        $manifestRow = $manifestByStableKey[$row.stableKey]
        if ($manifestRow.assetKey -ne $row.assetKey -or
            $manifestRow.english -ne $row.english -or
            $manifestRow.iosAssetStatus -ne 'existing_ios' -or
            $manifestRow.imageAction -ne 'reuse_ios') {
            throw 'manifest lifecycle or identity differs from the generated report'
        }

        $sourcePath = Resolve-ContainedPath $workspaceRoot $row.sourcePath 'Generated master path'
        $outputPath = Resolve-ContainedPath $repoRoot $row.outputPath 'Generated iOS output path'
        $expectedOutputPath = [IO.Path]::GetFullPath((Join-Path $catalogPath "$($row.assetKey).imageset\$($row.assetKey).png"))
        if ($outputPath -ne $expectedOutputPath -or
            -not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw 'generated source/output path is missing or inconsistent'
        }
        if ((Get-Item -LiteralPath $sourcePath).Length -ne [int64]$row.sourceBytes -or
            (Get-Item -LiteralPath $outputPath).Length -ne [int64]$row.outputBytes) {
            throw 'generated source/output byte count differs from the report'
        }

        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
        $outputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash
        if ($sourceHash -ne $row.sourceSHA256 -or
            $outputHash -ne $row.outputSHA256 -or
            $sourceHash -ne $outputHash) {
            throw 'generated source/output SHA-256 differs from the report'
        }

        $outputInfo = Get-DecodedDimensions $outputPath
        $alpha = Get-PngAlphaRange $outputPath
        if ($outputInfo.Format -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
            $outputInfo.Width -ne [int]$row.width -or
            $outputInfo.Height -ne [int]$row.height -or
            $outputInfo.Width -lt 1024 -or $outputInfo.Height -lt 1024 -or
            $alpha[0] -ne [int]$row.width -or $alpha[1] -ne [int]$row.height -or
            $alpha[2] -ne 0 -or $alpha[3] -ne 255 -or
            [int]$row.alphaMinimum -ne 0 -or [int]$row.alphaMaximum -ne 255) {
            throw 'generated PNG decode, dimensions, or actual alpha range is invalid'
        }
        $decodedGeneratedPNGCount += 1
    } catch {
        Add-AuditError "$($row.assetKey): $($_.Exception.Message)"
    }
}

$duplicateOutputGroups = @($outputHashes | Group-Object Hash | Where-Object Count -gt 1)
foreach ($group in $duplicateOutputGroups) {
    $sourceHashes = @($group.Group | ForEach-Object { $sourceHashesByAsset[$_.AssetKey] } | Sort-Object -Unique)
    if ($sourceHashes.Count -ne 1) {
        Add-AuditError "Migrated outputs share bytes without sharing Android-source provenance: $($group.Group.AssetKey -join ', ')"
    }
}

Write-Output "VOCABULARY_MANIFEST_ROWS=$($manifestRows.Count)"
Write-Output "VOCABULARY_READY_IOS_ASSETS=$($actionCounts['reuse_ios'])"
Write-Output "VOCABULARY_ANDROID_MIGRATION_ROWS=$($reportRows.Count)"
Write-Output "VOCABULARY_ANDROID_WEBP_SOURCES=$webPSourceCount"
Write-Output "VOCABULARY_ANDROID_PNG_SOURCES=$pngSourceCount"
Write-Output "VOCABULARY_MIGRATED_PNGS_DECODED=$decodedPNGCount"
Write-Output "VOCABULARY_DETERMINISTIC_PNGS_DECODED=$decodedDeterministicPNGCount"
Write-Output "VOCABULARY_TRUSTED_PNGS_DECODED=$decodedTrustedPNGCount"
Write-Output "VOCABULARY_KNOWN_FIX_PNGS_DECODED=$decodedKnownFixPNGCount"
Write-Output "VOCABULARY_GENERATED_PNGS_DECODED=$decodedGeneratedPNGCount"
Write-Output "VOCABULARY_PROVENANCE_DUPLICATE_OUTPUT_GROUPS=$($duplicateOutputGroups.Count)"
Write-Output "VOCABULARY_TRUSTED_ACQUIRE_REMAINING=$($actionCounts['trusted_acquire'])"
Write-Output "VOCABULARY_CREATE_NEW_REMAINING=$($actionCounts['create_new'])"
Write-Output "VOCABULARY_IMAGE_ASSET_ERRORS=$($errors.Count)"

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'VOCABULARY_IMAGE_ASSET_AUDIT_OK'

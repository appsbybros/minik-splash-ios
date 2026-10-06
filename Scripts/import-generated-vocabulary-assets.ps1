param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ArtworkStagingRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'artwork-staging')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class GeneratedVocabularyPngInspector
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

$catalogRoot = Join-Path $RepositoryRoot 'Resources\LanguageImages.xcassets'
$runtimeManifestPath = Join-Path $RepositoryRoot 'Resources\Vocabulary\vocabulary-image-manifest.tsv'
$documentationManifestPath = Join-Path $RepositoryRoot 'docs\vocabulary-image-manifest.tsv'
$provenancePath = Join-Path $ArtworkStagingRoot 'generated-master-provenance.tsv'
$masterRoot = Join-Path $ArtworkStagingRoot 'masters'
$reportPath = Join-Path $RepositoryRoot 'docs\vocabulary-generated-asset-provenance.tsv'
$workspaceRoot = Split-Path -Parent $RepositoryRoot

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Get-RelativePath([string]$Root, [string]$Path) {
    $rootURI = [Uri](([IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'))
    $pathURI = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($rootURI.MakeRelativeUri($pathURI).ToString()).Replace('/', '\')
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

foreach ($requiredPath in @($runtimeManifestPath, $documentationManifestPath, $provenancePath, $masterRoot)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required generated-asset input is missing: $requiredPath"
    }
}

$provenanceRows = @(Import-Csv -LiteralPath $provenancePath -Delimiter "`t" |
    Where-Object { $_.promptSource -match '^generation-sheets/generation_[0-9]{3}-prompt\.md$' })
if ($provenanceRows.Count -ne 93) {
    throw "Expected exactly 93 reviewed generated-asset provenance rows; found $($provenanceRows.Count)."
}
if (@($provenanceRows | Group-Object stableKey | Where-Object Count -gt 1).Count -gt 0) {
    throw 'Generated provenance contains duplicate stable keys.'
}
if (@($provenanceRows | Group-Object generationOutputID | Where-Object Count -gt 1).Count -gt 0) {
    throw 'Generated provenance contains duplicate generation output IDs.'
}

$runtimeManifestRows = @(Import-Csv -LiteralPath $runtimeManifestPath -Delimiter "`t")
$documentationManifestRows = @(Import-Csv -LiteralPath $documentationManifestPath -Delimiter "`t")
if ($runtimeManifestRows.Count -ne 543 -or $documentationManifestRows.Count -ne 543) {
    throw 'Both vocabulary manifests must contain exactly 543 rows.'
}

$runtimeManifestText = [IO.File]::ReadAllText($runtimeManifestPath, [Text.Encoding]::UTF8)
$crlf = [string][char]13 + [char]10
$lf = [string][char]10
$newline = if ($runtimeManifestText.Contains($crlf)) { $crlf } else { $lf }
$manifestLines = [System.Collections.Generic.List[string]]::new()
$runtimeManifestText.TrimEnd([char]13, [char]10).Split(@($crlf, $lf), [StringSplitOptions]::None) |
    ForEach-Object { $manifestLines.Add($_) }
$header = $manifestLines[0].Split([char]9)
$stableKeyIndex = [Array]::IndexOf($header, 'stableKey')
$assetKeyIndex = [Array]::IndexOf($header, 'assetKey')
$englishIndex = [Array]::IndexOf($header, 'english')
$iosStatusIndex = [Array]::IndexOf($header, 'iosAssetStatus')
$imageActionIndex = [Array]::IndexOf($header, 'imageAction')
if (@($stableKeyIndex, $assetKeyIndex, $englishIndex, $iosStatusIndex, $imageActionIndex) -contains -1) {
    throw 'Vocabulary manifest columns required by the generated importer are missing.'
}

$manifestByStableKey = @{}
for ($index = 1; $index -lt $manifestLines.Count; $index += 1) {
    $fields = $manifestLines[$index].Split([char]9)
    $manifestByStableKey[$fields[$stableKeyIndex]] = [pscustomobject]@{
        LineIndex = $index
        Fields = $fields
    }
}

$preflight = foreach ($provenance in $provenanceRows) {
    if ($provenance.reviewStatus -ne 'visually_reviewed' -or
        $provenance.generationOutputID -notmatch '^exec-[0-9a-f-]+$' -or
        $provenance.promptSection -notmatch '^Cell [0-9]+$' -or
        $provenance.generatedDate -notmatch '^2026-09-(12|13)$') {
        throw "Invalid generated provenance fields for $($provenance.stableKey)."
    }
    if (-not $manifestByStableKey.ContainsKey($provenance.stableKey)) {
        throw "Generated stable key is absent from the manifest: $($provenance.stableKey)"
    }

    $manifest = $manifestByStableKey[$provenance.stableKey]
    $fields = $manifest.Fields
    if ($fields[$assetKeyIndex] -ne $provenance.assetKey -or $fields[$englishIndex] -ne $provenance.english) {
        throw "Generated provenance identity differs from the manifest: $($provenance.stableKey)"
    }
    $lifecycle = "$($fields[$iosStatusIndex])/$($fields[$imageActionIndex])"
    if ($lifecycle -notin @('missing_ios/create_new', 'existing_ios/reuse_ios')) {
        throw "Unexpected generated-asset lifecycle for $($provenance.stableKey): $lifecycle"
    }

    $sourcePath = Join-Path $masterRoot "$($provenance.assetKey).png"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Generated master is missing: $sourcePath"
    }
    $inspection = [GeneratedVocabularyPngInspector]::Inspect($sourcePath)
    if ($inspection[0] -lt 1024 -or $inspection[1] -lt 1024 -or
        $inspection[2] -ne 0 -or $inspection[3] -ne 255) {
        throw "Generated master must be at least 1024 square with a real 0-255 alpha range: $sourcePath"
    }

    $destinationDirectory = Join-Path $catalogRoot "$($provenance.assetKey).imageset"
    $destinationPath = Join-Path $destinationDirectory "$($provenance.assetKey).png"
    if (Test-Path -LiteralPath $destinationDirectory) {
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf) -or
            (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash) {
            throw "Existing generated imageset differs from its reviewed master: $($provenance.assetKey)"
        }
    }

    [pscustomobject]@{
        Provenance = $provenance
        Manifest = $manifest
        SourcePath = $sourcePath
        DestinationDirectory = $destinationDirectory
        DestinationPath = $destinationPath
        Width = $inspection[0]
        Height = $inspection[1]
        AlphaMinimum = $inspection[2]
        AlphaMaximum = $inspection[3]
    }
}

$reportRows = [System.Collections.Generic.List[string]]::new()
$reportRows.Add(@(
    'stableKey', 'assetKey', 'english', 'sourcePath', 'sourceBytes', 'sourceSHA256',
    'outputPath', 'outputBytes', 'outputSHA256', 'width', 'height',
    'alphaMinimum', 'alphaMaximum', 'generationTool', 'generationOutputID',
    'promptSource', 'promptSection', 'generatedDate', 'reviewStatus', 'status'
) -join [char]9)

foreach ($item in $preflight) {
    if (-not (Test-Path -LiteralPath $item.DestinationDirectory)) {
        [void](New-Item -ItemType Directory -Path $item.DestinationDirectory)
        Copy-Item -LiteralPath $item.SourcePath -Destination $item.DestinationPath
        Write-Utf8NoBom (Join-Path $item.DestinationDirectory 'Contents.json') ((New-ContentsJson $item.Provenance.assetKey) + $lf)
    }

    $sourceHash = (Get-FileHash -LiteralPath $item.SourcePath -Algorithm SHA256).Hash
    $outputHash = (Get-FileHash -LiteralPath $item.DestinationPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $outputHash) {
        throw "Imported bytes differ from generated master: $($item.Provenance.assetKey)"
    }

    $fields = $item.Manifest.Fields
    $fields[$iosStatusIndex] = 'existing_ios'
    $fields[$imageActionIndex] = 'reuse_ios'
    $manifestLines[$item.Manifest.LineIndex] = $fields -join [char]9

    $reportRows.Add(@(
        $item.Provenance.stableKey,
        $item.Provenance.assetKey,
        $item.Provenance.english,
        (Get-RelativePath $workspaceRoot $item.SourcePath),
        (Get-Item -LiteralPath $item.SourcePath).Length,
        $sourceHash,
        (Get-RelativePath $RepositoryRoot $item.DestinationPath),
        (Get-Item -LiteralPath $item.DestinationPath).Length,
        $outputHash,
        $item.Width,
        $item.Height,
        $item.AlphaMinimum,
        $item.AlphaMaximum,
        'OpenAI built-in image_gen',
        $item.Provenance.generationOutputID,
        "artwork-staging\$($item.Provenance.promptSource.Replace('/', '\'))",
        $item.Provenance.promptSection,
        $item.Provenance.generatedDate,
        $item.Provenance.reviewStatus,
        'success'
    ) -join [char]9)
}

$updatedManifest = ($manifestLines -join $newline) + $newline
Write-Utf8NoBom $runtimeManifestPath $updatedManifest
Write-Utf8NoBom $documentationManifestPath $updatedManifest
Write-Utf8NoBom $reportPath (($reportRows -join $lf) + $lf)

Write-Output "VOCABULARY_GENERATED_ASSETS_IMPORTED=$($preflight.Count)"
Write-Output "VOCABULARY_GENERATED_PROVENANCE=$reportPath"

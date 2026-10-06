param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$MasterRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'artwork-staging\masters')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$catalogRoot = Join-Path $RepositoryRoot 'Resources\LanguageImages.xcassets'
$reportPath = Join-Path $RepositoryRoot 'docs\vocabulary-known-fix-provenance.tsv'
$items = @(
    @{
        StableKey = 'home_dehumidifier'
        AssetKey = 'dehumidifier'
        PreviousSHA256 = '152917818ADB52F389317BBE1CC87F037774D735CD2D082CCA3C8BBDD904E4EC'
        PromptSection = 'Dehumidifier'
        GenerationOutputID = 'exec-8e293e68-ce53-417a-9112-f5d887c0168e'
    },
    @{
        StableKey = 'shapes_helix'
        AssetKey = 'helix'
        PreviousSHA256 = 'B625C61F8649C7C8330D985BDB5CC2C8E374788A48756522EB9EF360F457476C'
        PromptSection = 'Helix'
        GenerationOutputID = 'exec-daac7d43-eca3-4bfc-94df-21b6eb45bbee'
    }
)

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Get-RelativePath([string]$Root, [string]$Path) {
    $rootURI = [Uri](([IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'))
    $pathURI = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($rootURI.MakeRelativeUri($pathURI).ToString()).Replace('/', '\')
}

$workspaceRoot = Split-Path -Parent $RepositoryRoot
$reportRows = [System.Collections.Generic.List[string]]::new()
$reportRows.Add(@(
    'stableKey', 'assetKey', 'sourcePath', 'sourceBytes', 'sourceSHA256',
    'outputPath', 'outputBytes', 'outputSHA256', 'width', 'height', 'hasAlpha',
    'generationTool', 'generationOutputID', 'promptSource', 'promptSection',
    'reviewedDate', 'status'
) -join [char]9)

foreach ($item in $items) {
    $sourcePath = Join-Path $MasterRoot "$($item.AssetKey).png"
    $destinationPath = Join-Path $catalogRoot "$($item.AssetKey).imageset\$($item.AssetKey).png"
    foreach ($requiredPath in @($sourcePath, $destinationPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required known-fix image is missing: $requiredPath"
        }
    }

    $sourceImage = [Drawing.Image]::FromFile($sourcePath, $true)
    try {
        if ($sourceImage.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid -or
            $sourceImage.Width -lt 1024 -or $sourceImage.Height -lt 1024 -or
            -not (($sourceImage.Flags -band [Drawing.Imaging.ImageFlags]::HasAlpha) -ne 0)) {
            throw "Known-fix master must be a decoded alpha PNG at least 1024 by 1024: $sourcePath"
        }
        $width = $sourceImage.Width
        $height = $sourceImage.Height
        $hasAlpha = $true
    } finally {
        $sourceImage.Dispose()
    }

    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
    $destinationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash
    if ($destinationHash -notin @($item.PreviousSHA256, $sourceHash)) {
        throw "Existing $($item.AssetKey) asset is neither the reviewed Android migration nor the reviewed replacement."
    }
    if ($destinationHash -eq $item.PreviousSHA256) {
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash -ne $sourceHash) {
        throw "Imported known-fix bytes differ from the reviewed master: $($item.AssetKey)"
    }

    $reportRows.Add(@(
        $item.StableKey,
        $item.AssetKey,
        (Get-RelativePath $workspaceRoot $sourcePath),
        (Get-Item -LiteralPath $sourcePath).Length,
        $sourceHash,
        (Get-RelativePath $RepositoryRoot $destinationPath),
        (Get-Item -LiteralPath $destinationPath).Length,
        $sourceHash,
        $width,
        $height,
        $hasAlpha,
        'OpenAI built-in image_gen',
        $item.GenerationOutputID,
        'artwork-staging\known-fix-generation-prompts.md',
        $item.PromptSection,
        '2026-09-12',
        'success'
    ) -join [char]9)
}

Write-Utf8NoBom $reportPath (($reportRows -join "`n") + "`n")
Write-Output "VOCABULARY_KNOWN_FIXES_IMPORTED=$($items.Count)"

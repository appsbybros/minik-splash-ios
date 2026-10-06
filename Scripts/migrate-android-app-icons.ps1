param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$AndroidRoot = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'android')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$drawableRoot = Join-Path $AndroidRoot 'app\src\main\res\drawable'
$assetCatalog = Join-Path $RepositoryRoot 'Resources\MinikVisuals.xcassets'

function New-Canvas([bool]$UseGradient) {
    $bitmap = [Drawing.Bitmap]::new(1024, 1024, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ($UseGradient) {
        $rectangle = [Drawing.Rectangle]::new(0, 0, 1024, 1024)
        $brush = [Drawing.Drawing2D.LinearGradientBrush]::new(
            $rectangle,
            [Drawing.ColorTranslator]::FromHtml('#03A9F4'),
            [Drawing.ColorTranslator]::FromHtml('#009688'),
            45
        )
        $blend = [Drawing.Drawing2D.ColorBlend]::new()
        $blend.Colors = @(
            [Drawing.ColorTranslator]::FromHtml('#03A9F4'),
            [Drawing.ColorTranslator]::FromHtml('#3F51B5'),
            [Drawing.ColorTranslator]::FromHtml('#009688')
        )
        $blend.Positions = [single[]]@(0, 0.5, 1)
        $brush.InterpolationColors = $blend
        $graphics.FillRectangle($brush, $rectangle)
        $brush.Dispose()
    } else {
        $graphics.Clear([Drawing.ColorTranslator]::FromHtml('#DAE2E1'))
    }

    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Write-AppIcon(
    [string]$SetName,
    [string]$SourceName,
    [bool]$UseGradient
) {
    $sourcePath = Join-Path $drawableRoot $SourceName
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing Android icon source: $sourcePath"
    }

    $destinationDirectory = Join-Path $assetCatalog "$SetName.appiconset"
    [void](New-Item -ItemType Directory -Force -Path $destinationDirectory)
    $destinationPath = Join-Path $destinationDirectory "$SetName-1024.png"
    $canvas = New-Canvas -UseGradient $UseGradient
    $source = [Drawing.Image]::FromFile($sourcePath)
    try {
        $canvas.Graphics.DrawImage($source, 0, 0, 1024, 1024)
        $canvas.Bitmap.Save($destinationPath, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $source.Dispose()
        $canvas.Graphics.Dispose()
        $canvas.Bitmap.Dispose()
    }

    $contents = @{
        images = @(@{
            filename = "$SetName-1024.png"
            idiom = 'universal'
            platform = 'ios'
            size = '1024x1024'
        })
        info = @{ author = 'xcode'; version = 1 }
    } | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText(
        (Join-Path $destinationDirectory 'Contents.json'),
        "$contents`n",
        [Text.UTF8Encoding]::new($false)
    )
}

# These are the exact owning Android adaptive-icon foreground/background pairs:
# plus -> app/src/plus foreground over bg_colorful_back_for_logo;
# plus-english-only has no flavor override and therefore uses the main pair.
Write-AppIcon -SetName 'MinikPlusAppIcon' -SourceName 'minik_plus_logo_small.png' -UseGradient $false
Write-AppIcon -SetName 'MinikPlusEnglishAppIcon' -SourceName 'minik_logo333.png' -UseGradient $true

Write-Output 'ANDROID_APP_ICONS_MIGRATED=2'

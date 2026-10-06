[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$errors = [System.Collections.Generic.List[string]]::new()

function Read-Required([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing $RelativePath")
        return ''
    }
    return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
}

function Require([string]$Content, [string]$Pattern, [string]$Message) {
    if ($Content -notmatch $Pattern) { $errors.Add($Message) }
}

$parent = Read-Required 'Sources/ParentAreaView.swift'
$progress = Read-Required 'Sources/ProgressStatisticsView.swift'
$records = Read-Required 'Sources/RecordsStreaksView.swift'
$leaderboard = Read-Required 'Sources/RecordsLeaderboardView.swift'
$pingPong = Read-Required 'Sources/PingPongView.swift'
$hub = Read-Required 'Sources/MinikActivityHubView.swift'
$languageShell = Read-Required 'Sources/LanguageShellViews.swift'
$visuals = Read-Required 'Sources/MinikPracticeVisuals.swift'
$buzzer = Read-Required 'Sources/MathSubmitBuzzer.swift'
$numberLine = Read-Required 'Sources/MathNumberLinePlacementView.swift'

Require $parent 'MinikVisualAsset\.close[\s\S]*?\.frame\(width: 44, height: 44\)[\s\S]*?accessibilityLabel\("Close Parent Area"\)' 'The compact Parent Area close control lacks a 44-point hit target or label.'
foreach ($entry in @(
    @{ Content = $progress; Name = 'Progress' },
    @{ Content = $records; Name = 'Records' }
)) {
    Require $entry.Content 'chevron\.backward\.circle\.fill[\s\S]*?\.frame\(width: compact \? 44 : 48, height: compact \? 44 : 48\)[\s\S]*?accessibilityLabel\("Back to Parent Area"\)' "$($entry.Name) back control lacks an explicit accessible 44-point minimum."
}
Require $leaderboard 'MinikVisualAsset\.close[\s\S]*?\.frame\(width: compact \? 46 : 56, height: compact \? 46 : 56\)[\s\S]*?accessibilityLabel\(String\(localized: "Done"\)\)' 'The leaderboard close control lacks its accessible size/label contract.'
Require $pingPong 'Image\(systemName: "xmark"\)[\s\S]*?\.frame\(width: 44, height: 44\)[\s\S]*?accessibilityLabel\("Close Ping Pong"\)' 'Ping Pong close controls lack a 44-point target or label.'
Require $hub 'Text\(interfaceLocaleID\.text\("Parent Area"\)\)[\s\S]*?minHeight: metrics\.parentButtonHeight[\s\S]*?var parentButtonHeight: CGFloat \{ value\(48, 60\) \}' 'The shared hub Parent Area entry lacks its 44-point minimum.'
Require $hub 'MinikVisualAsset\.trophy[\s\S]*?\.frame\(width: metrics\.roundButton, height: metrics\.roundButton\)[\s\S]*?accessibilityLabel\(String\(localized: "Top 20 records"\)\)[\s\S]*?var roundButton: CGFloat \{ value\(52, 76\) \}' 'The shared hub Records icon lacks its explicit label/target.'
Require $languageShell 'imageName: MinikVisualAsset\.home[\s\S]*?label: interfaceLocaleID\.text\("Home"\)[\s\S]*?imageName: MinikVisualAsset\.trophy[\s\S]*?label: interfaceLocaleID\.text\("Top 20 records"\)[\s\S]*?\.frame\(width: metrics\.roundButton, height: metrics\.roundButton\)[\s\S]*?\.accessibilityLabel\(Text\(label\)\)[\s\S]*?var roundButton: CGFloat \{ value\(58, 84\) \}' 'The Language menu icon controls lack explicit labels and adequate targets.'
Require $visuals 'struct MinikUtilityButtonStyle[\s\S]*?\.frame\(minWidth: 44, minHeight: (?:44|tablet \? 52 : 44)\)' 'Shared utility controls do not enforce a 44-point minimum.'
Require $visuals 'MinikVisualAsset\.success[\s\S]*?MinikVisualAsset\.tryAgain[\s\S]*?String\(localized: "Great job!"\)[\s\S]*?String\(localized: "Try again"\)' 'Correctness feedback is not expressed with both imagery and text.'
Require $buzzer 'Image\(systemName: "checkmark"\)[\s\S]*?\.frame\(width: 112, height: 78\)[\s\S]*?accessibilityLabel\(String\(localized: "Check answer"\)\)' 'The Math submit control lacks its accessible label/target.'
Require $numberLine '\.environment\(\\\.layoutDirection, \.leftToRight\)[\s\S]*?\.accessibilityElement\(children: \.ignore\)[\s\S]*?\.accessibilityLabel\(String\(session\.selectedValue\)\)' 'The spatial Math number line does not preserve LTR geometry with a semantic value label.'

$swiftFiles = Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Sources') -Filter '*.swift' -File
$directionalMistakes = @($swiftFiles | Select-String -Pattern '\.padding\(\.(left|right)|alignment:\s*\.(left|right)')
foreach ($match in $directionalMistakes) {
    $errors.Add("Hardcoded directional layout API: $($match.Path):$($match.LineNumber)")
}

$errors | ForEach-Object { "ACCESSIBILITY_RELEASE_ERROR=$_" }
"ACCESSIBILITY_RELEASE_VIEWS_AUDITED=10"
"ACCESSIBILITY_RELEASE_DIRECTIONAL_ERRORS=$($directionalMistakes.Count)"
"ACCESSIBILITY_RELEASE_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) { exit 1 }

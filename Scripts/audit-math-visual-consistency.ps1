$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$recordPath = Join-Path $repoRoot 'docs/math-visual-consistency.tsv'
$record = @(Import-Csv -LiteralPath $recordPath -Delimiter "`t")
$expectedActivities = @(
    'learnMath', 'mathPairs', 'buildNumber', 'buildQuantity', 'visualToAnswer',
    'answerToRepresentation', 'buildMath', 'mathMixed', 'mathCards',
    'mathSoccer', 'mathTower', 'mathMemory', 'pingPong'
)

if ($record.Count -ne 13 -or
    (($record.activity_id -join '|') -ne ($expectedActivities -join '|'))) {
    $errors.Add('Math visual record must contain the exact ordered 13 production identities.')
}
foreach ($row in $record) {
    if ($row.representative_levels -ne 'M1;M5;M10') {
        $errors.Add("Math visual record does not cover low/mid/high levels for $($row.activity_id).")
    }
    if ($row.static_status -ne 'static_consistent_runtime_pending' -or
        [string]::IsNullOrWhiteSpace($row.runtime_gate)) {
        $errors.Add("Math visual record overclaims or omits the runtime gate for $($row.activity_id).")
    }
}

$checks = @(
    @{ File = 'Sources/ProductConfiguration.swift'; Pattern = 'case \.minikMath:[\s\S]*contentDomain: \.math[\s\S]*allowedLearnedLanguages: \[\][\s\S]*fixedLearnedLanguage: nil[\s\S]*isLearningLanguageSelectionAvailable: false'; Label = 'Math has no learned-language state' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'if visualIdentity == \.math \{[\s\S]*Image\("math_frame_background"\)'; Label = 'Math uses its dedicated clean Minik frame background' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'struct MinikPracticeSurface[\s\S]*\.fill\(\.white\.opacity\(0\.94\)\)'; Label = 'Practice content uses the shared light/white surface' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'struct MinikPracticeHeader[\s\S]*MinikVisualAsset\.close'; Label = 'Practice screens share the branded close control' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'name: isCorrect \? MinikVisualAsset\.success : MinikVisualAsset\.tryAgain'; Label = 'Practice feedback shares real Minik success/failure art' },
    @{ File = 'Sources/RepresentationView.swift'; Pattern = 'private func mathText[\s\S]*\.environment\(\\\.layoutDirection, \.leftToRight\)'; Label = 'Math expressions remain LTR under RTL interfaces' },
    @{ File = 'Sources/BuildView.swift'; Pattern = 'case \.mathExpression, \.math:[\s\S]*\.leftToRight'; Label = 'Math build tokens remain LTR' },
    @{ File = 'Sources/MathFractionConstructionView.swift'; Pattern = 'fractionBar[\s\S]*\.environment\(\\\.layoutDirection, \.leftToRight\)'; Label = 'Fraction construction remains spatially LTR' },
    @{ File = 'Sources/MathNumberLinePlacementView.swift'; Pattern = 'private var numberLine[\s\S]*\.environment\(\\\.layoutDirection, \.leftToRight\)'; Label = 'Number-line construction remains spatially LTR' },
    @{ File = 'Sources/MathCurriculum.swift'; Pattern = 'title: String\(localized: "Level 1"\)[\s\S]*title: String\(localized: "Level 10"\)'; Label = 'Child-facing Math levels use Level 1 through Level 10 wording' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'ForEach\(ActivityCatalog\.mathSections[\s\S]*route = \.math\(activity, selectedMathLevelID'; Label = 'Math Home routes the canonical activity cards at the selected level' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'MathM1SessionView[\s\S]*MathM5SessionView[\s\S]*MathM10SessionView'; Label = 'Home routes representative low/mid/high production session views' },
    @{ File = 'Sources/PingPongScene.swift'; Pattern = 'SKSpriteNode\(imageNamed: PingPongAssetNames\.arena\)[\s\S]*PingPongTableLayout'; Label = 'Ping Pong uses its dedicated production arena and table layout' }
)

foreach ($check in $checks) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $check.File) -Raw -Encoding utf8
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing $($check.Label) [$($check.File)]")
    }
}

$sharedScreenFiles = @(
    'LearnView.swift', 'PairsView.swift', 'BuildView.swift', 'MultipleChoiceView.swift',
    'MathCountConstructionView.swift', 'MathStructuredConstructionView.swift',
    'MathFractionConstructionView.swift', 'MathNumberLinePlacementView.swift',
    'MathCardsView.swift', 'SoccerView.swift', 'TowerView.swift', 'MemoryView.swift'
)
foreach ($file in $sharedScreenFiles) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot "Sources/$file") -Raw -Encoding utf8
    if ($source -notmatch 'MinikPracticeScreen' -or $source -notmatch 'MinikPracticeSurface') {
        $errors.Add("Math presentation does not use the shared Minik practice frame: $file")
    }
}

$brandedReplayFiles = @(
    'MathCountConstructionView.swift', 'MathStructuredConstructionView.swift',
    'MathFractionConstructionView.swift', 'MathNumberLinePlacementView.swift',
    'MathCardsView.swift'
)
foreach ($file in $brandedReplayFiles) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot "Sources/$file") -Raw -Encoding utf8
    if ($source -notmatch 'MinikVisualAsset\.speaker') {
        $errors.Add("Math replay is missing branded speaker art: $file")
    }
    if ($source -match 'speaker\.wave') {
        $errors.Add("Math replay regressed to an SF speaker despite owned Minik art: $file")
    }
}

foreach ($level in 1..10) {
    $factoryPath = Join-Path $repoRoot "Sources/MathM$($level)ActivitySessionFactory.swift"
    $factory = Get-Content -LiteralPath $factoryPath -Raw -Encoding utf8
    foreach ($activity in $expectedActivities) {
        if ($factory -notmatch "case \.$activity") {
            $errors.Add("M$level factory is missing production identity: $activity")
        }
    }
}

$hub = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/MinikActivityHubView.swift') -Raw -Encoding utf8
if ($hub -match 'MathLearnDevelopmentView') {
    $errors.Add('A development/dashboard Math screen leaked into production routing.')
}

Write-Output "MATH_VISUAL_IDENTITIES_AUDITED=$($record.Count)"
Write-Output 'MATH_VISUAL_REPRESENTATIVE_LEVELS=M1,M5,M10'
Write-Output "MATH_VISUAL_SHARED_SCREENS_AUDITED=$($sharedScreenFiles.Count)"
Write-Output "MATH_VISUAL_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | Select-Object -First 30 | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'MATH_VISUAL_CONSISTENCY_OK'

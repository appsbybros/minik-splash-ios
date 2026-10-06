$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @(
    @{ File = 'Sources/TowerView.swift'; Pattern = 'private var languageTowerBody:[\s\S]*LanguageTowerPanel\(\s*sceneAsset: MinikVisualAsset\.towerScene'; Label = 'Language Tower owns the Android pastel scene instead of the generic practice shell' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'languageTowerNavigation\([\s\S]*Image\(systemName: "speaker\.wave\.1\.fill"\)[\s\S]*MinikVisualAsset\.close'; Label = 'Android-equivalent speaker replay and exact close stay inside the Language panel' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'interfaceLocaleID\.text\("Letter Tower"\)'; Label = 'The Android Letter Tower title uses the selected interface locale' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'Text\("Drag the letters in the correct order"\)'; Label = 'The exact Android instruction remains visible' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'representation: \.learningText\(content\.targetText\)'; Label = 'Target word remains visible' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'private func languageTowerLetterBlock\([\s\S]*\.position\(center\)[\s\S]*\.gesture\(\s*languageTowerDrag\(block, index: index, metrics: metrics\)[\s\S]*func looseSlotCenter\(index: Int, seed: Int\) -> CGPoint'; Label = 'Loose physical blocks occupy stable scene positions and remain draggable' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'allBlocks\.firstIndex\(where: \{ \$0\.id == block\.id \}\)'; Label = 'Duplicate blocks retain physical identity when positioned' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'func towerSlotCenter\(_ slot: Int\) -> CGPoint \{\s*CGPoint\(x: towerX, y: towerBaseBottom - blockSize / 2 - CGFloat\(slot\) \* blockSize\)'; Label = 'Semantic stack order is rendered bottom-up' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'case \.spacer[\s\S]*Color\(white: 0\.96\)'; Label = 'Whitespace auto-advances as a physical spacer' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'isBase: acceptedIndex == 0'; Label = 'The first accepted block remains the locked base' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'Locked base letter %@'; Label = 'VoiceOver distinguishes the locked base' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'Placed letter %@'; Label = 'VoiceOver distinguishes placed blocks' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'Available letter %@'; Label = 'VoiceOver distinguishes loose available blocks' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'Color\(red: 1\.00, green: 0\.059, blue: 0\.529\)[\s\S]*Color\(red: 0\.341, green: 0\.831, blue: 0\.757\)'; Label = 'The seven live Android solid block colors are present' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'MinikVisualAsset\.towerSand[\s\S]*MinikVisualAsset\.towerMascot[\s\S]*MinikVisualAsset\.towerSandPile'; Label = 'Exact sand, gift-block mascot, and beach foreground compose the lower scene' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'feedbackSoundPlayer\.play\(\.incorrect\)'; Label = 'Wrong placement uses the Android failure sound' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'speechPlayer\.speak\(\[letterCue, wordCue\]\)'; Label = 'The final accepted letter is followed by completed-word speech' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'LanguageTowerConfettiView\(reduceMotion: reduceMotion, startedAt: confettiStart\)[\s\S]*if completedRound \{[\s\S]*languageConfettiStart = Date\(\)'; Label = 'Completed words restore Reduce-Motion-aware Android confetti' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'pendingLanguageTransition = LanguageTowerTransition'; Label = 'Delayed feedback is presentation-scoped' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'expectedPresentationID: transition\.presentationID'; Label = 'Stale callbacks cannot advance a later word' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'resolveLanguageTransitionForBackground\(\)'; Label = 'Backgrounding resolves delayed Tower work safely' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'languageAttemptTracker\.makeAttempt\([\s\S]*activityFamily: \.tower'; Label = 'Tower retains specialized semantic token attempts' },
    @{ File = 'Sources/LanguageTowerPracticeSession.swift'; Pattern = 'mutating func takeCompletion\(\)[\s\S]*!didEmitCompletion'; Label = 'Each word completion emits exactly once' },
    @{ File = 'Sources/LanguageTowerPracticeSession.swift'; Pattern = 'presentationID = UUID\(\)[\s\S]*didEmitCompletion = false'; Label = 'Each continuous word begins with fresh identity and completion state' },
    @{ File = 'Sources/LanguageTowerPracticeSession.swift'; Pattern = 'remainingRounds\.isEmpty[\s\S]*lastAdvanceBoundary = poolTracker\.takeBoundary'; Label = 'Full Tower pool exhaustion is exposed exactly once' },
    @{ File = 'Sources/LanguageTowerRewardMapper.swift'; Pattern = 'activityID\.rawValue == "language\.tower"[\s\S]*reason: \.activityCompleted'; Label = 'Tower completion uses a typed Language-only reward boundary' },
    @{ File = 'Sources/Rewards.swift'; Pattern = 'androidTowerReference[\s\S]*pointsDelta: 2[\s\S]*streakEffect: \.unchanged'; Label = 'Android Tower completion awards exactly two points without invented streak behavior' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'onWordCompleted:\s*\{\s*recordLanguageTowerCompletion\(\$0\)'; Label = 'Production Language Tower wires the completion reward' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'if session\.orderedTokenContent != nil \{[\s\S]*languageTowerBody[\s\S]*\} else \{[\s\S]*standardBody'; Label = 'Language reconstruction is isolated from Math Tower' },
    @{ File = 'Sources/MinikVisualAssets.swift'; Pattern = 'towerScene = "minik_tower_scene"'; Label = 'Typed Tower scene asset exists' },
    @{ File = 'docs/minik-visual-asset-provenance.tsv'; Pattern = 'minik_tower_scene\t[^\r\n]*plus_background\.webp'; Label = 'Exact Android Tower scene provenance is recorded' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift'; Pattern = 'testConsumingOneDuplicateLeavesTheOtherPhysicalCopyAvailable'; Label = 'Duplicate consumption coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift'; Pattern = 'testLockedBaseCannotBeConsumedAgain'; Label = 'Locked-base rejection coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift'; Pattern = 'testAcceptedStackPreservesSemanticBottomUpOrder'; Label = 'Bottom-up semantic stack coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift'; Pattern = 'testCompletionEmitsExactlyOnceAndNextWordGetsFreshIdentity'; Label = 'Exactly-once completion and clean-word coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift'; Pattern = 'testStaleTransitionCannotAdvanceALaterWord'; Label = 'Stale-transition coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift'; Pattern = 'testTowerCompletionRewardIsFixedTwoPointsAndIdempotent'; Label = 'Fixed reward/idempotency coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TowerSessionTests.swift'; Pattern = 'testOrderedBlockPlacementDoesNotChangeMathValueOrderingState'; Label = 'Math Tower isolation coverage remains' }
)

$errors = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $check.File) -Raw -Encoding utf8
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing Tower contract: $($check.Label) [$($check.File)]")
    }
}

$towerSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/TowerView.swift') -Raw -Encoding utf8
$languageStart = $towerSource.IndexOf('private var languageTowerBody: some View')
$standardStart = $towerSource.IndexOf('private var progressLabel: String')
if ($languageStart -lt 0 -or $standardStart -le $languageStart) {
    $errors.Add('Unable to isolate the dedicated Language Tower presentation.')
} else {
    $languageBody = $towerSource.Substring($languageStart, $standardStart - $languageStart)
    foreach ($forbidden in @('MinikPracticeScreen(', 'MinikPracticeSurface(', 'LazyVGrid(', 'progressLabel:', 'MinikFeedbackBadge(', 'Text("Your tower")', 'Text("Available blocks")')) {
        if ($languageBody.Contains($forbidden)) {
            $errors.Add("Language Tower still contains forbidden generic presentation: $forbidden")
        }
    }
}

Write-Output "LANGUAGE_TOWER_CONTRACTS_AUDITED=$($checks.Count)"
Write-Output "LANGUAGE_TOWER_CONTRACT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'LANGUAGE_TOWER_AUDIT_OK'

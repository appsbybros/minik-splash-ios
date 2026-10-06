$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @(
    @{ File = 'Sources/CardsView.swift'; Pattern = 'MinikVisualAsset\.cardsBackground'; Label = 'Cards consumes the original sky/meadow background' },
    @{ File = 'Sources/LanguageActivityVisuals.swift'; Pattern = 'MinikLanguageLogo\(\)'; Label = 'Cards retains Minik logo placement' },
    @{ File = 'Sources/LanguageActivityVisuals.swift'; Pattern = 'MinikVisualAsset\.close'; Label = 'Cards uses the branded close control' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'onReplay: nil, onExit: exit[\s\S]*\.accessibilityAction\(named: "Replay current word"\)\s*\{\s*replayCurrentCard\(\)\s*\}'; Label = 'Cards shows no replay control, as Android; VoiceOver keeps learned-word replay' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'LanguagePanelNavigation\(wide: wide, showsLogo: true'; Label = 'Live Cards header uses full wordmark and inside close control' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'Text\("Cards"\)'; Label = 'Cards retains the Android title' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'MinikVisualAsset\.cardsMascot'; Label = 'Cards uses the Android pairs_image mascot' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'context: \.cardsHero'; Label = 'Cards retains its large word presentation' },
    @{ File = 'Sources/CardsView.swift'; Pattern = '\.onTapGesture\(perform: advance\)'; Label = 'The full Cards body preserves Android manual advance' },
    @{ File = 'Sources/CardsView.swift'; Pattern = '\.task\(id: AdvanceTaskKey\(presentationID: session\.presentationID, active: scenePhase == \.active\)'; Label = 'Each card schedules one cancellable automatic advance' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'let presentationCardID = session\.currentCard\.id[\s\S]*advance\(ifCurrentCardID: presentationCardID, presentationID: presentationID\)'; Label = 'Automatic advance is guarded by captured presentation identity' },
    @{ File = 'Sources/CardsSession.swift'; Pattern = 'advance\(ifCurrentCardID expectedCardID: StudyCardID\)[\s\S]*guard currentCard\.id == expectedCardID'; Label = 'Stale timers cannot advance a different card' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'min\(\s*11_000,\s*max\(4_500, 3_200 \+ visibleCharacterCount \* 170 \+ \(wordCount - 1\) \* 500\)'; Label = 'Android display timing bounds and formula are preserved' },
    @{ File = 'Sources/CardsView.swift'; Pattern = '\.onChange\(of: scenePhase\)'; Label = 'Cards stops speech when backgrounded' },
    @{ File = 'Sources/CardsView.swift'; Pattern = '\.onDisappear\(perform: speechPlayer\.stop\)'; Label = 'Cards stops speech on dismissal' },
    @{ File = 'Sources/CardsSession.swift'; Pattern = 'guard presentationID == expectedID'; Label = 'Repeated and single-card presentations reject old timers' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'min\(330, max\(156, \(height - 96\) \* 0\.28\)\)[\s\S]*min\(154, max\(104, height \* 0\.20\)\)'; Label = 'Short-word card: Android sw600dp frame on iPad, 70 percent of the prior 220-point frame on phones' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'width: wide \? 300 : 200'; Label = 'Original mascot is large and raised above the bottom inset' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'ScrollView \{\s*pageLayout \{[\s\S]*?\.scrollBounceBehavior\(\.basedOnSize\)'; Label = 'The card page scrolls only when its content is taller than the screen (basedOnSize)' },
    @{ File = 'Sources/CardsSession.swift'; Pattern = 'nextCycle\.first\?\.id == lastCardID'; Label = 'A new random bag does not immediately repeat its prior final card' },
    @{ File = 'Sources/LanguageWordCardsContentProvider.swift'; Pattern = 'representations: \[\.learningText\(displayText\)\]'; Label = 'Production Cards remain learned-word-only like Android' },
    @{ File = 'Tests/ProductConfigurationTests/CardsSessionTests.swift'; Pattern = 'testAdvancingThroughCycleLosesOrDuplicatesNoCard'; Label = 'Cycle identity test exists' },
    @{ File = 'Tests/ProductConfigurationTests/CardsSessionTests.swift'; Pattern = 'testAdvanceAfterFinalCardStartsNewShuffledCycleAtFirstPosition'; Label = 'No-boundary-repeat test exists' },
    @{ File = 'Tests/ProductConfigurationTests/CardsSessionTests.swift'; Pattern = 'testManualAdvanceMakesStaleTimedAdvanceANoOpWithoutSkippingNextCard'; Label = 'Manual-versus-timer race test exists' },
    @{ File = 'Tests/ProductConfigurationTests/CardsSessionTests.swift'; Pattern = 'testOnePresentationCanProduceAtMostOneIdentityGuardedAdvance'; Label = 'At-most-one guarded advance test exists' },
    @{ File = 'Tests/ProductConfigurationTests/CardsSessionTests.swift'; Pattern = 'testCurrentTimedPresentationAdvancesNormally'; Label = 'Normal guarded timer advance test exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageWordCardsContentProviderTests.swift'; Pattern = 'testProductLanguagePolicyIsEnforced'; Label = 'Product/language policy test exists' }
)

$errors = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    $path = Join-Path $repoRoot $check.File
    $source = Get-Content -LiteralPath $path -Raw -Encoding utf8
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing C9 contract: $($check.Label) [$($check.File)]")
    }
}

$cardsSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/CardsView.swift') -Raw -Encoding utf8
if ($cardsSource -match 'MinikPracticeScreen') {
    $errors.Add('Language Cards must not fall back to the generic progress-pill practice shell.')
}
if ($cardsSource -match 'onAttempt') {
    $errors.Add('Non-graded Word Cards must not emit progress attempts.')
}

Write-Output "LANGUAGE_WORD_CARDS_CONTRACTS_AUDITED=$($checks.Count + 2)"
Write-Output "LANGUAGE_WORD_CARDS_CONTRACT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

& (Join-Path $PSScriptRoot 'audit-cards-swiftui-api.ps1')
Write-Output 'LANGUAGE_WORD_CARDS_AUDIT_OK'

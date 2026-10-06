$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @(
    @{ File = 'Sources/ActivityCatalog.swift'; Pattern = 'id: "games"[\s\S]*activities: \[\.soccer, \.tower, \.wordMemory, \.ticTacToe\]'; Label = 'Picture Memory remains in the Games section' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'case \.wordMemory:[\s\S]*makeWordMemorySession[\s\S]*presentation: \.languagePicture[\s\S]*makeNextSession:'; Label = 'Production Picture Memory uses its dedicated continuous presentation' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'LanguageActivityScreen\([\s\S]*sceneAsset: MinikVisualAsset\.memoryScene'; Label = 'Language Picture Memory uses the Android pastel scene' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'languageMemoryBoard[\s\S]*count: 3[\s\S]*ForEach\(session\.presentedCards'; Label = 'Language board is a fixed three-column grid' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = '\.aspectRatio\(1, contentMode: \.fit\)'; Label = 'All twelve physical board positions use square cards' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = '\.environment\(\\\.layoutDirection, \.leftToRight\)'; Label = 'RTL interfaces preserve the physical board order' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'struct LanguageMemoryCardStyle[\s\S]*guard state == \.faceDown[\s\S]*Color\(red: 0\.914[\s\S]*Color\(red: 0\.012[\s\S]*Color\(red: 1\.0, green: 0\.722'; Label = 'All three Android card-back palettes are represented' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'case \.faceDown:[\s\S]*Color\.clear'; Label = 'Face-down cards contain no unintended symbol or text' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'if case \.imageAsset\(let asset\) = card\.representation[\s\S]*Image\(asset\.rawValue\)[\s\S]*scaledToFit'; Label = 'Revealed Language cards show the original vocabulary image directly' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'languageMemoryBoard\(metrics\)\s*\.padding\(\.top, metrics\.boardTopGap\)\s*\.padding\(\.bottom, metrics\.boardBottomGap\)\s*\}\s*\.frame\(maxWidth: \.infinity, minHeight: layout\.height, alignment: \.top\)'; Label = 'Picture Memory ends with the board and keeps the lower panel free, as Android hides the Minik boy in single-player Plus' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'minimumContentHeight: \{ _, wide in wide \? 600 : 540 \}'; Label = 'Only small-height or accessibility layouts request scrolling fallback' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'if let speechCue = session\.selectCard\(cardID\)[\s\S]*speechPlayer\.speak\(speechCue\)'; Label = 'Only accepted reveals emit their provider speech cue' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'Task\.sleep\(nanoseconds: 1_000_000_000\)[\s\S]*continueAfterAttempt\([\s\S]*matching: pending\.sessionTransition'; Label = 'Android one-second dwell resolves through a guarded transition' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'pending\.result == \.incorrect[\s\S]*Task\.sleep\(nanoseconds: 220_000_000\)'; Label = 'Mismatch keeps input locked through the flip-back safety interval' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'startNextLanguageRound[\s\S]*makeNextSession\?\(\)[\s\S]*session\.startNewRound\(\)'; Label = 'Completed Language boards continue with clean provider or local rounds' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = '\.onChange\(of: scenePhase\)[\s\S]*cancelLanguageTransitionForBackground\(\)[\s\S]*stopAudio\(\)'; Label = 'Backgrounding resolves/cancels pending work and stops audio' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = '\.onDisappear[\s\S]*pendingLanguageTransition = nil[\s\S]*stopAudio\(\)'; Label = 'Dismissal cancels delayed work and stops audio' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'accessibilityLabel\("Hidden card"\)'; Label = 'Face-down cards expose a semantic accessibility label' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'case \.faceUp, \.matched:[\s\S]*accessibilityValue\(for: state\)'; Label = 'Revealed and matched states expose accessible values' },
    @{ File = 'Sources/MemorySession.swift'; Pattern = 'struct MemoryAttemptTransition[\s\S]*presentationID: UUID[\s\S]*continueAfterAttempt\([\s\S]*matching transition:[\s\S]*pendingTransition == transition'; Label = 'Delayed callbacks carry stable presentation identity' },
    @{ File = 'Sources/MemorySession.swift'; Pattern = 'mutating func startNewRound\(\)[\s\S]*presentationID = UUID\(\)[\s\S]*matchedGroupIndices = \[\][\s\S]*isComplete = false'; Label = 'New rounds replace identity and clear all gameplay state' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageProductionParityTests.swift'; Pattern = 'testPictureMemoryIsGroupedAsAGameWithoutChangingProductionCount'; Label = 'Production Games grouping test exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageWordMemoryContentProviderTests.swift'; Pattern = 'testEachSetContainsTwoIdenticalImagesForTheSameContentItem'; Label = 'Image-to-identical-image semantic pairing test exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageWordMemoryContentProviderTests.swift'; Pattern = 'testDefaultSetsProduceTwelveMemoryCardInstances'; Label = 'Six-pair/twelve-card production size test exists' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testIdenticalRepresentationsCreateDistinctMatchingCardInstances'; Label = 'Physical card identities remain distinct from semantic match identity' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testMatchingUsesGroupIdentityInsteadOfRepresentationEquality'; Label = 'Matching uses semantic group identity' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testAcceptedRevealsEmitOneCueAndIgnoredSelectionsEmitNone'; Label = 'Exact-once accepted reveal speech coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testGenericMathMemoryRemainsSilentWithoutRevealCues'; Label = 'Generic Math memory has no unintended narration' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testIncorrectPairReturnsFaceDownAfterContinueWithoutMatching'; Label = 'Incorrect feedback/continuation behavior is covered' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testIncorrectPairResetDoesNotMoveAnyPhysicalCard'; Label = 'Mismatch preserves every physical board position' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testCorrectContinuePreservesMatchedCardsAndAllowsFurtherPlay'; Label = 'Correct continuation preserves progress' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testNewRoundClearsEveryRevealMatchAndCompletionState'; Label = 'Clean new-round state is covered' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testStaleTransitionCannotMutateANewerRound'; Label = 'Stale transition rejection is covered' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testNewRoundPreservesGenericMathCardsAndSilentContract'; Label = 'Generic Math Memory remains unchanged and silent' },
    @{ File = 'Tests/ProductConfigurationTests/MemorySessionTests.swift'; Pattern = 'testFinalCorrectContinueCompletesAndPostCompletionActionsAreSafe'; Label = 'Completion and post-completion behavior are covered' }
)

$errors = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    $path = Join-Path $repoRoot $check.File
    $source = Get-Content -LiteralPath $path -Raw -Encoding utf8
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing C12 contract: $($check.Label) [$($check.File)]")
    }
}

$memoryView = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/MemoryView.swift') -Raw -Encoding utf8
$languageStart = $memoryView.IndexOf('private var languagePictureBody')
$standardStart = $memoryView.IndexOf('private func headerSection')
if ($languageStart -lt 0 -or $standardStart -le $languageStart) {
    $errors.Add('Could not isolate the dedicated Language Picture Memory composition.')
} else {
    $languageComposition = $memoryView.Substring($languageStart, $standardStart - $languageStart)
    # MemoryGameFragment hides minikBoy in single-player Plus, so the Language board has no mascot.
    foreach ($forbidden in @('ScrollView', 'progressLabel:', 'MinikFeedbackBadge', 'continueButton', 'MinikVisualAsset.memoryMascot')) {
        if ($languageComposition.Contains($forbidden)) {
            $errors.Add("Language Picture Memory contains forbidden generic UI: $forbidden")
        }
    }
}

$mathMemorySources = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Sources') -Filter 'Math*View.swift' -File
foreach ($sourceFile in $mathMemorySources) {
    if ((Get-Content -LiteralPath $sourceFile.FullName -Raw -Encoding utf8) -match 'presentation:\s*\.languagePicture') {
        $errors.Add("Math source opts into Language Picture Memory presentation: $($sourceFile.Name)")
    }
}

Write-Output "LANGUAGE_PICTURE_MEMORY_CONTRACTS_AUDITED=$($checks.Count)"
Write-Output "LANGUAGE_PICTURE_MEMORY_CONTRACT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'LANGUAGE_PICTURE_MEMORY_AUDIT_OK'

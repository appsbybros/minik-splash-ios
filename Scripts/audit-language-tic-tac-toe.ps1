$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @(
    @{ File = 'Sources/ActivityCatalog.swift'; Pattern = 'id: "games"[\s\S]*\.ticTacToe'; Label = 'Tic-Tac-Toe remains a Language Game' },
    @{ File = 'Sources/ActivityCatalog.swift'; Pattern = 'case \.ticTacToe: return String\(localized: "Just for Fun"\)'; Label = 'Menu semantics remain just for fun' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'case \.ticTacToe:[\s\S]*TicTacToeView\([\s\S]*onResolvedRound: recordLanguageTicTacToeCompletion[\s\S]*onExit: returnToHub'; Label = 'Production route uses the dedicated TicTacToeView with outcome rewards but no graded-attempt telemetry' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'MinikPracticeBackground\(\)'; Label = 'Screen uses the Minik themed outer background' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'MinikArtworkImage\(name: MinikVisualAsset\.ticTacToeScene, contentMode: \.fill\)'; Label = 'Dedicated panel uses the exact Android pastel scene' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'MinikArtworkImage\(name: MinikVisualAsset\.close\)'; Label = 'Screen uses the branded close control' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'Text\(TicTacToeFeedbackCopy\.title\)[\s\S]*LinearGradient'; Label = 'Localized title retains the Android blue-teal-green treatment' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'markButton\(\.cross\)[\s\S]*markButton\(\.circle\)'; Label = 'X/O controls remain visible' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'LazyVGrid\([\s\S]*count: 3'; Label = 'Board remains a three-column 3x3 grid' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'colors: \[[\s\S]*0\.52, green: 0\.31, blue: 0\.71[\s\S]*0\.24, green: 0\.79, blue: 0\.84'; Label = 'White board cells retain the Android purple-pink-teal edge' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'MinikVisualAsset\.ticTacToeMascot'; Label = 'Screen uses original Android gameplay mascot art' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'ScrollView \{[\s\S]*\.frame\(minHeight: geometry\.size\.height\)[\s\S]*\.scrollBounceBehavior\(\.basedOnSize\)'; Label = 'The panel scrolls only when its content is taller than the screen (basedOnSize)' },
    @{ File = 'Sources/TicTacToeSession.swift'; Pattern = 'private\(set\) var childScore: Int[\s\S]*private\(set\) var minikScore: Int'; Label = 'Continuous child/Minik game scores remain modeled internally' },
    @{ File = 'Sources/TicTacToeSession.swift'; Pattern = 'case \.childWin:[\s\S]*childScore \+= 1[\s\S]*case \.minikWin:[\s\S]*minikScore \+= 1'; Label = 'Round outcomes continue updating hidden cumulative scores' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = '\.disabled\(session\.hasRoundStarted \|\| session\.isRoundComplete \|\| !inputIsEnabled\)'; Label = 'Mark selection locks after the first move' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'accessibilityReduceMotion'; Label = 'Reduce Motion is honored' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = '\.environment\(\\\.layoutDirection, \.leftToRight\)'; Label = 'Spatial board order remains stable in RTL interfaces' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = '\.onDisappear\(perform: cancelActivityWork\)'; Label = 'Exit/disappearance cancels feedback tasks and audio' },
    @{ File = 'Sources/TicTacToeFeedbackPlayer.swift'; Pattern = 'interfaceLocale: InterfaceLocaleID'; Label = 'Introduction and feedback use interface-language speech' },
    @{ File = 'Sources/TicTacToeFeedbackPlayer.swift'; Pattern = 'makeAudioPlayer\(named: "minik_kick"\)[\s\S]*makeAudioPlayer\(named: "minik_kick2"\)'; Label = 'Android move sounds remain wired' },
    @{ File = 'Sources/TicTacToeSession.swift'; Pattern = 'enum TicTacToeLevel[\s\S]*case a = "A"[\s\S]*case b = "B"[\s\S]*case c = "C"[\s\S]*case d = "D"[\s\S]*case e = "E"[\s\S]*case random = "RANDOM"[\s\S]*case adaptive = "ADAPTIVE"'; Label = 'A/B/C/D/E/Random/Adaptive levels remain modeled' },
    @{ File = 'Sources/TicTacToePreferences.swift'; Pattern = 'return \.adaptive'; Label = 'Adaptive remains the default level' },
    @{ File = 'Sources/TicTacToeSession.swift'; Pattern = 'levelThatUpdatesAdaptiveState: \.random'; Label = 'Android Random/Adaptive compatibility policy remains isolated' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testChildStartsWhetherCrossOrCircleWasSelected'; Label = 'Child-always-starts coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testMarkLocksAfterFirstMoveAndUnlocksNextRoundWithoutChangingSelection'; Label = 'Mark lock/reset coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testMediumPriorityWinBlockCenterCornerThenEdge'; Label = 'Medium tactical priority coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testMediumProbabilityBoundariesCanTakeOrSkipTacticalMove'; Label = 'Medium probability boundary coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testHardCannotBeForcedToLoseFromEmptyBoard'; Label = 'Hard minimax coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testNewRoundCannotReceiveAStaleAIMoveFromThePriorAtomicResolution'; Label = 'Atomic AI/new-round stale-work coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testAndroidCompatibilityUpdatesAdaptiveStateForRandomButNotAdaptive'; Label = 'Random/Adaptive compatibility coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/TicTacToeSessionTests.swift'; Pattern = 'testRoundResetPreservesCumulativeHiddenScore'; Label = 'Continuous non-mastery game score coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/ActivityCatalogTests.swift'; Pattern = 'testTicTacToeIsAJustForFunGameInBothLanguageProductsOnly'; Label = 'Language-only just-for-fun route coverage exists' },
    @{ File = 'Tests/ProductConfigurationTests/ActivityCatalogTests.swift'; Pattern = 'testMinikMathExposesPingPongOutsideMathCurriculumCatalog'; Label = 'Other product game routing remains independently covered' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageProductionParityTests.swift'; Pattern = 'testLearnCardsAndTicTacToeRemainOutsideMasteryProgress'; Label = 'No-mastery policy coverage exists' }
)

$errors = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    $path = Join-Path $repoRoot $check.File
    $source = Get-Content -LiteralPath $path -Raw -Encoding utf8
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing C13 contract: $($check.Label) [$($check.File)]")
    }
}

$viewSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/TicTacToeView.swift') -Raw -Encoding utf8
if ($viewSource -match 'onAttempt|ActivityAttemptData|recordLanguageAttempt') {
    $errors.Add('Tic-Tac-Toe must remain outside graded mastery telemetry.')
}
if ($viewSource -match 'LanguagePracticeReward|RewardEvent|\bpoints\b|\bstreak\b|leaderboard') {
    $errors.Add('Tic-Tac-Toe must not render or emit educational rewards, points, streaks, or leaderboard state.')
}
if ($viewSource -match 'Image\(systemName:') {
    $errors.Add('Tic-Tac-Toe still contains an SF-symbol visual fallback despite available original art.')
}
if ($viewSource -match 'session\.(childScore|minikScore)') {
    $errors.Add('Tic-Tac-Toe must not render the session childScore or minikScore; cumulative scores are internal-only.')
}
if ($viewSource -match 'MinikPracticeSurface|MinikPracticeScreen|progressLabel|MinikFeedbackBadge') {
    $errors.Add('Tic-Tac-Toe must not regress to generic practice card/progress/feedback chrome.')
}
if (([regex]::Matches($viewSource, 'ScrollView')).Count -ne 1) {
    $errors.Add('Tic-Tac-Toe must have exactly one ScrollView: the basedOnSize panel scroller.')
}

$provenance = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/minik-visual-asset-provenance.tsv') -Raw -Encoding utf8
if ($provenance -notmatch 'minik_tic_tac_toe_mascot\s+\.\./android/app/src/main/res/drawable/minik_plus_with_tic_tac_toe\.webp' -or
    $provenance -notmatch 'minik_tic_tac_toe_scene\s+\.\./android/app/src/main/res/drawable/plus_background\.webp') {
    $errors.Add('Tic-Tac-Toe gameplay mascot and panel scene require exact Android provenance.')
}

Write-Output "LANGUAGE_TIC_TAC_TOE_CONTRACTS_AUDITED=$($checks.Count + 7)"
Write-Output "LANGUAGE_TIC_TAC_TOE_CONTRACT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'LANGUAGE_TIC_TAC_TOE_AUDIT_OK'

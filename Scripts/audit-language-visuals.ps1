$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @(
    @{ File = 'Sources/LanguageShellViews.swift'; Pattern = 'func menuArtworkName\(for activity: LanguageActivityKind\)[\s\S]*MinikPretty\.Art\.catAbcBook'; Label = 'Language menu uses activity artwork' },
    @{ File = 'Sources/LanguageShellViews.swift'; Pattern = 'struct LanguageMenuView[\s\S]*MinikGlassPanel\('; Label = 'Language menu uses the white glass Minik panel' },
    @{ File = 'Sources/LanguageShellViews.swift'; Pattern = 'imageName: MinikVisualAsset\.home'; Label = 'Home top uses the yellow Android Home artwork' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'route = \.recordsLeaderboard[\s\S]*MinikVisualAsset\.trophy'; Label = 'Home trophy opens the distinct records leaderboard seam' },
    @{ File = 'Sources/RecordsLeaderboardView.swift'; Pattern = 'ProductionRecordsRepositoryFactory\.make[\s\S]*scoreRecords[\s\S]*streakRecords[\s\S]*Top 20 records'; Label = 'Home trophy uses the production remote score/streak records flow' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'Text\(interfaceLocaleID\.text\("Parent Area"\)\)'; Label = 'Parent Area has a distinct text settings entry' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = '\.sheet\(isPresented: parentAreaPresented\)'; Label = 'Parent Area overlays Home as a sheet' },
    @{ File = 'Sources/LanguageLearnPage.swift'; Pattern = 'card\.capitalLetterAsset[\s\S]*card\.smallLetterAsset'; Label = 'Learn separates original outlined letter forms from the word' },
    @{ File = 'Sources/LearnView.swift'; Pattern = 'presentation == \.language'; Label = 'Language Learn uses a dedicated presentation boundary' },
    @{ File = 'Sources/LanguageLearnPage.swift'; Pattern = 'LanguageSkyPanel\([\s\S]*MinikSkyBackground\(\)'; Label = 'Language Learn uses the glass panel over the sky' },
    @{ File = 'Sources/LanguageLearnPage.swift'; Pattern = '\.buttonStyle\(MinikPrettyButtonStyle\(\.yellow\)\)'; Label = 'Language Learn uses the glossy yellow action' },
    @{ File = 'Sources/LanguageLearnPage.swift'; Pattern = 'Image\(systemName: "play\.fill"\)'; Label = 'Language Learn uses the owner-required triangular replay control' },
    @{ File = 'Sources/PairsView.swift'; Pattern = 'session\.selectionStyle == \.anyTwoTiles'; Label = 'Letter Pairs preserves any-two layout' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'MinikVisualAsset\.memoryMascot'; Label = 'Picture Memory uses Minik identity' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'case \.faceDown:[\s\S]*Color\.clear'; Label = 'Picture Memory face-down cards are blank' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'case firstLetterPictureToLetter'; Label = 'First Letter picture-to-letter has an explicit presentation contract' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'speechCue\.text'; Label = 'First Letter picture prompt exposes learned-word accessibility' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'case firstLetterLetterToPicture'; Label = 'First Letter letter-to-picture has an explicit presentation contract' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'choiceAccessibilityLabel'; Label = 'First Letter picture choices expose learned-word accessibility' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'case pictureToWord'; Label = 'Picture-to-Word has an explicit presentation contract' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'case wordToPicture'; Label = 'Word-to-Picture has an explicit presentation contract' },
    @{ File = 'Sources/BuildView.swift'; Pattern = 'case word'; Label = 'Build Word has an explicit presentation contract' },
    @{ File = 'Sources/BuildView.swift'; Pattern = 'languageAttemptTracker\.makeAttempt'; Label = 'Build Word records typed ordered-token attempts' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'MinikVisualAsset\.cardsBackground'; Label = 'Word Cards uses the original sky/meadow background' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'MinikVisualAsset\.cardsMascot'; Label = 'Word Cards uses the Android mascot art' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'LanguagePanelNavigation\(wide: wide, showsLogo: true'; Label = 'Word Cards uses original Minik branding' },
    @{ File = 'Sources/LanguageActivityVisuals.swift'; Pattern = 'MinikVisualAsset\.close'; Label = 'Word Cards uses the branded close control' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'onReplay: nil, onExit: exit[\s\S]*\.accessibilityAction\(named: "Replay current word"\)\s*\{\s*replayCurrentCard\(\)\s*\}'; Label = 'Word Cards shows no replay control, as Android; VoiceOver keeps a replay action' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'ball\.orderedTokenDisplayText'; Label = 'Soccer explicitly renders ordered-token text' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'MinikVisualAsset\.soccerGoalie'; Label = 'Soccer uses original goalkeeper' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'MinikVisualAsset\.soccerField'; Label = 'Soccer uses original field' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'accessibilityLabel\(ballAccessibilityLabel'; Label = 'Soccer balls have explicit accessibility labels' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'Circle\(\)\.fill\(letterColor\(for: ball\)\)[\s\S]*Self\.letterPalette\[index % Self\.letterPalette\.count\]'; Label = 'Language Soccer uses colored ordered-token controls' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'introductionRepository\.registerPresentationIfNeeded'; Label = 'Language Soccer evaluates its persisted introduction' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'func introductionBottomRow[\s\S]*\.buttonStyle\(MinikPrettyButtonStyle\(\.yellow\)\)'; Label = 'Language Soccer introduction uses the glossy yellow Start action' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'MinikVisualAsset\.success'; Label = 'Shared success feedback uses Minik reaction' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'MinikVisualAsset\.tryAgain'; Label = 'Shared failure feedback uses Minik reaction' },
    @{ File = 'Sources/ParentAreaView.swift'; Pattern = 'MinikHomeSectionCard\(compact:'; Label = 'Parent Area uses one Minik modal panel' },
    @{ File = 'Sources/ParentAreaView.swift'; Pattern = 'MinikVisualAsset\.close'; Label = 'Parent Area uses the product close artwork' },
    @{ File = 'Sources/ParentAreaView.swift'; Pattern = 'ParentAreaActionButtonStyle'; Label = 'Parent Area uses Android-like blue progress actions' }
)

$errors = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    $path = Join-Path $repoRoot $check.File
    $source = Get-Content -LiteralPath $path -Raw
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing visual contract: $($check.Label) [$($check.File)]")
    }
}

$soccerSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/LanguageSoccerView.swift') -Raw
if ($soccerSource -match 'Image\(systemName:\s*"soccerball"\)') {
    $errors.Add('Soccer still substitutes an SF soccer ball for the product artwork.')
}

$memorySource = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/MemoryView.swift') -Raw
if ($memorySource -match 'case \.faceDown:[\s\S]{0,500}MinikVisualAsset\.activityArtwork') {
    $errors.Add('Picture Memory still stamps activity artwork on face-down cards.')
}

Write-Output "LANGUAGE_VISUAL_CONTRACTS_AUDITED=$($checks.Count + 1)"
Write-Output "LANGUAGE_VISUAL_CONTRACT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}
# Guard the shared choice-style API as well as visual asset/presentation tokens.
& (Join-Path $PSScriptRoot 'audit-minik-practice-visuals.ps1')
Write-Output 'LANGUAGE_VISUAL_AUDIT_OK'

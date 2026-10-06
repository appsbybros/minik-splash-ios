$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$allPath = Join-Path $repoRoot 'Resources/Localization/All/Localizable.xcstrings'
$englishOnlyPath = Join-Path $repoRoot 'Resources/Localization/EnglishOnly/Localizable.xcstrings'
$all = Get-Content -LiteralPath $allPath -Raw -Encoding utf8 | ConvertFrom-Json
$englishOnly = Get-Content -LiteralPath $englishOnlyPath -Raw -Encoding utf8 | ConvertFrom-Json
$allKeys = @($all.strings.PSObject.Properties.Name | Sort-Object)
$englishOnlyKeys = @($englishOnly.strings.PSObject.Properties.Name | Sort-Object)
$expectedLocales = @('am', 'ar', 'de', 'en', 'es', 'fr', 'nl', 'pt-BR', 'pt-PT', 'ru')
$minimumKeyCount = 469

if ($allKeys.Count -lt $minimumKeyCount) {
    $errors.Add("All catalog has $($allKeys.Count) keys; expected at least $minimumKeyCount.")
}
if ($englishOnlyKeys.Count -ne $allKeys.Count -or
    (($englishOnlyKeys -join "`n") -ne ($allKeys -join "`n"))) {
    $errors.Add('English Only catalog keys do not exactly match the All catalog.')
}

foreach ($key in $englishOnlyKeys) {
    $entry = $englishOnly.strings.PSObject.Properties[$key].Value
    $locales = @($entry.localizations.PSObject.Properties.Name | Sort-Object)
    if (($locales -join '|') -ne (($expectedLocales | Sort-Object) -join '|')) {
        $errors.Add("Wrong English Only locale set for key: $key")
    }
    if ($null -ne $entry.localizations.PSObject.Properties['he']) {
        $errors.Add("Hebrew localization state leaked into English Only key: $key")
    }
}

$checks = @(
    @{ File = 'project.yml'; Pattern = 'MinikPlusEnglish:[\s\S]*Resources/Localization/EnglishOnly/Localizable\.xcstrings[\s\S]*CFBundleLocalizations: \[en, am, ar, de, es, fr, nl, pt-BR, pt-PT, ru\]'; Label = 'English Only target packages exactly the 10-locale catalog policy' },
    @{ File = 'Sources/ProductConfiguration.swift'; Pattern = 'case \.minikPlusEnglish:[\s\S]*allowedLearnedLanguages: \[\.english\][\s\S]*fixedLearnedLanguage: \.english'; Label = 'No Hebrew learned-language state is permitted' },
    @{ File = 'Sources/RootView.swift'; Pattern = 'return interfaceLocaleController\.selectedLocale[\s\S]*?\.environment\(\\\.locale, effectiveInterfaceLocale\.locale\)|\.environment\(\\\.locale, effectiveInterfaceLocale\.locale\)[\s\S]*?return interfaceLocaleController\.selectedLocale'; Label = 'Arabic and other interface locales drive the SwiftUI interface environment' },
    @{ File = 'Sources/RepresentationView.swift'; Pattern = 'case \.learningText\(let text\):[\s\S]*learningText\(text\)[\s\S]*\.environment\(\\\.layoutDirection, direction\.layoutDirection\)'; Label = 'Typed learned text owns its direction independently of interface RTL' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageProductionParityTests.swift'; Pattern = 'testEnglishOnlySpeechBearingProductionSessionsUseEnglishLearnedSpeech[\s\S]*direction == \.leftToRight'; Label = 'English learned content and LTR metadata have deterministic coverage' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'MinikVisualAsset\.activityArtwork\([\s\S]*language: selectedLanguage'; Label = 'Home uses learned-language-specific production artwork' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageProductionParityTests.swift'; Pattern = 'testEnglishOnlyProductionArtworkNeverSelectsHebrewVariants'; Label = 'English Only artwork rejects Hebrew-specific variants' },
    @{ File = 'Sources/ParentAreaView.swift'; Pattern = 'if configuration\.isLearningLanguageSelectionAvailable[\s\S]*\} else \{[\s\S]*LabeledContent\("Learned language", value: selectedLanguage\.hubTitle\)'; Label = 'Parent Area presents fixed English coherently' },
    @{ File = 'Sources/CardsView.swift'; Pattern = 'MinikVisualAsset\.cardsBackground[\s\S]*MinikVisualAsset\.cardsMascot'; Label = 'Word Cards keeps the branded composition' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'MinikVisualAsset\.soccerField[\s\S]*MinikVisualAsset\.soccerGoal[\s\S]*MinikVisualAsset\.soccerGoalie'; Label = 'Soccer keeps original production scene art' },
    @{ File = 'Sources/LanguageSoccerView.swift'; Pattern = 'interfaceLocaleID\.text\("Drag letters upward in the correct order'; Label = 'Soccer introduction uses the interface catalog without changing learned tokens' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'MinikVisualAsset\.towerSand[\s\S]*MinikVisualAsset\.towerMascot[\s\S]*MinikVisualAsset\.towerSandPile'; Label = 'Tower keeps the completed branded lower composition' },
    @{ File = 'Sources/MemoryView.swift'; Pattern = 'MinikVisualAsset\.memoryMascot[\s\S]*case \.faceDown:[\s\S]*Color\.clear'; Label = 'Picture Memory keeps branded placement and blank face-down content' },
    @{ File = 'Sources/MinikPracticeVisuals.swift'; Pattern = 'struct MinikMemoryCardStyle:[\s\S]*case \.faceDown:[\s\S]*LinearGradient'; Label = 'Picture Memory keeps its branded gradient card-back style' },
    @{ File = 'Sources/TicTacToeView.swift'; Pattern = 'MinikVisualAsset\.ticTacToeMascot'; Label = 'Tic-Tac-Toe keeps original mascot composition' },
    @{ File = 'Scripts/audit-language-tic-tac-toe.ps1'; Pattern = 'must not render the session childScore or minikScore'; Label = 'Tic-Tac-Toe remains free of a visible score in English Only' }
)

foreach ($check in $checks) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $check.File) -Raw -Encoding utf8
    if ($source -notmatch $check.Pattern) {
        $errors.Add("Missing $($check.Label) [$($check.File)]")
    }
}

Write-Output "ENGLISH_ONLY_CATALOG_KEYS=$($englishOnlyKeys.Count)"
Write-Output "ENGLISH_ONLY_CATALOG_LOCALES=$($expectedLocales.Count)"
Write-Output "ENGLISH_ONLY_SURFACES_AUDITED=$($checks.Count)"
Write-Output "ENGLISH_ONLY_PARITY_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | Select-Object -First 20 | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'ENGLISH_ONLY_PRODUCT_PARITY_OK'

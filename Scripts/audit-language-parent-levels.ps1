[CmdletBinding()]
param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

$checks = @(
    @{ File = 'Sources/ParentAreaView.swift'; Pattern = 'Button \{\s*showsLanguageLevels = true[\s\S]*Text\("Levels"\)'; Label = 'Parent Levels action opens its destination' },
    @{ File = 'Sources/ParentAreaView.swift'; Pattern = 'LanguageParentLevelsView\([\s\S]*settings: Binding\([\s\S]*get: \{ languageLevelSettings \}[\s\S]*set: onSetLanguageLevels'; Label = 'Parent destination receives live persisted settings' },
    @{ File = 'Sources/LanguageParentLevelsView.swift'; Pattern = 'LanguageVocabularyLevel\.allCases'; Label = 'Word levels use the typed A-E order' },
    @{ File = 'Sources/LanguageParentLevelsView.swift'; Pattern = 'LanguageSoccerLevel\.allCases'; Label = 'Soccer levels use the typed A-C order' },
    @{ File = 'Sources/LanguageParentLevelsView.swift'; Pattern = 'TicTacToeLevel\.allCases'; Label = 'Tic-Tac-Toe uses the existing typed A-E/Random/Adaptive order' },
    @{ File = 'Sources/EducationalParentSettings.swift'; Pattern = 'static let androidDefault = LanguageParentLevelSettings\([\s\S]*mode: \.automatic[\s\S]*wordLevel: \.a[\s\S]*soccerLevel: \.a[\s\S]*ticTacToeLevel: \.adaptive'; Label = 'Defaults match Android production' },
    @{ File = 'Sources/EducationalParentSettings.swift'; Pattern = 'minik\.language-levels\.v1[\s\S]*product\.rawValue'; Label = 'Settings persist per product' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'vocabularyLevel: languageLevelSettings\.wordLevel'; Label = 'Production factory consumes the selected word level' },
    @{ File = 'Sources/LanguageActivitySessionFactory.swift'; Pattern = 'private var vocabularyStage[\s\S]*vocabularyLevel\.curriculumStageID'; Label = 'Typed level maps to its vocabulary curriculum stage' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'recordLanguagePoolBoundary[\s\S]*var updatedSettings = languageLevelSettings[\s\S]*settings: &updatedSettings[\s\S]*languageLevelSettings = updatedSettings'; Label = 'Automatic pools update the same live Parent settings' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'mode == \.automatic[\s\S]*newPassCount >= 2[\s\S]*settings\.wordLevel = level'; Label = 'Auto has a real Android-derived production effect' },
    @{ File = 'Tests/ProductConfigurationTests/ParentAreaPolicyTests.swift'; Pattern = 'testSelectedWordLevelDrivesProductionVocabularyStageForBothLearnedLanguages'; Label = 'Production effect has deterministic test coverage' },
    @{ File = 'Tests/ProductConfigurationTests/ParentAreaPolicyTests.swift'; Pattern = 'testEnglishOnlyUsesItsSelectedVocabularyLevelWithoutChangingFixedEnglishPolicy'; Label = 'English Only boundary has deterministic coverage' }
)

function Test-Contracts([hashtable[]]$Contracts, [hashtable]$Sources) {
    $contractErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($check in $Contracts) {
        if (-not $Sources[$check.File] -or $Sources[$check.File] -notmatch $check.Pattern) {
            $contractErrors.Add("Missing Language Parent Levels contract: $($check.Label) [$($check.File)]")
        }
    }
    return $contractErrors
}

$sources = @{}
foreach ($file in $checks.File | Sort-Object -Unique) {
    $sources[$file] = Get-Content -LiteralPath (Join-Path $repoRoot $file) -Raw -Encoding utf8
}
foreach ($contractError in @(Test-Contracts $checks $sources)) {
    $errors.Add($contractError)
}

$menuSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/LanguageShellViews.swift') -Raw -Encoding utf8
if ($menuSource -match 'Text\("Levels"\)|onLevels|languageLevels') {
    $errors.Add('Language Levels leaked into the child-facing Home/Menu source.')
}

if ($SelfTest) {
    $mutated = @{}
    foreach ($entry in $sources.GetEnumerator()) { $mutated[$entry.Key] = $entry.Value }
    $mutated['Sources/MinikActivityHubView.swift'] = $mutated['Sources/MinikActivityHubView.swift'].Replace(
        'vocabularyLevel: languageLevelSettings.wordLevel',
        'vocabularyLevel: .a'
    )
    if ((Test-Contracts $checks $mutated).Count -eq 0) {
        $errors.Add('Negative fixture failed: disconnected production vocabulary level was accepted.')
    } else {
        Write-Output 'LANGUAGE_PARENT_LEVELS_NEGATIVE_FIXTURES_REJECTED=1'
    }
}

Write-Output "LANGUAGE_PARENT_LEVELS_CONTRACTS_AUDITED=$($checks.Count)"
Write-Output "LANGUAGE_PARENT_LEVELS_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'LANGUAGE_PARENT_LEVELS_AUDIT_OK'

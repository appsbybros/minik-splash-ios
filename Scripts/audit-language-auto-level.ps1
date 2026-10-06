[CmdletBinding()]
param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = [Collections.Generic.List[string]]::new()

$checks = @(
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'case write[\s\S]*case tower[\s\S]*case soccer'; Label = 'Only Android Write, Tower and Soccer own Auto gates' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'attemptActivity\(for family: ActivityFamily\)[\s\S]*case \.tower:[\s\S]*return \.tower[\s\S]*case \.soccer:[\s\S]*return \.soccer[\s\S]*default:[\s\S]*return nil'; Label = 'Attempt routing excludes every non-Tower/Soccer family' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'completionActivity\(for activity: LanguageActivityKind\)[\s\S]*activity == \.wordBuild \? \.write : nil'; Label = 'Completion routing excludes Mixed Build from Write evidence' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'case \.write: return 100[\s\S]*case \.tower, \.soccer: return 600'; Label = 'Android attempt thresholds are exact' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'case \.write: return 90[\s\S]*case \.tower, \.soccer: return 80'; Label = 'Android accuracy thresholds are exact' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'contentItemID[\s\S]*vocabularyLevel[\s\S]*activity[\s\S]*correctCount[\s\S]*wrongCount'; Label = 'Typed per-content evidence is retained' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'private\(set\) var evidence: \[LanguageAutoContentEvidence\]'; Label = 'Auto state stores typed content evidence rather than aggregates' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'newPassCount >= 2'; Label = 'Promotion requires two consecutive passing pools' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'boundary\.evaluatedLevel == currentLevel'; Label = 'Stale level pools are rejected' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'let nextLevel = currentLevel\.next'; Label = 'Level E cannot overflow' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'ramp = 90[\s\S]*applicationDidStop\(\)[\s\S]*max\(0, ramp - 10\)'; Label = 'Ramp promotion and lifecycle decay are exact' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'private struct Envelope: Codable \{[\s\S]*let state: LanguageAutoProgressionState[\s\S]*language-auto-progress\.v1'; Label = 'Evidence, pass, level and ramp state persist together' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'Double\(previous\.count\)[\s\S]*Double\(boundedRamp\)[\s\S]*Double\(current\.count\)[\s\S]*Double\(100 - boundedRamp\)'; Label = 'Android rounded list-count mixing is preserved' },
    @{ File = 'Sources/LanguageActivitySessionFactory.swift'; Pattern = 'LanguageVocabularyPoolMixer\.mix\([\s\S]*previous: previous,[\s\S]*current: current,[\s\S]*ramp: vocabularyRamp'; Label = 'Production factories consume the persisted ramp' },
    @{ File = 'Sources/BuildView.swift'; Pattern = 'LanguageAutoPoolTracker[\s\S]*takeBoundary\(isExhausted: true\)[\s\S]*activity: \.write'; Label = 'Build Word emits only a complete-pool boundary' },
    @{ File = 'Sources/LanguageTowerPracticeSession.swift'; Pattern = 'lastAdvanceBoundary[\s\S]*remainingRounds\.isEmpty[\s\S]*takeBoundary\(isExhausted: true\)'; Label = 'Tower emits only a complete-pool boundary' },
    @{ File = 'Sources/LanguageSoccerPracticeSession.swift'; Pattern = 'lastAdvanceBoundary[\s\S]*remainingRounds\.isEmpty[\s\S]*takeBoundary\(isExhausted: true\)'; Label = 'Soccer reuses its complete-pool boundary' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'recordLanguagePoolBoundary[\s\S]*var updatedSettings = languageLevelSettings[\s\S]*settings: &updatedSettings[\s\S]*languageLevelSettings = updatedSettings[\s\S]*languageLevelRepository\.save\(updatedSettings'; Label = 'Promotion writes the shared Parent word level' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'newPhase == \.background[\s\S]*applicationDidStop\(\)[\s\S]*languageAutoRepository\.save'; Label = 'Android MainActivity stop maps to app background persistence' },
    @{ File = 'Sources/MinikActivityHubView.swift'; Pattern = 'LanguageAutoEvidenceRouting\.attemptActivity[\s\S]*LanguageAutoEvidenceRouting\.completionActivity'; Label = 'Production evidence uses the typed eligibility boundary' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageAutoLevelProgressionTests.swift'; Pattern = 'test01AndroidDefaults[\s\S]*test32LanguageProgressionDoesNotMutateMathState'; Label = 'All required deterministic behaviors are covered' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageAutoLevelProgressionTests.swift'; Pattern = 'testAutoEvidenceRoutingIncludesOnlyWriteTowerAndSoccer[\s\S]*completionActivity\(for: \.mixed\)'; Label = 'Mixed exclusion and eligible routing have deterministic coverage' }
)

function Read-Sources([hashtable[]]$Contracts) {
    $values = @{}
    foreach ($file in $Contracts.File | Sort-Object -Unique) {
        $values[$file] = Get-Content -LiteralPath (Join-Path $repoRoot $file) -Raw -Encoding utf8
    }
    return $values
}

function Test-Contracts([hashtable[]]$Contracts, [hashtable]$Sources) {
    $found = [Collections.Generic.List[string]]::new()
    foreach ($check in $Contracts) {
        if ($Sources[$check.File] -notmatch $check.Pattern) {
            $found.Add("Missing Language Auto contract: $($check.Label) [$($check.File)]")
        }
    }
    return $found
}

$sources = Read-Sources $checks
foreach ($contractError in @(Test-Contracts $checks $sources)) { $errors.Add($contractError) }

if ($SelfTest) {
    $fixtures = @(
        @{ Name = 'aggregate-only'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'private(set) var evidence: [LanguageAutoContentEvidence]'; New = 'private(set) var evidence: [ActivityProgressSummary]' },
        @{ Name = 'one-pass'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'newPassCount >= 2'; New = 'newPassCount >= 1' },
        @{ Name = 'stale-pool'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'boundary.evaluatedLevel == currentLevel'; New = 'boundary.evaluatedLevel != currentLevel' },
        @{ Name = 'E-overflow'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'let nextLevel = currentLevel.next'; New = 'let nextLevel = LanguageVocabularyLevel.a' },
        @{ Name = 'missing-ramp-persistence'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'state: LanguageAutoProgressionState'; New = 'state: ProgressSnapshot' },
        @{ Name = 'disconnected-factory'; File = 'Sources/LanguageActivitySessionFactory.swift'; Old = 'ramp: vocabularyRamp'; New = 'ramp: 0' },
        @{ Name = 'mixed-feeds-write'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'activity == .wordBuild ? .write : nil'; New = '.write' }
    )
    $rejected = 0
    foreach ($fixture in $fixtures) {
        $mutated = @{}
        foreach ($entry in $sources.GetEnumerator()) { $mutated[$entry.Key] = $entry.Value }
        $mutated[$fixture.File] = $mutated[$fixture.File].Replace($fixture.Old, $fixture.New)
        if ((Test-Contracts $checks $mutated).Count -eq 0) {
            $errors.Add("Negative fixture was accepted: $($fixture.Name)")
        } else {
            $rejected++
        }
    }
    Write-Output "LANGUAGE_AUTO_NEGATIVE_FIXTURES_REJECTED=$rejected"
}

Write-Output "LANGUAGE_AUTO_CONTRACTS_AUDITED=$($checks.Count)"
Write-Output "LANGUAGE_AUTO_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Output 'LANGUAGE_AUTO_LEVEL_AUDIT_OK'

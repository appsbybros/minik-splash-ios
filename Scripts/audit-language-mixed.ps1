[CmdletBinding()]
param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$checks = @(
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'case \.wordToPicture:\s*20'; Label = 'Word-to-Picture advances after 20 real challenges' },
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'case \.pictureToWord:\s*10'; Label = 'Picture-to-Word advances after 10 real challenges' },
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'case \.wordBuild:\s*5'; Label = 'Word Build advances after 5 real challenges' },
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'enabledModes: Set\(LanguageMixedPracticeMode\.allCases\)'; Label = 'Current capable content enables all three modes' },
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'event == \.advancedCurrentWord'; Label = 'Only real child advances increment the schedule' },
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'progression = previousProgression'; Label = 'Failed child replacement rolls schedule state back' },
    @{ File = 'Sources/LanguageMixedPractice.swift'; Pattern = 'fromChildWithID childID: UUID[\s\S]*currentChildActivity\.id == childID'; Label = 'Schedule advancement rejects stale child identities' },
    @{ File = 'Sources/LanguageMixedPracticeView.swift'; Pattern = 'presentation: choicePresentation\(for: childActivity\.mode\)'; Label = 'Choice children select activity-specific presentation' },
    @{ File = 'Sources/LanguageMixedPracticeView.swift'; Pattern = 'return \.wordToPicture'; Label = 'Word-to-Picture uses its typed presentation' },
    @{ File = 'Sources/LanguageMixedPracticeView.swift'; Pattern = 'return \.pictureToWord'; Label = 'Picture-to-Word uses its typed presentation' },
    @{ File = 'Sources/LanguageMixedPracticeView.swift'; Pattern = 'presentation: \.word'; Label = 'Mixed Word Build uses the word presentation' },
    @{ File = 'Sources/LanguageMixedPracticeView.swift'; Pattern = 'progressActivityFamily: \.mixed'; Label = 'Mixed children emit Mixed progress attempts' },
    @{ File = 'Sources/LanguageMixedPracticeView.swift'; Pattern = 'guard let mixed = ActivityAttemptData\([\s\S]{0,500}activityFamily: \.mixed'; Label = 'Child attempts are normalized to Mixed' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = 'usesExpectedSemanticIdentity: presentation\.usesExpectedSemanticProgressIdentity'; Label = 'Choice telemetry uses semantic vocabulary identity' },
    @{ File = 'Sources/BuildView.swift'; Pattern = 'activityFamily: family'; Label = 'Word Build forwards the Mixed attempt family' },
    @{ File = 'Sources/BuildView.swift'; Pattern = '@Environment\(\\\.scenePhase\)'; Label = 'Word Build stops speech on background' },
    @{ File = 'Sources/MultipleChoiceView.swift'; Pattern = '@Environment\(\\\.scenePhase\)'; Label = 'Choice modes stop speech on background' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageMixedPracticeTests.swift'; Pattern = 'testFailedModeTransitionDoesNotAdvanceOrDuplicateProgress'; Label = 'No-duplicate rollback test exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageMixedPracticeTests.swift'; Pattern = 'testCurrentPolicyCyclesAtTwentyTenAndFiveAdvancesForTwoCompleteCycles'; Label = 'Two complete schedule cycles are tested' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageMixedPracticeTests.swift'; Pattern = 'testStaleChildCallbacksCannotAdvanceOrReplaceCurrentChild'; Label = 'Stale child callbacks have deterministic behavior coverage' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageMixedPracticeTests.swift'; Pattern = 'testMixedChoiceTelemetryUsesStableVocabularyIdentityAndLearnedSpeech'; Label = 'Choice identity and speech test exists' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageMixedPracticeTests.swift'; Pattern = 'testMixedWordBuildTelemetryIsPerTokenAndContainsNoMathFields'; Label = 'Mixed per-token telemetry test exists' },
    @{ File = 'Sources/LanguageAutoLevelProgression.swift'; Pattern = 'completionActivity\(for activity: LanguageActivityKind\)[\s\S]*activity == \.wordBuild \? \.write : nil'; Label = 'Only standalone Build completion maps to Write Auto evidence' },
    @{ File = 'Tests/ProductConfigurationTests/LanguageAutoLevelProgressionTests.swift'; Pattern = 'testAutoEvidenceRoutingIncludesOnlyWriteTowerAndSoccer[\s\S]*completionActivity\(for: \.mixed\)'; Label = 'Mixed Build Auto exclusion has deterministic behavior coverage' }
)

$errors = [System.Collections.Generic.List[string]]::new()
function Read-Sources([hashtable[]]$Contracts) {
    $values = @{}
    foreach ($file in $Contracts.File | Sort-Object -Unique) {
        $values[$file] = Get-Content -LiteralPath (Join-Path $repoRoot $file) -Raw -Encoding utf8
    }
    return $values
}

function Test-Contracts([hashtable[]]$Contracts, [hashtable]$Sources) {
    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($check in $Contracts) {
        if ($Sources[$check.File] -notmatch $check.Pattern) {
            $found.Add("Missing C8 contract: $($check.Label) [$($check.File)]")
        }
    }
    return $found
}

$sources = Read-Sources $checks
foreach ($contractError in @(Test-Contracts $checks $sources)) { $errors.Add($contractError) }

$viewSource = $sources['Sources/LanguageMixedPracticeView.swift']
$mixedProgressRoutes = [regex]::Matches($viewSource, 'progressActivityFamily: \.mixed').Count
if ($mixedProgressRoutes -ne 2) {
    $errors.Add("Expected exactly two Mixed child progress routes; found $mixedProgressRoutes.")
}
if ($viewSource -match 'mathLevelID:') {
    $errors.Add('Language Mixed must not add Math level fields.')
}

if ($SelfTest) {
    $fixtures = @(
        @{ Name = 'wrong-first-threshold'; File = 'Sources/LanguageMixedPractice.swift'; Old = 'case .wordToPicture:'; New = 'case .wordToPictureBroken:' },
        @{ Name = 'missing-stale-child-guard'; File = 'Sources/LanguageMixedPractice.swift'; Old = 'currentChildActivity.id == childID'; New = 'currentChildActivity.id != childID' },
        @{ Name = 'generic-choice-presentation'; File = 'Sources/LanguageMixedPracticeView.swift'; Old = 'presentation: choicePresentation(for: childActivity.mode)'; New = 'presentation: .standard' },
        @{ Name = 'math-family-leak'; File = 'Sources/LanguageMixedPracticeView.swift'; Old = 'activityFamily: .mixed'; New = 'activityFamily: .buildMath' },
        @{ Name = 'mixed-feeds-write-auto'; File = 'Sources/LanguageAutoLevelProgression.swift'; Old = 'activity == .wordBuild ? .write : nil'; New = '.write' }
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
    Write-Output "LANGUAGE_MIXED_NEGATIVE_FIXTURES_REJECTED=$rejected"
}

Write-Output "LANGUAGE_MIXED_CONTRACTS_AUDITED=$($checks.Count + 2)"
Write-Output "LANGUAGE_MIXED_CONTRACT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'LANGUAGE_MIXED_AUDIT_OK'

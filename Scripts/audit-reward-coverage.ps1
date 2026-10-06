param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Read-Source([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $errors.Add("Missing $RelativePath")
        return ''
    }
    return Get-Content -Raw -LiteralPath $path
}

function Require-Pattern(
    [string]$Content,
    [string]$Pattern,
    [string]$Message
) {
    if ($Content -notmatch $Pattern) {
        $errors.Add($Message)
    }
}

$hub = Read-Source 'Sources/MinikActivityHubView.swift'
$mappers = Read-Source 'Sources/LanguageGameRewardMappers.swift'
$rewards = Read-Source 'Sources/Rewards.swift'
$remote = Read-Source 'Sources/RemoteRecords.swift'
$memory = Read-Source 'Sources/MemoryView.swift'
$soccer = Read-Source 'Sources/LanguageSoccerView.swift'
$ticTacToe = Read-Source 'Sources/TicTacToeView.swift'
$tests = Read-Source 'Tests/ProductConfigurationTests/RewardCoverageTests.swift'

Require-Pattern $rewards 'androidPictureMemoryReference[\s\S]*pointsDelta: 2[\s\S]*streakEffect: \.unchanged' 'Picture Memory must retain Android fixed +2 with no streak mutation.'
Require-Pattern $rewards 'androidSoccerReference[\s\S]*\.matchWon: RewardRule\(pointsDelta: 3[\s\S]*\.matchDrawn: RewardRule\(pointsDelta: 1' 'Soccer must retain Android +3 win / +1 draw policy.'
Require-Pattern $rewards 'androidTicTacToeReference[\s\S]*\.matchWon: RewardRule\(pointsDelta: 2[\s\S]*\.matchDrawn: RewardRule\(pointsDelta: 1[\s\S]*\.matchLost: RewardRule\(pointsDelta: -1' 'Tic-Tac-Toe must retain Android +2 / +1 / -1 policy.'

Require-Pattern $hub 'LanguageLetterPairsRewardMapper[\s\S]*androidLetterPairsReference' 'Letter Pairs production reward mapping is missing.'
Require-Pattern $hub 'LanguageTowerRewardMapper[\s\S]*androidTowerReference' 'Tower production reward mapping is missing.'
Require-Pattern $hub 'LanguagePictureMemoryRewardMapper[\s\S]*androidPictureMemoryReference' 'Picture Memory production reward mapping is missing.'
Require-Pattern $hub 'onLanguageGameCompleted: \{ eventID in[\s\S]*recordLanguagePictureMemoryCompletion\(eventID: eventID\)[\s\S]*onRoundCompleted:[\s\S]*recordLanguageAdOpportunity\(\.languagePictureMemory\)' 'Picture Memory completion does not reach rewards and ads independently.'
Require-Pattern $hub 'onMatchResolved: recordLanguageSoccerCompletion[\s\S]*onWordCompleted:[\s\S]*recordLanguageAdOpportunity\(\.languageSoccer\)' 'Soccer match completion does not reach rewards and ads independently.'
Require-Pattern $hub 'onResolvedRound: recordLanguageTicTacToeCompletion[\s\S]*onCompletedRound:[\s\S]*recordLanguageAdOpportunity\(\.languageTicTacToe\)' 'Tic-Tac-Toe completion does not reach rewards and ads independently.'
Require-Pattern $hub 'submitLanguageRewardRecordCandidate\(\)[\s\S]*rewardRecordSubmissionService\.submit' 'Completed local Language reward state is not submitted through the remote-record boundary.'

Require-Pattern $mappers 'case \.minikWin:[\s\S]*return nil' 'Soccer loss must preserve Android no-point-change behavior.'
Require-Pattern $mappers 'product == \.minikPlus \|\| product == \.minikPlusEnglish' 'New reward mappers are not isolated to Language products.'
Require-Pattern $memory 'recordLanguageGameCompletionIfNeeded\([\s\S]*presentationID: transition\.presentationID' 'Picture Memory does not emit an idempotent presentation-scoped completion.'
Require-Pattern $soccer 'onMatchResolved\(completedMatchOutcome\)' 'Soccer does not emit its typed final match outcome.'
Require-Pattern $ticTacToe 'onResolvedRound\(outcome\)' 'Tic-Tac-Toe does not emit its typed final match outcome.'

Require-Pattern $remote 'actor RewardRecordSubmissionService[\s\S]*state\.points > 0 \|\| state\.bestStreak > 0[\s\S]*RewardRecordCandidate\(' 'Remote record submission must forward only eligible aggregate reward state.'
Require-Pattern $tests 'testProductionLanguageRewardCoverageMatchesAndroidObservedActivities' 'The complete production Language route inventory is not tested.'
Require-Pattern $tests 'testNewLanguageRewardMappersRejectMathAndPingPong' 'Math and Ping Pong reward isolation is not tested.'
Require-Pattern $tests 'testRecordSubmissionForwardsExactAggregateRewardState' 'Remote reward-candidate submission is not tested.'

Write-Output 'PRODUCTION_LANGUAGE_REWARD_ROUTES_AUDITED=13'
Write-Output 'MATH_REWARD_POLICY=DEFERRED_NO_APPROVED_VALUES'
Write-Output 'PING_PONG_REWARD_POLICY=NOT_PRESENT_IN_ANDROID_CONTRACT'
Write-Output "REWARD_COVERAGE_AUDIT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'REWARD_COVERAGE_AUDIT_OK'

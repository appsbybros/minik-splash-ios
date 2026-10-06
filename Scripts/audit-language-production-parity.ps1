$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$recordPath = Join-Path $repoRoot 'docs/language-production-parity-lock.tsv'
$provenancePath = Join-Path $repoRoot 'docs/minik-visual-asset-provenance.tsv'
$errors = [System.Collections.Generic.List[string]]::new()

$requiredColumns = @(
    'activity_id', 'android_behavior_source', 'android_visual_reference',
    'menu_artwork', 'menu_provenance', 'menu_section', 'session_type',
    'learned_language_speech', 'interface_speech', 'progress_reward_policy',
    'retry_policy', 'lifecycle', 'accessibility', 'rtl_ltr', 'runtime_gate'
)
$expectedRows = [ordered]@{
    learn = @{ Section = 'letters'; Artwork = 'minik_activity_learn_english|minik_activity_learn_hebrew' }
    letterPairs = @{ Section = 'letters'; Artwork = 'minik_activity_pairs' }
    firstLetterChoices = @{ Section = 'letters'; Artwork = 'minik_activity_first_letter_english|minik_activity_first_letter_hebrew' }
    firstLetterPictures = @{ Section = 'letters'; Artwork = 'minik_activity_first_letter_english|minik_activity_first_letter_hebrew' }
    mixed = @{ Section = 'words'; Artwork = 'minik_activity_mixed' }
    wordBuild = @{ Section = 'words'; Artwork = 'minik_activity_build|minik_activity_build_hebrew' }
    imageToWord = @{ Section = 'words'; Artwork = 'minik_activity_picture_to_word' }
    wordToImage = @{ Section = 'words'; Artwork = 'minik_activity_word_to_picture' }
    wordCards = @{ Section = 'words'; Artwork = 'minik_activity_cards|minik_activity_cards_hebrew' }
    soccer = @{ Section = 'games'; Artwork = 'minik_activity_soccer' }
    tower = @{ Section = 'games'; Artwork = 'minik_activity_tower' }
    wordMemory = @{ Section = 'games'; Artwork = 'minik_activity_memory' }
    ticTacToe = @{ Section = 'games'; Artwork = 'minik_activity_tic_tac_toe' }
}

if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
    Write-Error "Missing C14 record: $recordPath"
    exit 1
}
$rows = @(Import-Csv -LiteralPath $recordPath -Delimiter "`t")
$provenance = @(Import-Csv -LiteralPath $provenancePath -Delimiter "`t")
$actualColumns = @($rows[0].PSObject.Properties.Name)
foreach ($column in $requiredColumns) {
    if ($column -notin $actualColumns) {
        $errors.Add("Missing C14 record column: $column")
    }
}

if ($rows.Count -ne 13) {
    $errors.Add("Expected 13 production records; found $($rows.Count).")
}
$duplicates = @($rows | Group-Object activity_id | Where-Object Count -ne 1)
foreach ($duplicate in $duplicates) {
    $errors.Add("Expected one C14 record for $($duplicate.Name); found $($duplicate.Count).")
}

foreach ($expected in $expectedRows.GetEnumerator()) {
    $row = @($rows | Where-Object activity_id -eq $expected.Key)
    if ($row.Count -ne 1) {
        $errors.Add("Missing unique C14 record for $($expected.Key).")
        continue
    }
    $row = $row[0]
    if ($row.menu_section -ne $expected.Value.Section) {
        $errors.Add("Wrong menu section for $($expected.Key): $($row.menu_section)")
    }
    if ($row.menu_artwork -ne $expected.Value.Artwork) {
        $errors.Add("Wrong artwork mapping for $($expected.Key): $($row.menu_artwork)")
    }
    foreach ($column in $requiredColumns) {
        if ([string]::IsNullOrWhiteSpace($row.$column)) {
            $errors.Add("Empty $column for $($expected.Key).")
        }
    }
    foreach ($relativePath in @($row.android_behavior_source -split ';') + @($row.android_visual_reference -split ';')) {
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath) -PathType Leaf)) {
            $errors.Add("Missing source/reference for $($expected.Key): $relativePath")
        }
    }
    $artworkIDs = @($row.menu_artwork -split '\|')
    $sourceNames = @($row.menu_provenance -split '\|')
    if ($artworkIDs.Count -ne $sourceNames.Count) {
        $errors.Add("Artwork/provenance count mismatch for $($expected.Key).")
    } else {
        for ($index = 0; $index -lt $artworkIDs.Count; $index += 1) {
            $match = @($provenance | Where-Object {
                $_.ios_asset -eq $artworkIDs[$index] -and
                    $_.android_source_filename -eq $sourceNames[$index]
            })
            if ($match.Count -ne 1) {
                $errors.Add("Missing exact provenance for $($expected.Key): $($artworkIDs[$index]) <- $($sourceNames[$index])")
            }
        }
    }
    if ($row.runtime_gate -notmatch '^pending:' -or $row.runtime_gate -match 'runtime-confirmed|runtime passed|runtime complete') {
        $errors.Add("Runtime gate for $($expected.Key) is not explicitly pending: $($row.runtime_gate)")
    }
}

$catalog = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/ActivityCatalog.swift') -Raw -Encoding utf8
if ($catalog -notmatch 'id: "letters"[\s\S]*activities: \[\.learn, \.letterPairs, \.firstLetterChoices, \.firstLetterPictures\][\s\S]*id: "words"[\s\S]*\.mixed,[\s\S]*\.wordBuild,[\s\S]*\.imageToWord,[\s\S]*\.wordToImage,[\s\S]*\.wordCards[\s\S]*id: "games"[\s\S]*activities: \[\.soccer, \.tower, \.wordMemory, \.ticTacToe\]') {
    $errors.Add('Production section/order contract no longer matches the 13-row C14 record.')
}

$tests = Get-Content -LiteralPath (Join-Path $repoRoot 'Tests/ProductConfigurationTests/LanguageProductionParityTests.swift') -Raw -Encoding utf8
foreach ($testName in @(
    'testProductionCatalogExposesExactlyTheThirteenAndroidActivities',
    'testGenericEnginesAreNotSeparateProductionMenuActivities',
    'testPictureMemoryIsGroupedAsAGameWithoutChangingProductionCount',
    'testEveryLearnedLanguageProductionActivityHasItsIntendedSession',
    'testEveryProductionActivityUsesTheAndroidSourceArtworkMapping',
    'testLearnCardsAndTicTacToeRemainOutsideMasteryProgress'
)) {
    if ($tests -notmatch [regex]::Escape($testName)) {
        $errors.Add("Missing production parity test: $testName")
    }
}

$hub = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/MinikActivityHubView.swift') -Raw -Encoding utf8
$parent = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/ParentAreaView.swift') -Raw -Encoding utf8
if ($hub -match 'languageSelectorSection|shouldShowLanguageSelector') {
    $errors.Add('Learned-language selector helper has returned to the child-facing Home.')
}
if ($parent -notmatch 'Picker\("Learned language"') {
    $errors.Add('Parent Area no longer owns learned-language selection.')
}

$cards = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/CardsView.swift') -Raw -Encoding utf8
$ticTacToe = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/TicTacToeView.swift') -Raw -Encoding utf8
if ($cards -match 'ActivityAttemptData|onAttempt|recordLanguageAttempt') {
    $errors.Add('Word Cards has become graded.')
}
if ($ticTacToe -match 'ActivityAttemptData|onAttempt|recordLanguageAttempt') {
    $errors.Add('Tic-Tac-Toe has become graded.')
}

foreach ($specialized in @(
    @{ File = 'Sources/SoccerView.swift'; Pattern = 'languageAttemptTracker\.makeAttempt\([\s\S]*activityFamily: \.soccer'; Name = 'Soccer' },
    @{ File = 'Sources/TowerView.swift'; Pattern = 'languageAttemptTracker\.makeAttempt\([\s\S]*activityFamily: \.tower'; Name = 'Tower' }
)) {
    $source = Get-Content -LiteralPath (Join-Path $repoRoot $specialized.File) -Raw -Encoding utf8
    if ($source -notmatch $specialized.Pattern) {
        $errors.Add("$($specialized.Name) lost specialized semantic telemetry.")
    }
}

Write-Output "LANGUAGE_PRODUCTION_PARITY_RECORDS_AUDITED=$($rows.Count)"
Write-Output "LANGUAGE_PRODUCTION_PARITY_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'LANGUAGE_PRODUCTION_PARITY_LOCK_OK'

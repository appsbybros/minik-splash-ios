$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$androidResources = Join-Path $repoRoot '..\android\app\src\main\res'
$localeSources = [ordered]@{
    'am' = 'values-am'
    'ar' = 'values-ar'
    'de' = 'values-de'
    'en' = 'values'
    'es' = 'values-es'
    'fr' = 'values-fr'
    'he' = 'values-he'
    'nl' = 'values-nl'
    'pt-BR' = 'values-pt-rBR'
    'pt-PT' = 'values-pt-rPT'
    'ru' = 'values-ru'
}

function Read-AndroidString {
    param(
        [Parameter(Mandatory = $true)][string] $ResourceDirectory,
        [Parameter(Mandatory = $true)][string] $Name
    )

    $path = Join-Path $androidResources "$ResourceDirectory\strings.xml"
    [xml] $document = Get-Content -LiteralPath $path -Raw -Encoding utf8
    [array] $nodes = @($document.resources.string) | Where-Object { $_.name -eq $Name }
    if ($nodes.Length -ne 1) {
        throw "Expected one Android string '$Name' in $path; found $($nodes.Length)."
    }
    $value = [string] $nodes[0].'#text'
    $value = $value.Replace('\n', "`n")
    $value = $value.Replace("\'", "'")
    $value = $value.Replace('\"', '"')
    return $value
}

function ConvertTo-JSONString {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Value)

    return ($Value | ConvertTo-Json -Compress)
}

function ConvertTo-IosTapSoccerCopy {
    param(
        [Parameter(Mandatory = $true)][string] $Locale,
        [Parameter(Mandatory = $true)][string] $Value
    )

    $replacements = @{
        'am' = @(
            @('\u1260\u1218\u130e\u1270\u1275', '\u1260\u1218\u1295\u12ab\u1275'),
            @('\u12ed\u130e\u1275\u1271 (\u12ed\u1218\u1271)', '\u12ed\u1295\u12a9 (\u12ed\u1218\u1271)')
        )
        'ar' = @(
            @('\u0627\u0636\u063a\u0637 \u0648\u0627\u0633\u062d\u0628', '\u0627\u0636\u063a\u0637'),
            @('\u0627\u0631\u0643\u0644 (\u0627\u0633\u062d\u0628)', '\u0627\u0636\u063a\u0637 \u0644\u0631\u0643\u0644')
        )
        'de' = @(
            @('Tippt und zieht', 'Tippt'),
            @('Zieht den richtigen Buchstaben', 'Tippt auf den richtigen Buchstaben')
        )
        'es' = @(
            @('Toca y arrastra', 'Toca'),
            @('Patea (arrastra)', 'Toca para patear')
        )
        'fr' = @(
            @('Touchez et faites glisser', 'Touchez'),
            @('Frappez (faites glisser)', 'Touchez pour frapper')
        )
        'he' = @(
            @('\u05dc\u05d7\u05e6\u05d5 \u05d5\u05d2\u05e8\u05e8\u05d5 \u05d0\u05ea \u05d4\u05d0\u05d5\u05ea\u05d9\u05d5\u05ea', '\u05dc\u05d7\u05e6\u05d5 \u05e2\u05dc \u05d4\u05d0\u05d5\u05ea\u05d9\u05d5\u05ea'),
            @('\u05e6\u05e8\u05d9\u05da \u05dc\u05d2\u05e8\u05d5\u05e8 (\u05dc\u05d1\u05e2\u05d5\u05d8) \u05d0\u05ea \u05d4\u05d0\u05d5\u05ea', '\u05dc\u05d7\u05e6\u05d5 \u05db\u05d3\u05d9 \u05dc\u05d1\u05e2\u05d5\u05d8 \u05d1\u05d0\u05d5\u05ea')
        )
        'nl' = @(
            @('Tik en sleep de letters', 'Tik op de letters'),
            @('Sleep de juiste letter', 'Tik op de juiste letter')
        )
        'pt-BR' = @(
            @('Toque e arraste', 'Toque'),
            @('Chute (arraste)', 'Toque para chutar')
        )
        'pt-PT' = @(
            @('Toca e arrasta', 'Toca'),
            @('Chuta (arrasta)', 'Toca para chutar')
        )
        'ru' = @(
            @('\u041d\u0430\u0436\u0438\u043c\u0430\u0439 \u0438 \u043f\u0435\u0440\u0435\u0442\u0430\u0441\u043a\u0438\u0432\u0430\u0439', '\u041d\u0430\u0436\u0438\u043c\u0430\u0439'),
            @('\u0411\u0435\u0439 (\u043f\u0435\u0440\u0435\u0442\u0430\u0441\u043a\u0438\u0432\u0430\u0439)', '\u041d\u0430\u0436\u0438\u043c\u0430\u0439, \u0447\u0442\u043e\u0431\u044b \u0443\u0434\u0430\u0440\u0438\u0442\u044c')
        )
    }

    $result = $Value
    foreach ($replacement in $replacements[$Locale]) {
        $source = [regex]::Unescape($replacement[0])
        $destination = [regex]::Unescape($replacement[1])
        $result = $result.Replace($source, $destination)
    }
    return $result
}

function New-CatalogEntry {
    param(
        [Parameter(Mandatory = $true)][string] $Key,
        [Parameter(Mandatory = $true)][string[]] $Locales,
        [Parameter(Mandatory = $true)][hashtable] $Values,
        [string[]] $NeedsReviewLocales = @()
    )

    $localizations = foreach ($locale in $Locales) {
        $localeJSON = ConvertTo-JSONString $locale
        $valueJSON = ConvertTo-JSONString $Values[$locale]
        $state = if ($locale -in $NeedsReviewLocales) { 'needs_review' } else { 'translated' }
        "$localeJSON`:{`"stringUnit`":{`"state`":`"$state`",`"value`":$valueJSON}}"
    }

    $keyJSON = ConvertTo-JSONString $Key
    return "$keyJSON`: {`"extractionState`":`"manual`",`"localizations`":{$($localizations -join ',')}}"
}

$keys = [ordered]@{
    'Start' = 'start'
    'Home' = 'plus_menu_home_description'
    # Preserve the shared SoccerView key here. The separately curated Language
    # drag key remains in both catalogs and must not be regenerated from this tap copy.
    "Tap letters in the correct order to kick toward the goal.`nA goal with the right letter earns you a point.`nMissing or being saved with a wrong letter gives the keeper a point.`nThe round continues until the word is complete." = 'game_dialog_text'
    'Top 20 records' = 'records_dialog_title'
    'The records could not be loaded.' = 'records_load_error'
    'Done' = 'records_close'
}

$valuesByKey = @{}
foreach ($pair in $keys.GetEnumerator()) {
    $values = @{}
    foreach ($localePair in $localeSources.GetEnumerator()) {
        $values[$localePair.Key] = Read-AndroidString `
            -ResourceDirectory $localePair.Value `
            -Name $pair.Value
    }

    if ($pair.Key -like 'Tap letters*') {
        $values['en'] = $pair.Key
        foreach ($locale in @($localeSources.Keys | Where-Object { $_ -ne 'en' })) {
            $values[$locale] = ConvertTo-IosTapSoccerCopy -Locale $locale -Value $values[$locale]
        }
    }
    $valuesByKey[$pair.Key] = $values
}

$catalogs = @(
    @{ Path = 'Resources\Localization\All\Localizable.xcstrings'; Locales = @($localeSources.Keys) },
    @{ Path = 'Resources\Localization\EnglishOnly\Localizable.xcstrings'; Locales = @($localeSources.Keys | Where-Object { $_ -ne 'he' }) }
)

foreach ($catalog in $catalogs) {
    $path = Join-Path $repoRoot $catalog.Path
    $source = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)

    foreach ($key in $keys.Keys) {
        $keyJSON = ConvertTo-JSONString $key
        $pattern = '(?m)^(?<indent>[ \t]*)' + [regex]::Escape($keyJSON) + ': .*\r?$'
        $matches = [regex]::Matches($source, $pattern)
        if ($matches.Count -gt 1) {
            for ($index = $matches.Count - 1; $index -ge 1; $index--) {
                $duplicate = $matches[$index]
                $source = $source.Remove($duplicate.Index, $duplicate.Length)
            }
        }
        $needsReviewLocales = if ($key -like 'Tap letters*') {
            @($catalog.Locales | Where-Object { $_ -ne 'en' })
        } else {
            @()
        }
        $replacementEntry = New-CatalogEntry `
            -Key $key `
            -Locales $catalog.Locales `
            -Values $valuesByKey[$key] `
            -NeedsReviewLocales $needsReviewLocales
        $replacement = '${indent}' + $replacementEntry + ','
        $entryExists = [regex]::IsMatch($source, $pattern)
        if ($entryExists) {
            $updated = [regex]::Replace($source, $pattern, $replacement)
        }
        else {
            $stringsPattern = '(?m)^(?<prefix>[ \t]*"strings":[ \t]*\{[ \t]*)\r?$'
            $updated = [regex]::Replace(
                $source,
                $stringsPattern,
                '${prefix}' + "`r`n                    $replacementEntry,",
                1
            )
        }
        if (-not $entryExists -and $updated -eq $source) {
            throw "Catalog entry '$key' could not be migrated in $path."
        }
        $source = $updated
    }

    $source = $source -replace "`r+(?=`n)", "`r"
    $source = $source -replace "(`r?`n){3,}", "`r`n"

    [IO.File]::WriteAllText(
        $path,
        $source,
        [Text.UTF8Encoding]::new($false)
    )
}

Write-Output "ANDROID_INTERFACE_LOCALIZATION_KEYS_MIGRATED=$($keys.Count)"
Write-Output "ANDROID_INTERFACE_LOCALIZATION_CATALOGS_UPDATED=$($catalogs.Count)"

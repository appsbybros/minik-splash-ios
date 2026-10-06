[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$CatalogPath,
    [string]$EnglishOnlyCatalogPath
)

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $PSScriptRoot "..\Sources"
}
if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
    $CatalogPath = Join-Path $PSScriptRoot "..\Resources\Localization\All\Localizable.xcstrings"
}
if ([string]::IsNullOrWhiteSpace($EnglishOnlyCatalogPath)) {
    $EnglishOnlyCatalogPath = Join-Path $PSScriptRoot "..\Resources\Localization\EnglishOnly\Localizable.xcstrings"
}

$localizedKeys = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
if (Test-Path -LiteralPath $CatalogPath) {
    $catalog = Get-Content -Raw -LiteralPath $CatalogPath -Encoding utf8 | ConvertFrom-Json
    foreach ($property in $catalog.strings.PSObject.Properties) {
        [void]$localizedKeys.Add($property.Name)
    }
}

$patterns = @(
    '\bText\(\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"',
    '\bLabel\(\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"',
    '\bButton\(\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"',
    '\bToggle\(\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"',
    '\.accessibility(?:Label|Hint|Value)\(\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"',
    '\b(?:title|subtitle|message):\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"'
)

$findings = foreach ($file in Get-ChildItem -LiteralPath $SourceRoot -Filter *.swift -File) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding utf8) {
        $lineNumber += 1
        foreach ($pattern in $patterns) {
            foreach ($match in [regex]::Matches($line, $pattern)) {
                $value = $match.Groups['value'].Value
                if (-not $localizedKeys.Contains($value)) {
                    [pscustomobject]@{
                        Path = $file.Name
                        Line = $lineNumber
                        Text = $value
                    }
                }
            }
        }
    }
}

$ordered = @($findings | Sort-Object Path, Line, Text -Unique)
$ordered | ForEach-Object { "{0}:{1}: {2}" -f $_.Path, $_.Line, $_.Text }
"LIKELY_USER_VISIBLE_HARDCODED_STRINGS={0}" -f $ordered.Count

function Get-BraceDelta([string]$Line) {
    $openCount = ([regex]::Matches($Line, '\{')).Count
    $closeCount = ([regex]::Matches($Line, '\}')).Count
    return $openCount - $closeCount
}

function Test-IsUserVisibleProducer([string]$Name) {
    return $Name -match '(?i)(accessibility|displayName|hint|label|message|status|subtitle|title|copy)'
}

function Test-IsInternalDynamicLiteral([string]$Line, [string]$Value) {
    if ($Line -match '(?i)(systemName|symbolName|assetName|imageName|storageKey|identifier|rawValue|named:)') {
        return $true
    }
    if ($Value -match '^[A-Z0-9+%=<>.:/\s]{1,8}$') {
        return $true
    }
    if ($Value -match '^[a-z0-9]+(?:\.[a-z0-9]+)+$') {
        return $true
    }
    # A switch with one case per interface language (LanguageMenuAndroidText) is a
    # per-locale translation table, localized by construction.
    if ($Line -match '^\s*case\s+\.(?:english|amharic|arabic|german|spanish|french|hebrew|dutch|portugueseBrazil|portuguesePortugal|russian)\s*:\s*return\s+"') {
        return $true
    }
    $literalPortion = [regex]::Replace($Value, '\\\([^)]*\)', '')
    # Escape sequences such as \n are not words.
    $literalPortion = [regex]::Replace($literalPortion, '\\(?:u\{[0-9A-Fa-f]+\}|[nrt0"''\\])', '')
    if ($literalPortion -notmatch '[A-Za-z]') {
        return $true
    }
    return $false
}

$dynamicFindings = foreach ($file in Get-ChildItem -LiteralPath $SourceRoot -Filter *.swift -File) {
    $lines = @(Get-Content -LiteralPath $file.FullName -Encoding utf8)
    $isSwiftUI = ($lines -join "`n") -match '(?m)^import SwiftUI\s*$'
    $braceDepth = 0
    $producerName = $null
    $producerBaseDepth = -1

    for ($index = 0; $index -lt $lines.Count; $index += 1) {
        $line = $lines[$index]
        $lineNumber = $index + 1

        if ($null -eq $producerName -and
            $line -match '\b(?:var|func)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)[^\r\n]*(?:->|:)\s*String\s*\{') {
            $candidateName = $Matches['name']
            if (Test-IsUserVisibleProducer $candidateName) {
                $producerName = $candidateName
                $producerBaseDepth = $braceDepth
            }
        }

        $candidatePatterns = [System.Collections.Generic.List[string]]::new()
        if ($null -ne $producerName) {
            $candidatePatterns.Add('\breturn\s+"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"')
            $candidatePatterns.Add('^\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"\s*$')
            $candidatePatterns.Add('\?\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"')
            $candidatePatterns.Add(':\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"')
        }
        if ($isSwiftUI -and $line -notmatch '(?i)(systemName|symbolName|assetName|imageName|named:)') {
            $candidatePatterns.Add('\?\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"')
            $candidatePatterns.Add('^\s*:\s*"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"')
        }
        if ($line -match 'onStatusChanged\?\(') {
            $candidatePatterns.Add('"(?<value>[^"\r\n]*[A-Za-z][^"\r\n]*)"')
        }

        foreach ($pattern in $candidatePatterns) {
            foreach ($match in [regex]::Matches($line, $pattern)) {
                $value = $match.Groups['value'].Value
                $valueGroup = $match.Groups['value']
                $prefixBeforeValue = $line.Substring(0, $valueGroup.Index)
                $explicitlyLocalized = $prefixBeforeValue -match 'String\(localized:\s*"$'
                if (-not $explicitlyLocalized -and
                    -not (Test-IsInternalDynamicLiteral -Line $line -Value $value)) {
                    [pscustomobject]@{
                        Path = $file.Name
                        Line = $lineNumber
                        Text = $value
                    }
                }
            }
        }

        $braceDepth += Get-BraceDelta $line
        if ($null -ne $producerName -and $braceDepth -le $producerBaseDepth) {
            $producerName = $null
            $producerBaseDepth = -1
        }
    }
}

$dynamicOrdered = @($dynamicFindings | Sort-Object Path, Line, Text -Unique)
$dynamicOrdered | ForEach-Object { "DYNAMIC_STRING: {0}:{1}: {2}" -f $_.Path, $_.Line, $_.Text }
"DYNAMIC_USER_VISIBLE_UNLOCALIZED_STRINGS={0}" -f $dynamicOrdered.Count

$catalogReferencePatterns = @(
    'String\(localized:\s*"(?<value>[^"\r\n]+)"',
    '\blocalized(?:Format|Title)\(\s*"(?<value>[^"\r\n]+)"'
)
$missingCatalogKeys = foreach ($file in Get-ChildItem -LiteralPath $SourceRoot -Filter *.swift -File) {
    $contents = Get-Content -Raw -LiteralPath $file.FullName -Encoding utf8
    foreach ($pattern in $catalogReferencePatterns) {
        foreach ($match in [regex]::Matches($contents, $pattern)) {
            $value = $match.Groups['value'].Value
            $catalogValue = $value.Replace('\n', "`n").Replace('\t', "`t")
            if (-not $localizedKeys.Contains($catalogValue)) {
                "{0}: {1}" -f $file.Name, $value
            }
        }
    }
}
$missingCatalogKeys = @($missingCatalogKeys | Sort-Object -Unique)
$missingCatalogKeys | ForEach-Object { "MISSING_CATALOG_KEY: $_" }
"MISSING_CATALOG_KEYS={0}" -f $missingCatalogKeys.Count

$fullLocales = @('am', 'ar', 'de', 'en', 'es', 'fr', 'he', 'nl', 'pt-BR', 'pt-PT', 'ru')
$englishOnlyLocales = @('am', 'ar', 'de', 'en', 'es', 'fr', 'nl', 'pt-BR', 'pt-PT', 'ru')
$catalogErrors = [System.Collections.Generic.List[string]]::new()

function Test-CatalogCoverage {
    param(
        [string]$Path,
        [string[]]$ExpectedLocales,
        [System.Collections.Generic.List[string]]$Errors
    )
    $document = Get-Content -Raw -LiteralPath $Path -Encoding utf8 | ConvertFrom-Json
    foreach ($property in $document.strings.PSObject.Properties) {
        $actual = @($property.Value.localizations.PSObject.Properties.Name | Sort-Object)
        $expected = @($ExpectedLocales | Sort-Object)
        if (($actual -join '|') -ne ($expected -join '|')) {
            $Errors.Add("$([IO.Path]::GetFileName($Path)) [$($property.Name)] locales: $($actual -join ',')")
        }
    }
    return $document
}

$allCatalog = Test-CatalogCoverage -Path $CatalogPath -ExpectedLocales $fullLocales -Errors $catalogErrors
$englishCatalog = Test-CatalogCoverage -Path $EnglishOnlyCatalogPath -ExpectedLocales $englishOnlyLocales -Errors $catalogErrors
$allKeys = @($allCatalog.strings.PSObject.Properties.Name | Sort-Object)
$englishKeys = @($englishCatalog.strings.PSObject.Properties.Name | Sort-Object)
if (($allKeys -join '|') -ne ($englishKeys -join '|')) {
    $catalogErrors.Add('Full and English-only catalogs have different key sets.')
}
$catalogErrors | ForEach-Object { "CATALOG_ERROR: $_" }
"CATALOG_ERRORS={0}" -f $catalogErrors.Count

if ($ordered.Count -gt 0 -or $dynamicOrdered.Count -gt 0 -or $missingCatalogKeys.Count -gt 0 -or $catalogErrors.Count -gt 0) {
    exit 1
}

[CmdletBinding()]
param()

$catalogs = @(
    @{
        Path = Join-Path $PSScriptRoot "..\Resources\Localization\All\Localizable.xcstrings"
        Locales = @('en', 'am', 'ar', 'de', 'es', 'fr', 'he', 'nl', 'pt-BR', 'pt-PT', 'ru')
    },
    @{
        Path = Join-Path $PSScriptRoot "..\Resources\Localization\EnglishOnly\Localizable.xcstrings"
        Locales = @('en', 'am', 'ar', 'de', 'es', 'fr', 'nl', 'pt-BR', 'pt-PT', 'ru')
    }
)

$failed = $false
foreach ($definition in $catalogs) {
    $catalog = Get-Content -Raw -LiteralPath $definition.Path -Encoding utf8 |
        ConvertFrom-Json
    $keys = @($catalog.strings.PSObject.Properties)
    foreach ($property in $keys) {
        $actual = @($property.Value.localizations.PSObject.Properties.Name | Sort-Object)
        $expected = @($definition.Locales | Sort-Object)
        if (Compare-Object $expected $actual) {
            Write-Error "Locale coverage mismatch for '$($property.Name)' in $($definition.Path)."
            $failed = $true
        }
    }
    "CATALOG={0}; KEYS={1}; LOCALES={2}" -f $definition.Path, $keys.Count, $definition.Locales.Count
}

if ($failed) { exit 1 }

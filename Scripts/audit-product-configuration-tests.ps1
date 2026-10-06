$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$testRoot = Join-Path $repoRoot "Tests\ProductConfigurationTests"
$sourceRoot = Join-Path $repoRoot "Sources"
$testFiles = @(Get-ChildItem -LiteralPath $testRoot -Filter "*.swift" -File -Recurse | Sort-Object FullName)
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Filter "*.swift" -File -Recurse | Sort-Object FullName)
$errors = [System.Collections.Generic.List[string]]::new()

function Get-CallBlocks {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$CallName
    )

    $blocks = [System.Collections.Generic.List[object]]::new()
    $pattern = "\b$([regex]::Escape($CallName))\s*\("
    foreach ($match in [regex]::Matches($Text, $pattern)) {
        $openIndex = $Text.IndexOf("(", $match.Index)
        $depth = 0
        $inString = $false
        $escaped = $false
        $closeIndex = -1

        for ($index = $openIndex; $index -lt $Text.Length; $index++) {
            $character = $Text[$index]
            if ($inString) {
                if ($escaped) {
                    $escaped = $false
                } elseif ($character -eq "\") {
                    $escaped = $true
                } elseif ($character -eq '"') {
                    $inString = $false
                }
                continue
            }

            if ($character -eq '"') {
                $inString = $true
                continue
            }
            if ($character -eq "(") {
                $depth++
            } elseif ($character -eq ")") {
                $depth--
                if ($depth -eq 0) {
                    $closeIndex = $index
                    break
                }
            }
        }

        if ($closeIndex -lt 0) {
            $line = ([regex]::Matches($Text.Substring(0, $match.Index), "`n")).Count + 1
            $blocks.Add([pscustomobject]@{ Line = $line; Text = $null })
            continue
        }

        $lineNumber = ([regex]::Matches($Text.Substring(0, $match.Index), "`n")).Count + 1
        $blocks.Add([pscustomobject]@{
            Line = $lineNumber
            Text = $Text.Substring($match.Index, $closeIndex - $match.Index + 1)
        })
    }
    return $blocks
}

function Get-RelevantLabels {
    param(
        [Parameter(Mandatory = $true)][string]$Block,
        [Parameter(Mandatory = $true)][string[]]$AllowedLabels
    )

    $labels = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Block, "(?m)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:")) {
        $label = $match.Groups[1].Value
        if (($AllowedLabels -contains $label) -and (-not $labels.Contains($label))) {
            $labels.Add($label)
        }
    }
    return @($labels)
}

function Test-LabelSequence {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][int]$Line,
        [Parameter(Mandatory = $true)][string]$CallName,
        [Parameter(Mandatory = $true)][string[]]$Actual,
        [Parameter(Mandatory = $true)][string[]]$Expected
    )

    if (($Actual -join "|") -ne ($Expected -join "|")) {
        $errors.Add("${File}:${Line}: ${CallName} labels are [$($Actual -join ', ')]; expected [$($Expected -join ', ')].")
    }
}

$manifestLabels = @(
    "stableKey", "assetReference", "source", "englishText", "hebrewText", "level",
    "categoryID", "iosAssetStatus", "androidAssetStatus", "imageAction", "isReadyInCurrentIOS"
)
$learningTextRequiredLabels = @("text", "language", "direction")
$learningTextAllLabels = @("text", "language", "direction", "speechText")
$manifestCallCount = 0
$testManifestCallCount = 0
$learningTextCallCount = 0
$literalTestStableKeys = @{}
$allFiles = @($sourceFiles) + @($testFiles)

foreach ($file in $allFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $relativePath = $file.FullName.Substring($repoRoot.Length).TrimStart("\")
    $isTestFile = $file.FullName.StartsWith($testRoot, [System.StringComparison]::OrdinalIgnoreCase)

    foreach ($call in @(Get-CallBlocks -Text $text -CallName "LanguageVocabularyImageManifestEntry")) {
        $manifestCallCount++
        if ($null -eq $call.Text) {
            $errors.Add("${relativePath}:$($call.Line): unterminated LanguageVocabularyImageManifestEntry call.")
            continue
        }
        $actualLabels = @(Get-RelevantLabels -Block $call.Text -AllowedLabels $manifestLabels)
        Test-LabelSequence -File $relativePath -Line $call.Line -CallName "LanguageVocabularyImageManifestEntry" -Actual $actualLabels -Expected $manifestLabels

        if ($isTestFile) {
            $testManifestCallCount++
            $stableKeyMatch = [regex]::Match($call.Text, "(?m)^\s*stableKey\s*:\s*([^,\r\n]+)")
            if (-not $stableKeyMatch.Success) {
                $errors.Add("${relativePath}:$($call.Line): test manifest fixture has no stableKey expression.")
                continue
            }
            $stableKeyExpression = $stableKeyMatch.Groups[1].Value.Trim()
            if ($stableKeyExpression -match "(^|\W)(englishText|hebrewText)(\W|$)|\.text\b") {
                $errors.Add("${relativePath}:$($call.Line): display text must not be used as manifest identity: $stableKeyExpression")
            }
            if ($stableKeyExpression -match '^"([^"\\]+)"$') {
                $literalKey = $Matches[1]
                if ($literalTestStableKeys.ContainsKey($literalKey)) {
                    $errors.Add("${relativePath}:$($call.Line): duplicate literal synthetic manifest stableKey '$literalKey'.")
                } else {
                    $literalTestStableKeys[$literalKey] = "${relativePath}:$($call.Line)"
                }
            }
        }
    }

    foreach ($call in @(Get-CallBlocks -Text $text -CallName "LearningTextRepresentation")) {
        $learningTextCallCount++
        if ($null -eq $call.Text) {
            $errors.Add("${relativePath}:$($call.Line): unterminated LearningTextRepresentation call.")
            continue
        }
        $actualLabels = @(Get-RelevantLabels -Block $call.Text -AllowedLabels $learningTextAllLabels)
        $expectedLabels = if ($actualLabels -contains "speechText") {
            $learningTextAllLabels
        } else {
            $learningTextRequiredLabels
        }
        Test-LabelSequence -File $relativePath -Line $call.Line -CallName "LearningTextRepresentation" -Actual $actualLabels -Expected $expectedLabels
    }
}

$testLineCount = 0
$optionalIdentityInterpolations = 0
$opaqueViewReturns = 0
foreach ($file in $testFiles) {
    $lines = @(Get-Content -LiteralPath $file.FullName)
    $text = $lines -join "`n"
    $relativePath = $file.FullName.Substring($repoRoot.Length).TrimStart("\")
    $testLineCount += $lines.Count

    if ($text -notmatch "(?m)^\s*@testable\s+import\s+MinikPlus\s*$") {
        $errors.Add("${relativePath}: missing '@testable import MinikPlus'.")
    }

    $identityMatches = @([regex]::Matches($text, "\\\([^\r\n)]*\.androidWordID"))
    $optionalIdentityInterpolations += $identityMatches.Count
    foreach ($match in $identityMatches) {
        $line = ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count + 1
        $errors.Add("${relativePath}:${line}: optional androidWordID is interpolated into a String.")
    }

    $opaqueViewReturns += ([regex]::Matches($text, "->\s*some\s+View\b")).Count
}

Write-Output "PRODUCT_CONFIGURATION_TEST_FILES_AUDITED=$($testFiles.Count)"
Write-Output "PRODUCT_CONFIGURATION_TEST_LINES_AUDITED=$testLineCount"
Write-Output "MANIFEST_ENTRY_CALLS_AUDITED=$manifestCallCount"
Write-Output "TEST_MANIFEST_ENTRY_CALLS_AUDITED=$testManifestCallCount"
Write-Output "LEARNING_TEXT_CALLS_AUDITED=$learningTextCallCount"
Write-Output "OPTIONAL_ANDROID_WORD_ID_INTERPOLATIONS=$optionalIdentityInterpolations"
Write-Output "TEST_OPAQUE_VIEW_RETURN_SITES=$opaqueViewReturns"
Write-Output "PRODUCT_CONFIGURATION_TEST_COMPATIBILITY_ERRORS=$($errors.Count)"
foreach ($errorMessage in $errors) {
    [Console]::Error.WriteLine($errorMessage)
}
if ($errors.Count -gt 0) {
    exit 1
}

# Keep the demonstrated Gate #6 factory-boundary regression in the standard audit.
& (Join-Path $PSScriptRoot "audit-m3-build-contract.ps1") -SelfTest

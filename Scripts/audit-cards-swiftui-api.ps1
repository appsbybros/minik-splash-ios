param([switch]$SelfTest, [switch]$ReportCandidates)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Focused source contract, not a Swift parser, overload resolver, or compiler.
# API authority and remaining Xcode checks: docs/cards-accessibility-mac-analysis.md.
function Test-CardsAccessibilityContract {
    param([string]$Source)

    $failures = [System.Collections.Generic.List[string]]::new()
    # Ignore comments so a commented-out repair cannot satisfy this guard.
    # This simple comment filter is only suitable for this known component.
    $code = [regex]::Replace($Source, '(?s)/\*.*?\*/|(?m)//[^\r\n]*', '')
    $body = [regex]::Match($code, '(?s)var body: some View\s*\{(.*?)private func cardsHeader\(')
    if (-not $body.Success) {
        $failures.Add('Cards body/header boundary changed; review the component contract.')
        return $failures.ToArray()
    }
    $bodyCode = $body.Groups[1].Value
    if ($code -cmatch '\.accessibilityAction\(\s*advance\s*\)') {
        $failures.Add('Historical invalid accessibilityAction(advance) call returned.')
    }
    if ([regex]::Matches($bodyCode, '\.accessibilityAction\b').Count -ne 1 -or
        $bodyCode -cnotmatch '\.accessibilityAddTraits\(\.isButton\)\s*\.accessibilityAction\(\.default\)\s*\{\s*advance\(\)\s*\}') {
        $failures.Add('The Cards tap surface must have one explicit default accessibility action calling advance().')
    }
    if ($bodyCode -cnotmatch '\.onTapGesture\(perform:\s*advance\)') {
        $failures.Add('Manual tap must retain the labeled perform: callback.')
    }
    if ($code -cnotmatch 'private func advance\(\)\s*\{\s*guard scenePhase == \.active else \{ return \}\s*speechPlayer\.stop\(\)\s*session\.advance\(\)\s*\}') {
        $failures.Add('Default activation must use the existing speech-stop/manual-next operation.')
    }
    if ($code -cnotmatch '\.accessibilityHint\("Double tap to advance to the next word"\)') {
        $failures.Add('The existing default-activation hint must remain.')
    }
    return $failures.ToArray()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'Sources/CardsView.swift') -Raw -Encoding UTF8
$failures = @(Test-CardsAccessibilityContract -Source $source)
if ($failures.Count -gt 0) { throw ($failures -join "`n") }

if ($SelfTest) {
    $actionPattern = '\.accessibilityAction\(\.default\)\s*\{\s*advance\(\)\s*\}'
    $mutants = [ordered]@{
        'historical bare function reference' = [regex]::Replace($source, $actionPattern, '.accessibilityAction(advance)')
        'removed action' = [regex]::Replace($source, $actionPattern, '')
        'wrong action kind' = $source.Replace('.accessibilityAction(.default)', '.accessibilityAction(.escape)')
        'custom action substituted for default' = $source.Replace('.accessibilityAction(.default)', '.accessibilityAction(named: Text("Next"))')
        'wrong handler' = [regex]::Replace($source, $actionPattern, '.accessibilityAction(.default) { exit() }')
        'commented-out action' = [regex]::Replace($source, $actionPattern, '/* .accessibilityAction(.default) { advance() } */')
    }
    foreach ($name in $mutants.Keys) {
        if ($mutants[$name] -ceq $source -or @(Test-CardsAccessibilityContract -Source $mutants[$name]).Count -eq 0) {
            throw "Cards regression self-test did not reject: $name"
        }
    }
    Write-Output 'CARDS_SWIFTUI_API_SELF_TESTS=6 rejected mutations; current source accepted'
}

if ($ReportCandidates) {
    # Diagnostic inventory only: these textual candidates may be ordinary values,
    # valid function references, comments, or custom APIs. Human review is required.
    # It deliberately does not assign compiler-error status from a regex match.
    $families = 'accessibilityAction|accessibilityAdjustableAction|accessibilityScrollAction|onTapGesture|onLongPressGesture|onAppear|onDisappear|task|refreshable|onSubmit|simultaneousGesture|highPriorityGesture|gesture|onChange|sheet|fullScreenCover|confirmationDialog|alert'
    $files = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Sources') -Recurse -File -Filter '*.swift' | Sort-Object FullName)
    Write-Output "SWIFTUI_SCAN_SOURCE_FILES=$($files.Count)"
    Write-Output 'CANDIDATES_ONLY: absence of a match is not compiler acceptance; matches are not necessarily errors.'
    foreach ($file in $files) {
        $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
        $patterns = [ordered]@{ modifier = "\.($families)\s*(?=\(|\{)" }
        if ($text -match 'import SwiftUI') {
            $patterns['bare'] = '\.[A-Za-z_]\w*\(\s*[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\s*\)'
            $patterns['labeled-callback'] = '\b[A-Za-z_]\w*\(\s*(?:action|perform):\s*[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\s*\)'
        }
        foreach ($kind in $patterns.Keys) {
            foreach ($match in [regex]::Matches($text, $patterns[$kind])) {
                $line = [regex]::Matches($text.Substring(0, $match.Index), "`n").Count + 1
                $snippet = ($match.Value -replace '\s+', ' ').Trim()
                Write-Output "REVIEW_CANDIDATE [$kind] ${relative}:${line} $snippet"
            }
        }
    }
}

Write-Output 'CARDS_SWIFTUI_API_CONTRACT_OK'
Write-Output 'LIMIT: This guard checks the documented Cards source contract only. SDK overload selection, actor isolation, generated View types, and all four Xcode builds remain unverified.'

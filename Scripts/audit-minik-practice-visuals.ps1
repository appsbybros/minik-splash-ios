param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# A deliberately narrow source-contract guard, NOT a Swift parser/typechecker.
# Revisit these expectations when intentionally changing this component's API.
# Windows static audits cannot replace Xcode compilation of all four products.
function Test-PracticeVisualContract {
    param([string]$Visuals, [hashtable]$Consumers)

    $failures = [System.Collections.Generic.List[string]]::new()
    $start = $Visuals.IndexOf('struct MinikChoiceButtonStyle: ButtonStyle {', [StringComparison]::Ordinal)
    $end = $Visuals.IndexOf('struct MinikTokenButtonStyle:', [StringComparison]::Ordinal)
    if ($start -lt 0 -or $end -le $start) {
        $failures.Add('Cannot isolate MinikChoiceButtonStyle; review the component boundary.')
        return $failures.ToArray()
    }
    $style = $Visuals.Substring($start, $end - $start)
    $bodyStart = $style.IndexOf('func makeBody(configuration: Configuration) -> some View {', [StringComparison]::Ordinal)
    $helperStart = $style.IndexOf('private func palette(for state: FeedbackState) -> ChoicePalette {', [StringComparison]::Ordinal)
    if ($bodyStart -lt 0 -or $helperStart -le $bodyStart) {
        $failures.Add('Choice makeBody/palette signatures changed; review their scope contract.')
        return $failures.ToArray()
    }
    $body = $style.Substring($bodyStart, $helperStart - $bodyStart)
    $helper = $style.Substring($helperStart)

    $requirements = @(
        @($style, 'enum FeedbackState: Equatable\s*\{\s*case idle\s*case selected\s*case correct\s*case incorrect\s*\}', 'Four feedback cases'),
        @($style, 'let feedbackState: FeedbackState\s+let compact: Bool', 'Stored feedbackState/compact API'),
        @($style, '@Environment\(\\\.isEnabled\) private var isEnabled', 'Enabled environment'),
        @($style, '@Environment\(\\\.accessibilityReduceMotion\) private var reduceMotion', 'Reduce Motion environment'),
        @($body, 'let palette = palette\(for: feedbackState\)', 'Palette uses the stored feedback state'),
        @($body, 'colors: feedbackState == \.idle\s*\? \[Color\(red: 0\.59, green: 0\.38, blue: 0\.91\), Color\(red: 0\.25, green: 0\.78, blue: 0\.91\)\]\s*: \[palette\.stroke, palette\.stroke\]', 'Idle gradient and feedback border colors'),
        @($body, 'lineWidth: feedbackState == \.idle \? 2 : palette\.lineWidth', 'Idle width and feedback palette width'),
        @($body, '\.fill\(palette\.fill\)', 'Palette fill retained'),
        @($body, 'configuration\.label', 'Caller label retained'),
        @($body, '\.opacity\(isEnabled \? 1 : 0\.9\)', 'Disabled appearance retained'),
        @($body, '\.scaleEffect\(configuration\.isPressed && !reduceMotion \? 0\.975 : 1\)', 'Reduce Motion press scale retained'),
        @($body, '\.animation\(reduceMotion \? nil : \.easeOut\(duration: 0\.16\), value: configuration\.isPressed\)', 'Reduce Motion animation retained'),
        @($helper, 'switch state\s*\{', 'Helper-local state is valid only in the palette helper')
    )
    foreach ($requirement in $requirements) {
        if ($requirement[0] -cnotmatch $requirement[1]) {
            $failures.Add($requirement[2])
        }
    }
    # Limit this rejection to makeBody. Other styles legitimately own `state`.
    if ($body -cmatch '\bstate\b') {
        $failures.Add('Choice makeBody references state; its stored API is feedbackState.')
    }
    foreach ($case in @('idle', 'selected', 'correct', 'incorrect')) {
        if ([regex]::Matches($helper, "case \.$case\s*:").Count -ne 1) {
            $failures.Add("Palette must handle .$case exactly once.")
        }
    }
    $paletteStart = $Visuals.IndexOf('private struct ChoicePalette {', [StringComparison]::Ordinal)
    if ($paletteStart -lt 0) {
        $failures.Add('ChoicePalette declaration is missing.')
    } else {
        $palette = $Visuals.Substring($paletteStart)
        $fields = @{ fill = 'LinearGradient'; stroke = 'Color'; lineWidth = 'CGFloat'; shadow = 'Color'; shadowRadius = 'CGFloat'; shadowY = 'CGFloat' }
        foreach ($field in $fields.Keys) {
            if ($palette -cnotmatch "let ${field}: $($fields[$field])\b" -or
                $body -cnotmatch "palette\.$field\b") {
                $failures.Add("ChoicePalette.$field declaration/use contract changed.")
            }
        }
    }

    $callCount = 0
    foreach ($path in $Consumers.Keys) {
        $text = $Consumers[$path]
        $count = [regex]::Matches($text, '\bMinikChoiceButtonStyle\s*\(').Count
        $callCount += $count
        # Current production integration has one caller and two memberwise labels.
        # Additional call forms must be reviewed, rather than silently ignored.
        $validCount = [regex]::Matches($text, 'MinikChoiceButtonStyle\(\s*feedbackState: choiceFeedbackState\(choice\),\s*compact: compact\s*\)').Count
        if ($count -ne $validCount) {
            $failures.Add("${path}: choice-style constructor API changed.")
        }
    }
    if ($callCount -ne 1 -or -not $Consumers.ContainsKey('MultipleChoiceView.swift')) {
        $failures.Add('Expected the shared MultipleChoiceView choice-style caller.')
    } else {
        $caller = $Consumers['MultipleChoiceView.swift']
        foreach ($pattern in @(
            'private func choiceFeedbackState\(_ choice: Choice\) -> MinikChoiceButtonStyle\.FeedbackState',
            'return \.idle', 'return \.selected', 'return \.correct', 'return \.incorrect',
            '\.disabled\(!session\.canSelectChoices\)',
            '\.accessibilityLabel\(choiceAccessibilityLabel\(for: choice\)\)',
            '\.accessibilityHint\(accessibilityHint\(for: choice\)\)'
        )) {
            if ($caller -cnotmatch $pattern) { $failures.Add("MultipleChoiceView integration changed: $pattern") }
        }
    }
    return $failures.ToArray()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$visuals = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'Sources/MinikPracticeVisuals.swift')
$consumers = @{}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Sources') -Filter '*.swift' -File -Recurse) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    if ($text -cmatch '\bMinikChoiceButtonStyle\s*\(') { $consumers[$file.Name] = $text }
}
$failures = @(Test-PracticeVisualContract -Visuals $visuals -Consumers $consumers)
if ($failures.Count -gt 0) { throw ($failures -join "`n") }

if ($SelfTest) {
    # Mutations are in memory only. The exact historical failure must be caught,
    # including either bad reference reintroduced by itself.
    $mutants = [ordered]@{
        'both historical references' = $visuals.Replace('feedbackState == .idle', 'state == .idle')
        'gradient reference only' = $visuals.Replace('colors: feedbackState == .idle', 'colors: state == .idle')
        'width reference only' = $visuals.Replace('lineWidth: feedbackState == .idle', 'lineWidth: state == .idle')
        'missing property' = $visuals.Replace('let feedbackState: FeedbackState', 'let feedback: FeedbackState')
        'palette API drift' = $visuals.Replace('let palette = palette(for: feedbackState)', 'let palette = palette(for: .idle)')
        'missing feedback case' = $visuals.Replace('case .correct:', 'case .obsolete:')
    }
    foreach ($name in $mutants.Keys) {
        if (@(Test-PracticeVisualContract -Visuals $mutants[$name] -Consumers $consumers).Count -eq 0) {
            throw "Self-test failed to reject $name."
        }
    }
    $badConsumers = $consumers.Clone()
    $badConsumers['MultipleChoiceView.swift'] = $badConsumers['MultipleChoiceView.swift'].Replace('feedbackState: choiceFeedbackState(choice)', 'state: choiceFeedbackState(choice)')
    if (@(Test-PracticeVisualContract -Visuals $visuals -Consumers $badConsumers).Count -eq 0) {
        throw 'Self-test failed to reject the wrong caller argument label.'
    }
    Write-Output 'PASS: seven in-memory regression mutations rejected; repaired source accepted.'
}
Write-Output 'PASS: MinikChoiceButtonStyle state/palette/caller/accessibility source contract.'
Write-Output 'LIMIT: This focused source audit is not Swift parsing or typechecking. Xcode compilation remains required for all four products.'

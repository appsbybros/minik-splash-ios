param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# This checks known source boundaries. It does not execute Swift or XCTest.
# Diagnosis and the two distinct factory paths: docs/m3-build-xctest-root-cause.md.
function Test-M3BuildBoundary {
    param([hashtable]$Files)
    $failures = [System.Collections.Generic.List[string]]::new()
    $test = [regex]::Match($Files.LegacyTest, '(?ms)^    func testM3BuildKeepsTheMissingValueTaskInsideTheBuildInteraction\(\) throws \{(.*?)^    \}')
    if (-not $test.Success) {
        $failures.Add('Legacy M3 Build regression method missing; review the boundary explicitly.')
    } else {
        $body = $test.Groups[1].Value
        if ($body.Contains('missingValueExpression')) {
            $failures.Add('WRONG_FACTORY_BOUNDARY: legacy MathActivitySessionFactory cannot satisfy a typed missingValueExpression assertion.')
        }
        foreach ($required in @(
            'mathFactory.makeBuildSession(for: .m3)',
            'guard case .mathExpression(let prompt)',
            'XCTAssertEqual(prompt.expression, "\(lhs) + \u{25A1} = \(result)")',
            'XCTAssertEqual(lhs + rhs, result)',
            'XCTAssertEqual(pieces[1], "+")',
            'XCTAssertEqual(pieces[3], "=")'
        )) {
            if (-not $body.Contains($required)) { $failures.Add("Legacy semantic assertion missing: $required") }
        }
    }
    foreach ($check in @(
        @{ Key = 'LegacyFactory'; Text = 'private let provider = MathContentProvider()' },
        @{ Key = 'LegacyFactory'; Text = 'provider.buildChallenge(for: request)' },
        @{ Key = 'LegacyProvider'; Text = 'let prompt = Prompt(representations: [mathExpression(' },
        @{ Key = 'ProductionFactory'; Text = 'relationships.compactMap(provider.buildEquationChallenge)' },
        @{ Key = 'ProductionProvider'; Text = '.math(.missingValueExpression(MathMissingValueRepresentation(' },
        @{ Key = 'ProductionTest'; Text = 'testBuildMathPreservesTypedMissingValuePromptsAcrossAllSixChallenges' },
        @{ Key = 'ProductionTest'; Text = 'factory.makeSession(for: .buildMath)' },
        @{ Key = 'ProductionTest'; Text = '.math(.missingValueExpression(let prompt))' },
        @{ Key = 'ProviderTest'; Text = 'testEveryBuildEquationRetainsItsTypedRelationshipAndOrderedSolution' },
        @{ Key = 'ProviderTest'; Text = 'for relationship in MathM3ContentProvider.relationships {' },
        @{ Key = 'ProviderTest'; Text = '.math(.missingValueExpression(let prompt))' }
    )) {
        if (-not $Files[$check.Key].Contains($check.Text)) { $failures.Add("Boundary/coverage changed: $($check.Key): $($check.Text)") }
    }
    return $failures.ToArray()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$paths = @{
    LegacyTest = 'Tests/ProductConfigurationTests/MathActivitySessionFactoryTests.swift'
    LegacyFactory = 'Sources/MathActivitySessionFactory.swift'
    LegacyProvider = 'Sources/MathContentProvider.swift'
    ProductionFactory = 'Sources/MathM3ActivitySessionFactory.swift'
    ProductionProvider = 'Sources/MathM3ContentProvider.swift'
    ProductionTest = 'Tests/ProductConfigurationTests/MathM3ActivitySessionFactoryTests.swift'
    ProviderTest = 'Tests/ProductConfigurationTests/MathM3ContentProviderTests.swift'
}
$files = @{}
foreach ($key in $paths.Keys) {
    $files[$key] = Get-Content -LiteralPath (Join-Path $repoRoot $paths[$key]) -Raw -Encoding UTF8
}
$failures = @(Test-M3BuildBoundary -Files $files)
if ($failures.Count -gt 0) { throw ($failures -join "`n") }

if ($SelfTest) {
    $mutations = @(
        @{ Key = 'LegacyTest'; From = 'guard case .mathExpression(let prompt)'; To = 'guard case .math(.missingValueExpression(let prompt))' },
        @{ Key = 'LegacyTest'; From = 'XCTAssertEqual(prompt.expression, "\(lhs) + \u{25A1} = \(result)")'; To = '' },
        @{ Key = 'LegacyFactory'; From = 'private let provider = MathContentProvider()'; To = 'private let provider = MathM3ContentProvider()' },
        @{ Key = 'ProductionTest'; From = '.math(.missingValueExpression(let prompt))'; To = '.mathExpression(let prompt)' },
        @{ Key = 'ProviderTest'; From = 'for relationship in MathM3ContentProvider.relationships {'; To = 'for relationship in MathM3ContentProvider.relationships.prefix(1) {' }
    )
    foreach ($mutation in $mutations) {
        $changed = $files.Clone()
        $changed[$mutation.Key] = $changed[$mutation.Key].Replace($mutation.From, $mutation.To)
        if ($changed[$mutation.Key] -ceq $files[$mutation.Key] -or @(Test-M3BuildBoundary -Files $changed).Count -eq 0) {
            throw "Boundary self-test did not reject mutation in $($mutation.Key)."
        }
    }
    Write-Output 'M3_BUILD_BOUNDARY_SELF_TESTS=5 rejected mutations'
}
Write-Output 'M3_BUILD_BOUNDARY_CONTRACT_OK'
Write-Output 'LIMIT: Source contracts only; randomized values, Swift typechecking and XCTest execution are not evaluated by this script.'

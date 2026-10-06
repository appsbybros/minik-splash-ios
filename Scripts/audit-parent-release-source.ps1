param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Require-Pattern([string]$RelativePath, [string]$Pattern, [string]$Message) {
    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        $errors.Add("Missing $RelativePath")
        return
    }
    if ((Get-Content -Raw -LiteralPath $path) -notmatch $Pattern) {
        $errors.Add($Message)
    }
}

Require-Pattern 'Sources/RemoveAdsReminder.swift' 'firstDelay: TimeInterval = 2 \* 24 \* 60 \* 60' 'Android two-day first reminder delay is missing.'
Require-Pattern 'Sources/RemoveAdsReminder.swift' 'repeatDelay: TimeInterval = 14 \* 24 \* 60 \* 60' 'Android fourteen-day reminder delay is missing.'
Require-Pattern 'Sources/RemoveAdsReminder.swift' 'state\.nextPresentationAt = now\.addingTimeInterval\(RemoveAdsReminderPolicy\.repeatDelay\)[\s\S]*wasShownThisSession = true' 'Reminder must defer on presentation and show once per session.'
Require-Pattern 'Sources/RemoveAdsReminder.swift' 'adsAreActive[\s\S]*purchaseIsAvailable[\s\S]*!state\.neverShowAgain[\s\S]*!wasShownThisSession' 'Reminder eligibility gates are incomplete.'
Require-Pattern 'Sources/RemoveAdsReminder.swift' 'ParentalGateView\(' 'Reminder purchase is not protected by a grown-up gate.'
Require-Pattern 'Sources/RootView.swift' 'isProviderReady\(\)[\s\S]*!commerceController\.isRemoveAdsActive[\s\S]*purchaseIsAvailable: commerceController\.removeAdsProduct != nil' 'Root reminder requires real ads, no entitlement, and a loaded product.'
Require-Pattern 'Sources/MinikReleaseInformation.swift' 'url\.scheme\?\.lowercased\(\) == "https"[\s\S]*url\.host != nil' 'External Parent destinations must validate HTTPS URLs.'
Require-Pattern 'Sources/ParentAreaView.swift' 'gatedParentAction = \.external\(destination\)[\s\S]*case \.external\(let destination\):[\s\S]*openURL\(url\)' 'External links do not pass through the grown-up gate.'
Require-Pattern 'Sources/ParentAreaView.swift' 'LabeledContent\("App version", value: releaseInformation\.versionDescription\)' 'Version/build metadata is not exposed in Parent Area.'
Require-Pattern 'project.yml' 'MinikPrivacyPolicyURL: \$\(MINIK_PRIVACY_POLICY_URL\)[\s\S]*MinikTermsOfUseURL: \$\(MINIK_TERMS_OF_USE_URL\)[\s\S]*MinikSupportURL: \$\(MINIK_SUPPORT_URL\)' 'Configurable release URL hooks are incomplete.'
Require-Pattern 'Tests/ProductConfigurationTests/ParentReleaseSourceTests.swift' 'testRemoveAdsReminderUsesAndroidTwoDayFirstDelayAndFourteenDayRepeat' 'Reminder cadence tests are missing.'
Require-Pattern 'Tests/ProductConfigurationTests/ParentReleaseSourceTests.swift' 'testReleaseInformationAcceptsOnlyConfiguredHTTPSDestinations' 'Release URL validation tests are missing.'

$parent = Get-Content -Raw -LiteralPath (Join-Path $RepositoryRoot 'Sources/ParentAreaView.swift')
if ($parent -match '\bLink\s*\(') {
    $errors.Add('Parent Area must not bypass the grown-up gate with a direct Link.')
}

Write-Output "PARENT_RELEASE_SOURCE_AUDIT_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'PARENT_RELEASE_SOURCE_AUDIT_OK'

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

function Require-Pattern([string]$Path, [string]$Pattern, [string]$Message) {
    $source = [IO.File]::ReadAllText((Join-Path $root $Path), [Text.Encoding]::UTF8)
    if ($source -notmatch $Pattern) { $errors.Add("${Path}: $Message") }
}

Require-Pattern 'Sources/LearningReminderNotifications.swift' 'defaultInterval: TimeInterval = 7 \* 24 \* 60 \* 60' 'weekly first-release cadence changed'
Require-Pattern 'Sources/LearningReminderNotifications.swift' 'requestAuthorization\(options: \[\.alert, \.sound\]\)' 'alert/sound permission request missing'
Require-Pattern 'Sources/LearningReminderNotifications.swift' 'func setEnabled\([\s\S]*requestAuthorization\(\)' 'Parent opt-in path does not request permission'
Require-Pattern 'Sources/LearningReminderNotifications.swift' 'func synchronize\([\s\S]*authorizationStatus\(\)[\s\S]*isScheduled' 'lifecycle repair path missing'
Require-Pattern 'Sources/ParentAreaView.swift' 'learningReminderController\.setEnabled[\s\S]*Learning reminders' 'Parent control is not connected'
Require-Pattern 'Sources/RootView.swift' 'scenePhase[\s\S]*learningReminderController\.synchronize' 'active-scene synchronization is missing'
Require-Pattern 'Tests/ProductConfigurationTests/LearningReminderNotificationTests.swift' 'testLifecycleSynchronizationNeverPromptsAndRepairsMissingSchedule' 'no-prompt lifecycle regression missing'
Require-Pattern 'Tests/ProductConfigurationTests/LearningReminderNotificationTests.swift' 'testDisableCancelsOnlyTheProductReminder' 'disable/cancel regression missing'

$notificationSource = [IO.File]::ReadAllText(
    (Join-Path $root 'Sources/LearningReminderNotifications.swift'),
    [Text.Encoding]::UTF8
)
$synchronize = [regex]::Match(
    $notificationSource,
    '(?ms)func synchronize\([^}]+\{(?<body>.*?)(?=^    func |^})'
)
if (-not $synchronize.Success -or $synchronize.Groups['body'].Value -match 'requestAuthorization\(') {
    $errors.Add('Lifecycle synchronization must never request notification permission.')
}

$errors | ForEach-Object { "LEARNING_REMINDER_ERROR=$_" }
"LEARNING_REMINDER_ERRORS=$($errors.Count)"
if ($errors.Count -gt 0) { exit 1 }

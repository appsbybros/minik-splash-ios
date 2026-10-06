$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:/Users/User/.jdks/jbr-21.0.11'
$env:ANDROID_HOME = 'C:/Users/User/AppData/Local/Android/Sdk'
$buildProject = 'C:/Projects/MinikPaddleAndLearn'
$buildEvidence = Join-Path $buildProject 'artifacts/bounce-refresh-20260930'
New-Item -ItemType Directory -Force -Path $buildEvidence | Out-Null
Push-Location $buildProject
try {
    # Java compiler notices on stderr are not PowerShell terminating errors.
    $ErrorActionPreference = 'Continue'
    & ./gradlew.bat :app:assembleDebug :app:assembleRelease :app:bundleRelease :app:test :app:lintDebug --console=plain *> (Join-Path $buildEvidence 'build.log')
    $buildResult = $LASTEXITCODE
    Get-Content (Join-Path $buildEvidence 'build.log') -Tail 65
    exit $buildResult
} finally { Pop-Location }

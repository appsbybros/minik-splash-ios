$env:JAVA_HOME = 'C:/Users/User/.jdks/jbr-21.0.11'
$env:ANDROID_HOME = 'C:/Users/User/AppData/Local/Android/Sdk'
$buildProject = 'C:/Projects/minikMath'
$buildEvidence = Join-Path $buildProject 'artifacts/result-banner-20260930'
New-Item -ItemType Directory -Force -Path $buildEvidence | Out-Null
Push-Location $buildProject
try {
    $ErrorActionPreference = 'Continue'
    & ./gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug --console=plain *> (Join-Path $buildEvidence 'build.log')
    $buildResult = $LASTEXITCODE
    Get-Content (Join-Path $buildEvidence 'build.log') -Tail 45
    exit $buildResult
} finally { Pop-Location }

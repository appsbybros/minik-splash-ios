$ErrorActionPreference='Stop'
if($env:JAVA_HOME){$env:PATH=(Join-Path $env:JAVA_HOME 'bin')+';'+$env:PATH}
Push-Location $PSScriptRoot
try {
    if(-not (Test-Path -LiteralPath 'node_modules/firebase-tools/lib/bin/firebase.js')){
        throw 'Run npm ci inside the firebase directory first. Set JAVA_HOME to your JDK 21 installation.'
    }
    npm run emulators
    if($LASTEXITCODE -ne 0){throw "Local emulators exited with code $LASTEXITCODE"}
} finally {Pop-Location}

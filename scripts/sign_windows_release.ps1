# Signs the Windows release bundle (every .exe and .dll that is ours) with a code-signing
# certificate, then verifies each signature. PLACEHOLDER until the owner has a certificate: if a
# cloud signing service or a hardware-token EV certificate is chosen instead of a PFX, this script
# is replaced, not extended.
#
#   pwsh scripts/sign_windows_release.ps1 <bundle dir>
#
# Inputs come from the environment (the release-tag job's repository secrets) and are never printed:
#   WINDOWS_SIGNING_PFX_BASE64    the certificate and private key (.pfx, base64)
#   WINDOWS_SIGNING_PFX_PASSWORD  its password
# A missing input is named and the release stops before anything is signed.

param([Parameter(Mandatory = $true)][string]$BundleDir)
$ErrorActionPreference = 'Stop'

$missing = @('WINDOWS_SIGNING_PFX_BASE64', 'WINDOWS_SIGNING_PFX_PASSWORD') |
  Where-Object { -not [Environment]::GetEnvironmentVariable($_) }
if ($missing) {
  Write-Output "::error::Windows release signing is not set up: $($missing -join ', ') missing. The release tag stops here rather than ship an unsigned app."
  exit 1
}

$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $signtool) { Write-Output '::error::signtool.exe not found'; exit 1 }

$pfx = Join-Path $env:RUNNER_TEMP 'release-signing.pfx'
try {
  [IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:WINDOWS_SIGNING_PFX_BASE64))
  # Our own binaries only: the app and the Rust core. Third-party plugin DLLs keep their vendors' state.
  $targets = @('fuzzzy_ink.exe', 'fuzzy_crypto_core.dll') | ForEach-Object { Join-Path $BundleDir $_ }
  foreach ($target in $targets) {
    if (-not (Test-Path $target)) { Write-Output "::error::missing $target"; exit 1 }
    & $signtool.FullName sign /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com `
      /f $pfx /p $env:WINDOWS_SIGNING_PFX_PASSWORD $target
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $signtool.FullName verify /pa /v $target
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
} finally {
  Remove-Item -Force -ErrorAction SilentlyContinue $pfx
}

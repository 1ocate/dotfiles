#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/windows-environment.ps1')
$testRoot = Join-Path $env:TEMP ('dotfiles-selection-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot 'scripts') | Out-Null
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/environment.py') -Destination (Join-Path $testRoot 'scripts/environment.py')
function Expect-Rejection([scriptblock]$Action, [string]$Pattern) {
    try { & $Action }
    catch { if ($_.Exception.Message -like $Pattern) { return }; throw }
    throw 'Expected rejection did not occur.'
}
Expect-Rejection { Assert-WindowsPowerShellSelection -RepoPath $testRoot } '*registration failed*'
if (Test-Path (Join-Path $testRoot '.local')) { throw 'Unapproved invocation wrote state.' }
Assert-WindowsPowerShellSelection -RepoPath $testRoot -ApprovePowerShell
$statePath = Join-Path $testRoot '.local/environment.json'
$first = [System.IO.File]::ReadAllBytes($statePath)
Assert-WindowsPowerShellSelection -RepoPath $testRoot
Write-WindowsSelectionStatus -RepoPath $testRoot
if ([Convert]::ToBase64String($first) -ne [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($statePath))) { throw 'Repeat invocation changed approval.' }
$state = Get-Content $statePath -Raw | ConvertFrom-Json
$state.host = 'another-host'
$state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
Expect-Rejection { Assert-WindowsPowerShellSelection -RepoPath $testRoot } '*registration failed*'
$state.host = [Environment]::MachineName
$state.approved = 'true'
$state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
Expect-Rejection { Assert-WindowsPowerShellSelection -RepoPath $testRoot } '*registration failed*'
$state.approved = $true
$state.host = [Environment]::MachineName
$state.environment = 'windows-wsl'
$state | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
Expect-Rejection { Assert-WindowsPowerShellSelection -RepoPath $testRoot } '*registration failed*'
$oldOS = $env:OS
try {
    $env:OS = 'Linux'
    Expect-Rejection { Assert-WindowsPowerShellSelection -RepoPath $testRoot -ApprovePowerShell } '*requires native Windows*'
} finally { $env:OS = $oldOS }
Write-Output 'PASS: approval, repeat invocation, host/environment mismatch and non-Windows rejection.'
Write-Output "Only temporary test state was written: $testRoot"

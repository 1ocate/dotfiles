#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts/setup-meslo-font.ps1')
$testRoot = Join-Path $repo ('.local/meslo-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $testRoot 'scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot 'fonts') -Force | Out-Null
Copy-Item (Join-Path $repo 'fonts/meslo.json') (Join-Path $testRoot 'fonts/meslo.json')
$environmentMock = 'function Write-WindowsSelectionStatus { param($RepoPath); "mock selection read-only" }' + "`n" + 'function Assert-WindowsPowerShellSelection { param($RepoPath, [switch]$ApprovePowerShell); if (-not $script:approved) { throw "Unapproved mock environment" } }'
$environmentMock | Set-Content (Join-Path $testRoot 'scripts/windows-environment.ps1')
$oldLocal = $env:LOCALAPPDATA
$oldOS = $env:OS
$script:registrations = @{}
$script:downloadCalls = 0
$script:publishCalls = 0
$script:approved = $false
$script:bytes = [Text.Encoding]::UTF8.GetBytes('mock pinned font')
$sha = [Security.Cryptography.SHA256]::Create()
$hash = ([BitConverter]::ToString($sha.ComputeHash($script:bytes))).Replace('-', '').ToLowerInvariant()
$sha.Dispose()
function Get-MesloFontRegistration { param($Name, $Scope); return $script:registrations[$Scope] }
function Set-MesloFontRegistration { param($Name, $Target); if ($script:registrations['User']) { throw 'Concurrent registry conflict' }; $script:registrations['User'] = $Target }
function Remove-MesloFontRegistration { param($Name); $script:registrations.Remove('User') }
function Receive-MesloFont { param($Url, $Destination); $script:downloadCalls++; [IO.File]::WriteAllBytes($Destination, $script:bytes) }
function Publish-MesloFontChange { param($Target); $script:publishCalls++; if ($script:publishFailure) { throw 'Mock native font load failure' } }
function Expect-Failure { param([scriptblock]$Action, [string]$Pattern); try { & $Action; throw 'Expected failure did not occur' } catch { if ($_.Exception.Message -notmatch $Pattern) { throw } } }
try {
    $env:LOCALAPPDATA = Join-Path $testRoot 'profile'
    $env:OS = 'Windows_NT'
    $manifest = Get-MesloFontManifest -RepoPath $repo
    if ($manifest.sha256 -ne '66e3a38c5caad569892bd5c241d0ea1fa3e09690521bd9453b77457e1208852a' -or $manifest.family -ne 'MesloLGMDZ Nerd Font Mono') { throw 'Pinned manifest changed without fixture update.' }
    Invoke-MesloFontSetup -RepoPath $testRoot -Plan -ApprovePowerShell | Out-Null
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot -Check -ApprovePowerShell } 'missing or unregistered'
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot } 'Unapproved'
    if ($script:downloadCalls -or $script:registrations.Count -or (Test-Path $env:LOCALAPPDATA) -or (Test-Path (Join-Path $testRoot '.local'))) { throw 'Read-only or unapproved setup changed state.' }
    Write-Output 'PASS: Plan/Check/Approve remain read-only; missing font Check and unapproved apply fail.'
    $env:OS = 'Linux'
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot -Plan } 'native Windows'
    $env:OS = 'Windows_NT'
    $manifest.sha256 = $hash
    $status = Get-MesloFontStatus -Manifest $manifest
    $wrong = $manifest.PSObject.Copy()
    $wrong.sha256 = ('0' * 64)
    Expect-Failure { Install-MesloFont -RepoPath $testRoot -Manifest $wrong -Status $status } 'SHA256 mismatch'
    if ((Test-Path $status.Target) -or $script:registrations.Count -or $script:publishCalls) { throw 'Hash failure installed state.' }
    Write-Output 'PASS: hash mismatch blocks target/registry/native changes; download is test bytes only.'
    New-Item -ItemType Directory -Path (Split-Path -Parent $status.Target) -Force | Out-Null
    [IO.File]::WriteAllText($status.Target, 'user file')
    Expect-Failure { Get-MesloFontStatus -Manifest $manifest } 'will not be overwritten'
    if ([IO.File]::ReadAllText($status.Target) -ne 'user file') { throw 'Existing user file changed.' }
    [IO.File]::Delete($status.Target)
    $script:registrations['User'] = (Join-Path $testRoot 'missing-other-font.ttf')
    Expect-Failure { Get-MesloFontStatus -Manifest $manifest } 'registration conflicts'
    $script:registrations.Clear()
    Write-Output 'PASS: pre-existing file and registry conflicts preserved.'
    Install-MesloFont -RepoPath $testRoot -Manifest $manifest -Status (Get-MesloFontStatus $manifest) | Out-Null
    $ready = Get-MesloFontStatus -Manifest $manifest
    if (-not $ready.Registered -or $ready.Scope -ne 'User') { throw 'Install not verified.' }
    $script:registrations['Machine'] = (Join-Path $testRoot 'machine-missing.ttf')
    Expect-Failure { Get-MesloFontStatus $manifest } 'Machine font registration conflicts'
    $machineConflict = Join-Path $testRoot 'machine-conflict.ttf'
    [IO.File]::WriteAllText($machineConflict, 'other version')
    $script:registrations['Machine'] = $machineConflict
    Expect-Failure { Get-MesloFontStatus $manifest } 'Machine font registration conflicts'
    $script:registrations['Machine'] = $ready.Target
    if ((Get-MesloFontStatus $manifest).Scope -ne 'User') { throw 'Dual valid registration lost user priority.' }
    $script:registrations.Remove('Machine')
    Write-Output 'PASS: both registry scopes checked; missing/wrong machine asset rejected despite valid user registration.'
    $downloadBefore = $script:downloadCalls
    $publishBefore = $script:publishCalls
    Install-MesloFont -RepoPath $testRoot -Manifest $manifest -Status $ready | Out-Null
    if ($script:downloadCalls -ne $downloadBefore -or $script:publishCalls -ne $publishBefore) { throw 'Repeat setup was not idempotent.' }
    $script:registrations.Clear()
    $unregistered = Get-MesloFontStatus -Manifest $manifest
    if ($unregistered.Status -ne 'Unregistered') { throw 'File alone incorrectly treated as installed.' }
    Install-MesloFont -RepoPath $testRoot -Manifest $manifest -Status $unregistered | Out-Null
    if ($script:downloadCalls -ne $downloadBefore -or -not (Get-MesloFontStatus $manifest).Registered) { throw 'Registration-only repair downloaded or failed.' }
    Write-Output 'PASS: exact bytes and registry verification, idempotence, file-only registration repair.'
    $script:registrations.Clear()
    [IO.File]::Delete($status.Target)
    $script:publishFailure = $true
    Expect-Failure { Install-MesloFont -RepoPath $testRoot -Manifest $manifest -Status (Get-MesloFontStatus $manifest) } 'native font load failure'
    if ((Test-Path $status.Target) -or $script:registrations.Count) { throw 'Native failure left success state.' }
    $script:publishFailure = $false
    $machineTarget = Join-Path $testRoot 'system-mock.ttf'
    [IO.File]::WriteAllBytes($machineTarget, $script:bytes)
    $script:registrations['Machine'] = $machineTarget
    if ((Get-MesloFontStatus $manifest).Scope -ne 'Machine') { throw 'Exact preinstalled system registration not reused.' }
    Write-Output 'PASS: failed native registration rolls back only new state; exact system registration reused.'
    $script:registrations.Clear()
    $script:approved = $true
    $stateDirectory = Join-Path $testRoot '.local'
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    $statePath = Join-Path $stateDirectory 'setup-state.json'
    $wrongHost = [pscustomobject]@{ host='another-host'; environment='windows-powershell'; components=[pscustomobject]@{ neovim=[pscustomobject]@{status='old'} } }
    $wrongHost | ConvertTo-Json -Depth 10 | Set-Content $statePath -Encoding UTF8
    $stateBefore = [IO.File]::ReadAllText($statePath)
    $callsBefore = $script:downloadCalls
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot -ApprovePowerShell } 'another host/environment'
    if ($script:downloadCalls -ne $callsBefore -or [IO.File]::ReadAllText($statePath) -ne $stateBefore) { throw 'Wrong-host progress changed state.' }
    $wrongHost.host = [Environment]::MachineName
    $wrongHost.environment = $null
    $wrongHost | ConvertTo-Json -Depth 10 | Set-Content $statePath -Encoding UTF8
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot } 'another host/environment'
    '{broken' | Set-Content $statePath -Encoding UTF8
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot } 'Invalid setup-state JSON'
    [IO.File]::Delete($statePath)
    # Use test-byte pin only in this temporary checkout; upstream manifest stays intact.
    $manifest | ConvertTo-Json | Set-Content (Join-Path $testRoot 'fonts/meslo.json') -Encoding UTF8
    Invoke-MesloFontSetup -RepoPath $testRoot | Out-Null
    $newState = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
    if ($newState.host -ne [Environment]::MachineName -or $newState.environment -ne 'windows-powershell' -or $newState.components.meslo_font.status -ne 'ready') { throw 'New current-host completion not recorded.' }
    $newState.components | Add-Member -NotePropertyName other_component -NotePropertyValue ([pscustomobject]@{ status='preserved'; evidence='user data' })
    $newState | ConvertTo-Json -Depth 10 | Set-Content $statePath -Encoding UTF8
    $preservedBytes = [IO.File]::ReadAllBytes($statePath)
    Invoke-MesloFontSetup -RepoPath $testRoot | Out-Null
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) -ne [Convert]::ToBase64String($preservedBytes)) { throw 'Repeat rewrote progress or other component.' }
    $script:registrations.Clear()
    [IO.File]::Delete($status.Target)
    $script:publishFailure = $true
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot } 'native font load failure'
    $failedState = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
    if ($failedState.components.meslo_font.status -ne 'failed' -or $failedState.components.other_component.status -ne 'preserved') { throw 'Failed attempt claimed ready or lost other component.' }
    $script:publishFailure = $false
    if ($script:registrations.Count -or (Test-Path $status.Target)) { throw 'Recorded failure left mock font state.' }
    $stateBefore = [IO.File]::ReadAllText($statePath)
    Invoke-MesloFontSetup -RepoPath $testRoot -Plan | Out-Null
    Expect-Failure { Invoke-MesloFontSetup -RepoPath $testRoot -Check } 'missing or unregistered'
    if ([IO.File]::ReadAllText($statePath) -ne $stateBefore) { throw 'Plan/Check rewrote progress.' }
    Write-Output 'PASS: wrong-host/missing-environment/corrupt progress blocked; ready/failed recorded, other components preserved, repeat and Plan/Check do not rewrite.'
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts/setup-meslo-font.ps1'), [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count) { throw 'Font helper parser errors.' }
    Write-Output 'PASS: helper syntax. No real font files, registry, network, native APIs or environment records changed.'
} finally {
    $env:LOCALAPPDATA = $oldLocal
    $env:OS = $oldOS
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.local')) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe temporary cleanup target.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
#Requires -Version 5.1
# Version routing with empty fixture binaries and mocked process/CLI boundaries.
# No real psmux executable, server, profile or installation is touched.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Native Windows is required.' }
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $env:TEMP ('dotfiles-psmux-routing-' + [guid]::NewGuid())
$runtime = Join-Path $testRoot 'powershell/psmux.ps1'
New-Item -ItemType Directory -Path (Split-Path -Parent $runtime),(Join-Path $testRoot '.local'),(Join-Path $testRoot 'tmux') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'powershell/psmux.ps1') -Destination $runtime
foreach ($version in @('3.3.8','3.4.0')) {
    $bin = Join-Path $testRoot "Programs/psmux/$version"
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    foreach ($name in @('psmux.exe','tmux.exe')) { [IO.File]::WriteAllBytes((Join-Path $bin $name), [byte[]]@()) }
}
$selectionPath = Join-Path $testRoot '.local/environment.json'
$featurePath = Join-Path $testRoot '.local/psmux.json'
$selection = @{schemaVersion=1;environment='windows-powershell';host=[Environment]::MachineName;approved=$true}
# Deliberately omit a feature version marker: it must not imply legacy routing.
$feature = @{schemaVersion=1;host=[Environment]::MachineName;enabled=$true}
function Save-TestRecords {
    $selection | ConvertTo-Json | Set-Content -LiteralPath $selectionPath -Encoding UTF8
    $feature | ConvertTo-Json | Set-Content -LiteralPath $featurePath -Encoding UTF8
}
Save-TestRecords
$environmentNames = @('LOCALAPPDATA','Path','TMUX','PSMUX_SESSION','PSMUX_CONFIG_FILE','DOTFILES_ROOT','DOTFILES_PSMUX_VERSION','PSMUX_DATA_DIR')
$savedEnvironment = @{}
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$global:DotfilesRoutingProcessPath = $null
$global:DotfilesRoutingProcessFailure = $false
$global:DotfilesRoutingUnreadablePath = $false
$global:DotfilesRoutingProcessReads = 0
function global:Get-Process {
    param([int]$Id, [object]$ErrorAction)
    $global:DotfilesRoutingProcessReads++
    if ($Id -ne 4242 -or $global:DotfilesRoutingProcessFailure) { throw 'Fixture process is no longer running.' }
    if ($global:DotfilesRoutingUnreadablePath) {
        $result = [pscustomobject]@{}
        $result | Add-Member -MemberType ScriptProperty -Name Path -Value { throw 'Fixture process path access denied.' }
        return $result
    }
    [pscustomobject]@{Path=$global:DotfilesRoutingProcessPath}
}
# User commands are deliberately preserved across every profile reload.
function global:mux { 'user-mux' }
function global:t { 'user-project' }
function Reset-TestEnvironment {
    $env:LOCALAPPDATA = $testRoot
    $env:Path = $savedEnvironment['Path']
    $env:TMUX = $null
    $env:PSMUX_SESSION = $null
    $env:PSMUX_CONFIG_FILE = $null
    $env:DOTFILES_ROOT = $null
    $env:DOTFILES_PSMUX_VERSION = $null
    $env:PSMUX_DATA_DIR = $null
    $global:DotfilesRoutingProcessPath = $null
    $global:DotfilesRoutingProcessFailure = $false
    $global:DotfilesRoutingUnreadablePath = $false
    $global:DotfilesRoutingProcessReads = 0
}
function Set-TestPane {
    param([string]$Version, [string]$Executable='psmux.exe')
    $env:TMUX = '/tmp/psmux-4242/default,12345,0'
    $env:PSMUX_SESSION = 'fixture'
    $env:DOTFILES_ROOT = $testRoot
    $env:PSMUX_CONFIG_FILE = Join-Path $testRoot 'tmux/psmux.conf'
    $global:DotfilesRoutingProcessPath = Join-Path $testRoot "Programs/psmux/$Version/$Executable"
}
function Assert-BlockedWithoutChanges {
    param([string]$ExpectedReason)
    $snapshot = @{}
    foreach ($name in $environmentNames) { $snapshot[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
    $hashes = @((Get-FileHash -LiteralPath $selectionPath).Hash, (Get-FileHash -LiteralPath $featurePath).Hash)
    $output = . $runtime
    if ($output) { throw 'Blocked runtime emitted profile output.' }
    $status = Get-DotfilesMuxStatus
    if ($status.Status -ne 'Blocked' -or $status.Reason -notmatch $ExpectedReason) { throw "Unexpected blocked status: $($status.Reason)" }
    foreach ($name in $environmentNames) {
        if ($snapshot[$name] -cne [Environment]::GetEnvironmentVariable($name,'Process')) { throw "Blocked runtime changed $name." }
    }
    if ($hashes[0] -ne (Get-FileHash -LiteralPath $selectionPath).Hash -or $hashes[1] -ne (Get-FileHash -LiteralPath $featurePath).Hash) { throw 'Diagnostics changed approval records.' }
    if (Test-DotfilesMuxPane) { throw 'Blocked runtime claimed the current pane.' }
    # Exercise the stale function retained by a previously approved profile.
    # Mock its native boundary so a missing fail-closed check cannot launch any
    # executable, including the empty fixture files.
    $body = (Get-Item Function:\Invoke-DotfilesMux).ScriptBlock.ToString().Replace('& $muxExe', 'Invoke-TestMuxCLI')
    Set-Item Function:\global:Invoke-DotfilesMux -Value ([scriptblock]::Create($body))
    function global:Invoke-TestMuxCLI { throw 'Blocked route reached native CLI boundary.' }
    $rejected = $false
    try { Invoke-DotfilesMux -Session 'blocked-fixture' -Path $testRoot }
    catch {
        if ($_.Exception.Message -notmatch $ExpectedReason) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Blocked route allowed mux invocation.' }
}
try {
    Reset-TestEnvironment
    . $runtime
    $status = Get-DotfilesMuxStatus
    $expectedData = Join-Path $testRoot 'psmux/3.4.0'
    if ($status.Status -ne 'Ready' -or $status.PinnedVersion -ne '3.4.0' -or $status.ActiveVersion -ne '3.4.0' -or $status.IsLegacy) { throw 'Outside-pane pinned routing failed.' }
    if ($env:PSMUX_DATA_DIR -ne $expectedData -or $status.DataDirectory -ne $expectedData) { throw 'New default data namespace was not selected.' }
    if ($global:DotfilesRoutingProcessReads) { throw 'Outside-pane routing probed a server process.' }
    if ($env:DOTFILES_PSMUX_VERSION -ne '3.4.0' -or ($env:Path -split ';')[0] -ne (Join-Path $testRoot 'Programs/psmux/3.4.0')) { throw 'New binary route not exported.' }
    if ((mux) -ne 'user-mux' -or (t) -ne 'user-project') { throw 'Existing user commands were replaced.' }
    Reset-TestEnvironment
    $env:PSMUX_DATA_DIR = Join-Path $testRoot 'private-custom-data'
    . $runtime
    if ($env:PSMUX_DATA_DIR -ne (Join-Path $testRoot 'private-custom-data')) { throw 'Explicit private data root changed.' }
    if (Test-Path -LiteralPath $env:PSMUX_DATA_DIR) { throw 'Runtime created a data directory.' }
    Write-Output 'PASS: new pinned route defaults only absent data root and preserves explicit roots without creating directories.'

    foreach ($version in @('3.3.8','3.4.0')) {
        foreach ($executable in @('psmux.exe','tmux.exe')) {
            Reset-TestEnvironment
            Set-TestPane -Version $version -Executable $executable
            # An informative marker cannot override the authoritative PID path.
            $env:DOTFILES_PSMUX_VERSION = 'not-authoritative'
            . $runtime
            $status = Get-DotfilesMuxStatus
            if ($status.Status -ne 'Ready' -or $status.ActiveVersion -ne $version -or $status.IsLegacy -ne ($version -eq '3.3.8')) { throw "Server process routing failed: $version/$executable" }
            if ($version -eq '3.3.8' -and ($status.Reason -notmatch 'Legacy 3.3.8 server retained' -or $status.Action -notmatch 'outside mux for 3.4.0')) { throw 'Legacy readiness implies upgrade completion.' }
            if ($env:PSMUX_DATA_DIR -or $status.DataDirectory) { throw 'Inside-pane routing inferred a missing data root.' }
            if ($env:DOTFILES_PSMUX_VERSION -ne $version -or ($env:Path -split ';')[0] -ne (Join-Path $testRoot "Programs/psmux/$version")) { throw 'Server binary route not retained.' }
            if (-not (Test-DotfilesMuxPane)) { throw 'Known owned server pane rejected.' }
            $env:PSMUX_DATA_DIR = Join-Path $testRoot "private-$version"
            . $runtime
            if ($env:PSMUX_DATA_DIR -ne (Join-Path $testRoot "private-$version")) { throw 'Inside-pane explicit data root changed.' }
        }
    }
    Write-Output 'PASS: known old/new psmux.exe and tmux.exe PID paths route correctly; legacy absent roots stay absent.'

    Reset-TestEnvironment; Set-TestPane -Version '9.9.9'
    Assert-BlockedWithoutChanges -ExpectedReason 'not a known installed version'
    Reset-TestEnvironment; Set-TestPane -Version '3.4.0'
    $global:DotfilesRoutingProcessFailure = $true
    Assert-BlockedWithoutChanges -ExpectedReason 'process is unavailable'
    Reset-TestEnvironment; Set-TestPane -Version '3.4.0'
    $global:DotfilesRoutingUnreadablePath = $true
    Assert-BlockedWithoutChanges -ExpectedReason 'path cannot be read'
    Reset-TestEnvironment; Set-TestPane -Version '3.4.0'
    $global:DotfilesRoutingProcessPath = $null
    Assert-BlockedWithoutChanges -ExpectedReason 'path cannot be read'
    Reset-TestEnvironment; Set-TestPane -Version '3.4.0'
    $env:PSMUX_CONFIG_FILE = Join-Path $testRoot 'foreign/psmux.conf'
    Assert-BlockedWithoutChanges -ExpectedReason 'another or unrecognized'
    if ($global:DotfilesRoutingProcessReads) { throw 'Foreign config reached process lookup.' }
    Reset-TestEnvironment; Set-TestPane -Version '3.4.0'
    $env:TMUX = '/tmp/psmux-4242/named,12345,0'
    Assert-BlockedWithoutChanges -ExpectedReason 'another or unrecognized'
    Reset-TestEnvironment; Set-TestPane -Version '3.4.0'
    $env:PSMUX_SESSION = $null
    Assert-BlockedWithoutChanges -ExpectedReason 'another or unrecognized'
    Write-Output 'PASS: unknown, dead, unreadable and foreign servers are blocked without environment or PATH changes.'

    Reset-TestEnvironment
    $selection.approved = 'true'; Save-TestRecords
    Assert-BlockedWithoutChanges -ExpectedReason 'boolean true'
    $selection.approved = $true; $selection.host='different-host'; Save-TestRecords
    Assert-BlockedWithoutChanges -ExpectedReason 'host differs'
    $selection.host=[Environment]::MachineName; $feature.enabled=$false; Save-TestRecords
    Assert-BlockedWithoutChanges -ExpectedReason 'activation must be boolean true'
    $feature.enabled=$true; Save-TestRecords
    Write-Output 'PASS: approval and feature failures cannot select PATH or data namespaces.'

    # Replace only the native CLI boundary in the real function body. Empty
    # fixture .exe files are never launched. Mixed versions must fail before
    # show-environment, binding edits or attach/switch are attempted.
    Reset-TestEnvironment
    $env:PSMUX_DATA_DIR = Join-Path $testRoot 'explicit-shared-root'
    . $runtime
    $invokeSource = (Get-Item Function:\Invoke-DotfilesMux).ScriptBlock.ToString().Replace('& $muxExe', 'Invoke-TestMuxCLI')
    Set-Item Function:\global:Invoke-DotfilesMux -Value ([scriptblock]::Create($invokeSource))
    $global:DotfilesRoutingCliCommands = @()
    function global:Invoke-TestMuxCLI {
        $global:LASTEXITCODE = 0
        $global:DotfilesRoutingCliCommands += ($args -join ' ')
        if ($args -contains 'display-message') { return '3.3.8' }
    }
    $rejected = $false
    try { Invoke-DotfilesMux -Session 'fixture' -Path $testRoot }
    catch {
        if ($_.Exception.Message -notmatch 'different or unknown psmux version') { throw }
        $rejected = $true
    }
    if (-not $rejected -or $global:DotfilesRoutingCliCommands.Count -ne 2 -or
        $global:DotfilesRoutingCliCommands[-1] -notmatch 'display-message') { throw 'Mixed version reached session mutation or attach.' }
    Write-Output 'PASS: shared-root server version mismatch is rejected before configuration or attachment.'

    # psmux 3.4.0 reports the startup config only in the global environment.
    # Our own server must be adopted; a foreign global marker must still fail
    # before any binding edit or attachment.
    $ownConfig = 'PSMUX_CONFIG_FILE=' + (Join-Path $testRoot 'tmux/psmux.conf')
    foreach ($fixture in @(
        @{ Label='session marker'; Session=@($ownConfig); Global=@(); Owned=$true },
        @{ Label='global-only marker'; Session=@('TERM=xterm-256color'); Global=@($ownConfig); Owned=$true },
        @{ Label='foreign global marker'; Session=@('TERM=xterm-256color'); Global=@('PSMUX_CONFIG_FILE=' + (Join-Path $testRoot 'foreign/psmux.conf')); Owned=$false },
        @{ Label='missing marker'; Session=@(); Global=@(); Owned=$false })) {
        $global:DotfilesRoutingFixture = $fixture
        $global:DotfilesRoutingCliCommands = @()
        $global:DotfilesRoutingBindingFile = $null
        $global:DotfilesRoutingBindings = $null
        function global:Invoke-TestMuxCLI {
            $global:LASTEXITCODE = 0
            $global:DotfilesRoutingCliCommands += ($args -join ' ')
            if ($args -contains 'display-message') { return '3.4.0' }
            if ($args -contains 'show-environment') {
                if ($args -contains '-g') { return $global:DotfilesRoutingFixture.Global }
                return $global:DotfilesRoutingFixture.Session
            }
            if ($args -contains 'source-file') {
                $global:DotfilesRoutingBindingFile = $args[-1]
                $global:DotfilesRoutingBindings = [IO.File]::ReadAllText($args[-1])
            }
        }
        $failure = $null
        try { Invoke-DotfilesMux -Session 'fixture' -Path $testRoot } catch { $failure = $_.Exception.Message }
        $attached = @($global:DotfilesRoutingCliCommands | Where-Object { $_ -match 'attach-session|switch-client' }).Count
        $configured = @($global:DotfilesRoutingCliCommands | Where-Object { $_ -match 'bind-key|source-file' }).Count
        if ($fixture.Owned) {
            if ($failure -or $attached -ne 1 -or $configured -ne 1) { throw "Owned server rejected ($($fixture.Label)): $failure" }
            $bindings = $global:DotfilesRoutingBindings
            if ($bindings -notmatch "(?m)^bind-key -r F new-window -c '#\{pane_current_path\}' '[^']+ -NoLogo -NoExit -Command t'$" -or
                $bindings -notmatch "(?m)^bind-key -r D new-window '[^']+ -Command Invoke-DotfilesConfigProject'$" -or
                $bindings -notmatch "(?m)^bind-key r source-file '[^']+psmux\.conf' \\; bind-key -r F .+ \\; bind-key -r D .+$" -or
                $bindings[0] -eq [char]0xFEFF) { throw "Binding file content is wrong ($($fixture.Label))." }
            if (Test-Path -LiteralPath $global:DotfilesRoutingBindingFile) { throw 'Temporary binding file was left behind.' }
        } elseif ($failure -notmatch 'another configuration' -or $attached -or $configured) {
            throw "Foreign server accepted or mutated ($($fixture.Label))."
        }
    }
    Write-Output 'PASS: config ownership reads session or 3.4.0 global markers; owned servers get F/D/reload through one removed config file.'
} finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name,$savedEnvironment[$name],'Process') }
    Remove-Item Function:\global:Get-Process -ErrorAction SilentlyContinue
    Remove-Item Function:\global:Invoke-TestMuxCLI -ErrorAction SilentlyContinue
}
Write-Output 'PASS: version routing uses fixture files only; no real psmux executable or server was invoked.'

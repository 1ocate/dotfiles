#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Plan, [switch]$Check, [switch]$ApprovePowerShell)

function Get-MesloFontManifest {
    param([string]$RepoPath)
    $manifest = [IO.File]::ReadAllText((Join-Path $RepoPath 'fonts/meslo.json')) | ConvertFrom-Json
    if ($manifest.file_name -ne 'MesloLGMDZNerdFontMono-Regular.ttf' -or
        $manifest.family -ne 'MesloLGMDZ Nerd Font Mono' -or
        $manifest.full_name -ne 'MesloLGMDZ Nerd Font Mono Regular' -or
        $manifest.sha256 -notmatch '^[a-f0-9]{64}$' -or
        $manifest.upstream_commit -notmatch '^[a-f0-9]{40}$' -or
        $manifest.url -ne ('https://raw.githubusercontent.com/ryanoasis/nerd-fonts/' + $manifest.upstream_commit + '/patched-fonts/Meslo/M-DZ/' + $manifest.file_name)) {
        throw 'Invalid pinned Meslo Mono font manifest.'
    }
    return $manifest
}

function Get-MesloFontRegistration {
    param([string]$Name, [ValidateSet('User', 'Machine')][string]$Scope)
    $hive = if ($Scope -eq 'User') { 'HKCU:' } else { 'HKLM:' }
    $key = $hive + '\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $properties = Get-ItemProperty -LiteralPath $key
    $property = $properties.PSObject.Properties[$Name]
    if ($property) { return [string]$property.Value }
    return $null
}

function Get-MesloFontStatus {
    param($Manifest)
    if ($env:OS -ne 'Windows_NT') { throw 'Meslo installation requires native Windows.' }
    if (-not $env:LOCALAPPDATA -or -not [IO.Path]::IsPathRooted($env:LOCALAPPDATA)) { throw 'Invalid LOCALAPPDATA.' }
    $target = Join-Path $env:LOCALAPPDATA ('Microsoft/Windows/Fonts/' + $Manifest.file_name)
    $name = $Manifest.full_name + ' (TrueType)'
    $userValue = Get-MesloFontRegistration -Name $name -Scope User
    $machineValue = Get-MesloFontRegistration -Name $name -Scope Machine
    $readyRegistrations = @()
    foreach ($registration in @(@{ Value = $userValue; Scope = 'User' }, @{ Value = $machineValue; Scope = 'Machine' })) {
        if ($null -eq $registration.Value) { continue }
        if ([string]::IsNullOrWhiteSpace($registration.Value)) { throw 'Existing font registration is empty; preserve and resolve it explicitly before retrying.' }
        $path = [Environment]::ExpandEnvironmentVariables($registration.Value)
        if (-not [IO.Path]::IsPathRooted($path)) {
            if ($registration.Scope -eq 'Machine') { $path = Join-Path (Join-Path $env:WINDIR 'Fonts') $path }
            else { throw 'Existing user font registration has a relative path; preserve it and resolve the conflict manually.' }
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $Manifest.sha256) {
            throw "Existing $($registration.Scope) font registration conflicts with the pinned asset: $path. Preserve/remove it explicitly before retrying, or use -SkipFonts in setup-windows.ps1."
        }
        $readyRegistrations += [pscustomobject]@{ Status = 'Ready'; Target = $path; Registered = $true; Scope = $registration.Scope; RegistryName = $name }
    }
    if ($readyRegistrations.Count) { return $readyRegistrations[0] }
    $exists = Test-Path -LiteralPath $target
    if ($exists -and (-not (Test-Path -LiteralPath $target -PathType Leaf) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $Manifest.sha256)) {
        throw "Existing font target conflicts with the pinned asset: $target. It will not be overwritten; resolve explicitly or use -SkipFonts."
    }
    return [pscustomobject]@{ Status = $(if ($exists) { 'Unregistered' } else { 'Missing' }); Target = $target; Registered = $false; Scope = 'User'; RegistryName = $name }
}

function Receive-MesloFont {
    param([string]$Url, [string]$Destination)
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    } finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
}

function Set-MesloFontRegistration {
    param([string]$Name, [string]$Target)
    $key = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    if ($null -ne (Get-MesloFontRegistration -Name $Name -Scope User)) { throw 'Font registration appeared concurrently; nothing was overwritten.' }
    New-ItemProperty -LiteralPath $key -Name $Name -Value $Target -PropertyType String | Out-Null
}

function Remove-MesloFontRegistration {
    param([string]$Name)
    Remove-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $Name
}

function Publish-MesloFontChange {
    param([string]$Target)
    if (-not ('Dotfiles.MesloNative' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace Dotfiles {
    public static class MesloNative {
        [DllImport("gdi32.dll", CharSet=CharSet.Unicode)]
        public static extern int AddFontResourceW(string path);
        [DllImport("gdi32.dll", CharSet=CharSet.Unicode)]
        public static extern bool RemoveFontResourceW(string path);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)]
        public static extern bool SendNotifyMessageW(IntPtr hwnd, uint msg, UIntPtr wparam, IntPtr lparam);
    }
}
"@
    }
    if ([Dotfiles.MesloNative]::AddFontResourceW($Target) -eq 0) { throw 'Windows could not load the font; no successful installation is reported.' }
    if (-not [Dotfiles.MesloNative]::SendNotifyMessageW([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero)) {
        Write-Warning 'WM_FONTCHANGE notification failed. Restart terminal applications before using the font.'
    }
}

function Undo-MesloFontChange {
    param([string]$Target)
    if ('Dotfiles.MesloNative' -as [type]) {
        $null = [Dotfiles.MesloNative]::RemoveFontResourceW($Target)
        $null = [Dotfiles.MesloNative]::SendNotifyMessageW([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero)
    }
}

function Install-MesloFont {
    param([string]$RepoPath, $Manifest, $Status)
    if ($Status.Registered) { Write-Output 'Pinned Meslo Mono font and registry registration already verified.'; return }
    $temporary = $null
    $createdFile = $false
    $createdRegistration = $false
    $loaded = $false
    try {
        if ($Status.Status -eq 'Missing') {
            $local = Join-Path $RepoPath '.local'
            New-Item -ItemType Directory -Path $local -Force | Out-Null
            $temporary = Join-Path $local ('meslo-download-' + [guid]::NewGuid().ToString('N') + '.ttf')
            Receive-MesloFont -Url $Manifest.url -Destination $temporary
            if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $Manifest.sha256) { throw 'Font SHA256 mismatch. No font file or registration has been installed.' }
            New-Item -ItemType Directory -Path (Split-Path -Parent $Status.Target) -Force | Out-Null
            [IO.File]::Move($temporary, $Status.Target)
            $temporary = $null
            $createdFile = $true
        }
        if ((Get-FileHash -LiteralPath $Status.Target -Algorithm SHA256).Hash -ne $Manifest.sha256) { throw 'Font changed before registration.' }
        Set-MesloFontRegistration -Name $Status.RegistryName -Target $Status.Target
        $createdRegistration = $true
        Publish-MesloFontChange -Target $Status.Target
        $loaded = $true
        $verified = Get-MesloFontStatus -Manifest $Manifest
        if (-not $verified.Registered) { throw 'Font registration verification failed.' }
        Write-Output 'Pinned Meslo Mono font installed for the current user and registration verified. Open a new terminal process.'
    } catch {
        $originalError = $_
        if ($loaded) {
            try { Undo-MesloFontChange -Target $Status.Target }
            catch { Write-Warning ('Font load rollback failed; inspect the newly created state: ' + $_.Exception.Message) }
        }
        if ($createdRegistration) {
            try {
                if ((Get-MesloFontRegistration -Name $Status.RegistryName -Scope User) -eq $Status.Target) { Remove-MesloFontRegistration -Name $Status.RegistryName }
                else { Write-Warning 'Font registry changed concurrently; preserve it and inspect the partial setup manually.' }
            } catch { Write-Warning ('Font registry rollback failed; inspect the newly created state: ' + $_.Exception.Message) }
        }
        if ($createdFile -and (Test-Path -LiteralPath $Status.Target -PathType Leaf)) {
            try {
                if ((Get-FileHash -LiteralPath $Status.Target -Algorithm SHA256).Hash -eq $Manifest.sha256) { [IO.File]::Delete($Status.Target) }
                else { Write-Warning 'Font file changed concurrently; preserve it and inspect the partial setup manually.' }
            } catch { Write-Warning ('Font file rollback failed; inspect the newly created state: ' + $_.Exception.Message) }
        }
        throw $originalError
    } finally {
        if ($temporary -and (Test-Path -LiteralPath $temporary -PathType Leaf)) {
            try { [IO.File]::Delete($temporary) }
            catch { Write-Warning ('Temporary font cleanup failed; remove only this ignored download after review: ' + $temporary) }
        }
    }
}

function Get-MesloFontProgress {
    param([string]$RepoPath)
    $path = Join-Path $RepoPath '.local/setup-state.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ scope = 'local'; environment = 'windows-powershell'; host = [Environment]::MachineName; components = [pscustomobject]@{} }
    }
    try { $state = [IO.File]::ReadAllText($path) | ConvertFrom-Json }
    catch { throw 'Invalid setup-state JSON. Preserve and repair it explicitly before font installation.' }
    if ($state -isnot [pscustomobject] -or $state.components -isnot [pscustomobject] -or
        $state.host -ne [Environment]::MachineName -or $state.environment -ne 'windows-powershell') {
        throw 'Font setup-state belongs to another host/environment or has invalid components. Preserve and repair/archive it explicitly before font installation; no font changes were made.'
    }
    return $state
}

function Write-MesloFontProgress {
    param([string]$RepoPath, $Manifest, $FontStatus, [ValidateSet('ready','failed')][string]$Status, [string]$Failure)
    # Re-read to preserve any other component completed since the initial guard.
    $state = Get-MesloFontProgress -RepoPath $RepoPath
    $component = [pscustomobject]@{
        status = $Status; host = [Environment]::MachineName;
        source = (Join-Path $RepoPath 'fonts/meslo.json'); target = $FontStatus.Target;
        upstream_commit = $Manifest.upstream_commit; sha256 = $Manifest.sha256;
        registry_scope = $FontStatus.Scope; registry_name = $FontStatus.RegistryName;
        verification = $(if ($Status -eq 'ready') { 'Exact asset hash and font registration verified. Newly registered fonts requested native loading and WM_FONTCHANGE; pre-existing fonts reused. Terminal GUI and fresh-machine installation are not verified.' } else { 'Installation failed; no successful font completion recorded. Inspect any rollback warnings and actual file/registry state before retrying.' });
        failure = $Failure; checked_at = (Get-Date -Format o)
    }
    $previous = $state.components.meslo_font
    $same = $null -ne $previous
    foreach ($name in @('status','host','source','target','upstream_commit','sha256','registry_scope','registry_name','verification','failure')) {
        if (-not $previous -or $previous.$name -ne $component.$name) { $same = $false }
    }
    if ($same) { return }
    $state.components | Add-Member -NotePropertyName meslo_font -NotePropertyValue $component -Force
    $directory = Join-Path $RepoPath '.local'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $directory 'setup-state.json') -Encoding UTF8
}

function Invoke-MesloFontSetup {
    param([string]$RepoPath, [switch]$Plan, [switch]$Check, [switch]$ApprovePowerShell)
    if ($Plan -and $Check) { throw 'Plan and Check cannot be combined.' }
    if ($env:OS -ne 'Windows_NT') { throw 'Meslo installation requires native Windows.' }
    $manifest = Get-MesloFontManifest -RepoPath $RepoPath
    . (Join-Path $RepoPath 'scripts/windows-environment.ps1')
    if ($Plan -or $Check) {
        Write-WindowsSelectionStatus -RepoPath $RepoPath
        $status = Get-MesloFontStatus -Manifest $manifest
        Write-Output ("Font: $($manifest.family); asset: $($manifest.file_name); status: $($status.Status); target: $($status.Target)")
        Write-Output ("Pinned commit: $($manifest.upstream_commit); SHA256: $($manifest.sha256)")
        if ($Check -and -not $status.Registered) { throw 'Pinned Meslo Mono font is missing or unregistered. Run setup-meslo-font.ps1 to install, or explicitly use -SkipFonts in setup-windows.ps1.' }
        return
    }
    $null = Get-MesloFontProgress -RepoPath $RepoPath
    Assert-WindowsPowerShellSelection -RepoPath $RepoPath -ApprovePowerShell:$ApprovePowerShell
    $status = Get-MesloFontStatus -Manifest $manifest
    try {
        Install-MesloFont -RepoPath $RepoPath -Manifest $manifest -Status $status
        $verified = Get-MesloFontStatus -Manifest $manifest
        Write-MesloFontProgress -RepoPath $RepoPath -Manifest $manifest -FontStatus $verified -Status ready
    } catch {
        $originalError = $_
        try { Write-MesloFontProgress -RepoPath $RepoPath -Manifest $manifest -FontStatus $status -Status failed -Failure $originalError.Exception.Message }
        catch { Write-Warning ('Font progress could not be recorded; inspect local state: ' + $_.Exception.Message) }
        throw $originalError
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    Invoke-MesloFontSetup -RepoPath (Split-Path -Parent $PSScriptRoot) -Plan:$Plan -Check:$Check -ApprovePowerShell:$ApprovePowerShell
}

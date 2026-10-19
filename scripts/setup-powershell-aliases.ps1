#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Plan, [switch]$Check)

# Explicit paths allow temporary-profile verification without touching user profiles.
function Invoke-PowerShellAliasesSetup {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$DocumentsPath, [switch]$Plan, [switch]$Check)
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT') { throw 'PowerShell aliases require native Windows.' }
    if ($Plan -and $Check) { throw 'Plan and Check cannot be combined.' }
    $runtimePath = Join-Path $RepoPath 'powershell/aliases.ps1'
    if (-not [IO.Path]::IsPathRooted($DocumentsPath) -or -not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
        throw 'Alias source or absolute Documents path is unavailable.'
    }
    $loader = ". '" + $runtimePath.Replace("'", "''") + "'"
    $profiles = @('WindowsPowerShell', 'PowerShell') | ForEach-Object { Join-Path $DocumentsPath "$_/Microsoft.PowerShell_profile.ps1" }
    if ($Plan) {
        Write-Output 'Connect both PowerShell profiles to powershell/aliases.ps1: vi and vim launch Neovim; preserve and back up existing profiles.'
        return
    }
    if (-not (Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'Neovim (nvim.exe) is missing. Install it before connecting aliases; no profiles were changed.'
    }
    # Read all profiles before making any changes; retain their original encoding.
    $entries = foreach ($profilePath in $profiles) {
        $existing = ''
        $encoding = [Text.UTF8Encoding]::new($true)
        if (Test-Path -LiteralPath $profilePath) {
            $profileBytes = [IO.File]::ReadAllBytes($profilePath)
            $hasBom = ($profileBytes.Length -ge 3 -and $profileBytes[0] -eq 239 -and $profileBytes[1] -eq 187 -and $profileBytes[2] -eq 191) -or
                ($profileBytes.Length -ge 2 -and (($profileBytes[0] -eq 255 -and $profileBytes[1] -eq 254) -or ($profileBytes[0] -eq 254 -and $profileBytes[1] -eq 255))) -or
                ($profileBytes.Length -ge 4 -and $profileBytes[0] -eq 0 -and $profileBytes[1] -eq 0 -and $profileBytes[2] -eq 254 -and $profileBytes[3] -eq 255)
            if (-not $hasBom -and ((@($profileBytes | Where-Object { $_ -gt 127 }).Count -gt 0) -or $loader -match '[^\x00-\x7f]')) {
                throw 'Profile encoding is ambiguous without a BOM. Back it up and save it as UTF-8 with BOM before linking; no profiles were changed.'
            }
            $reader = [IO.StreamReader]::new($profilePath, $true)
            try { $existing = $reader.ReadToEnd(); $encoding = $reader.CurrentEncoding }
            finally { $reader.Dispose() }
        }
        [pscustomobject]@{Path=$profilePath;Text=$existing;Encoding=$encoding;Linked=(($existing -split '\r?\n') -contains $loader)}
    }
    if ($Check) {
        if (@($entries | Where-Object { -not $_.Linked }).Count) {
            throw 'PowerShell alias loader is missing. Run scripts/setup-powershell-aliases.ps1; no profiles were changed.'
        }
        Write-Output 'Neovim and both profile loaders are available. Runtime aliases still require the current host PowerShell selection.'
        return
    }
    . (Join-Path $RepoPath 'scripts/windows-environment.ps1')
    Assert-WindowsPowerShellSelection -RepoPath $RepoPath
    $statePath = Join-Path $RepoPath '.local/setup-state.json'
    $state = $null
    if (Test-Path -LiteralPath $statePath) {
        $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.host -ne [Environment]::MachineName -or $state.environment -ne 'windows-powershell' -or $state.components -isnot [pscustomobject]) {
            throw 'Alias setup-state belongs to another host/environment or is invalid. Preserve and repair it before applying; no profiles were changed.'
        }
    }
    if (-not $state) {
        $state = [pscustomobject]@{host=[Environment]::MachineName;environment='windows-powershell';components=[pscustomobject]@{}}
    }
    $previous = $state.components.powershell_aliases
    $backups = @()
    if ($previous -and $previous.backups) { $backups += @($previous.backups) }
    $changed = $false
    foreach ($entry in $entries) {
        if ($entry.Linked) { continue }
        if (Test-Path -LiteralPath $entry.Path) {
            $backup = $entry.Path + '.backup-' + [guid]::NewGuid().ToString('N')
            Copy-Item -LiteralPath $entry.Path -Destination $backup
            $backups += $backup
        } else { New-Item -ItemType Directory -Path (Split-Path -Parent $entry.Path) -Force | Out-Null }
        [IO.File]::AppendAllText($entry.Path, "`r`n" + $loader + "`r`n", $entry.Encoding)
        $changed = $true
    }
    foreach ($profilePath in $profiles) {
        if (([IO.File]::ReadAllText($profilePath) -split '\r?\n') -notcontains $loader) { throw 'Alias profile loader verification failed.' }
    }
    if ($changed -or -not $previous -or $previous.source -ne $runtimePath -or $previous.status -ne 'linked' -or
        (@($previous.profiles) -join '|') -ne ($profiles -join '|')) {
        $component = [pscustomobject]@{status='linked';source=$runtimePath;profiles=@($profiles);backups=$backups;checked_at=(Get-Date -Format o);
            verification='Both profile loaders verified. Open a new PowerShell session to verify vi/vim command resolution; GUI editing is not verified.'}
        $state.components | Add-Member -NotePropertyName powershell_aliases -NotePropertyValue $component -Force
        if (Test-Path -LiteralPath $statePath) { Copy-Item -LiteralPath $statePath -Destination ($statePath + '.backup-' + [guid]::NewGuid().ToString('N')) }
        $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding UTF8
    }
    Write-Output 'Neovim aliases connected. Open a new PowerShell session, or dot-source powershell/aliases.ps1 in the current session.'
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-PowerShellAliasesSetup -RepoPath (Split-Path -Parent $PSScriptRoot) -DocumentsPath ([Environment]::GetFolderPath('MyDocuments')) -Plan:$Plan -Check:$Check
}

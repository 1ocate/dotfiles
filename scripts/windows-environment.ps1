#Requires -Version 5.1
# Shared guard for native Windows setup entry points. No changes when dot-sourced.
function Get-WindowsEnvironmentSelection {
    param([Parameter(Mandatory = $true)][string]$RepoPath)
    $statePath = Join-Path $RepoPath '.local/environment.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return $null }
    try { $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw 'Invalid local environment selection. Review .local/environment.json before setup.' }
    if ($state -isnot [pscustomobject]) { throw 'Local environment selection must be a JSON object.' }
    return $state
}
function Write-WindowsSelectionStatus {
    param([Parameter(Mandatory = $true)][string]$RepoPath)
    $state = Get-WindowsEnvironmentSelection -RepoPath $RepoPath
    if ($state) { Write-Output "Saved environment: $($state.environment); host: $($state.host). Installation will validate approval and host match." }
    else { Write-Output 'No saved environment. Installation requires an explicit windows-powershell selection (-ApprovePowerShell).' }
}
function Assert-WindowsPowerShellSelection {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [switch]$ApprovePowerShell
    )
    if ($env:OS -ne 'Windows_NT') { throw 'This adapter requires native Windows; WSL/macOS/Linux are not targets.' }
    $statePath = Join-Path $RepoPath '.local/environment.json'
    $state = Get-WindowsEnvironmentSelection -RepoPath $RepoPath
    $sameSelection = $state -and $state.environment -eq 'windows-powershell' -and
        $state.host -eq [Environment]::MachineName -and $state.approved -is [bool] -and $state.approved -eq $true
    if (-not $ApprovePowerShell -and -not $sameSelection) {
        if ($state -and $state.environment -eq 'windows-wsl') {
            throw 'Saved selection is windows-wsl. PowerShell is not approved; run the WSL setup or explicitly approve an environment change.'
        }
        throw 'PowerShell environment is not approved for this host. Review -Plan, then pass -ApprovePowerShell to explicitly select native Windows. No installation or configuration has been changed.'
    }
    if ($sameSelection) {
        Write-Output "Reusing saved selection: windows-powershell ($statePath)"
        return
    }
    # This flag is an explicit user choice, not inferred from OS or shell detection.
    New-Item -ItemType Directory -Path (Split-Path -Parent $statePath) -Force | Out-Null
    if (Test-Path -LiteralPath $statePath) {
        Copy-Item -LiteralPath $statePath -Destination ($statePath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    }
    $choice = [ordered]@{
        environment = 'windows-powershell'
        host = [Environment]::MachineName
        approved = $true
        approvedAt = [DateTime]::UtcNow.ToString('o')
        approvalSource = 'explicit -ApprovePowerShell'
    }
    [System.IO.File]::WriteAllText($statePath, ($choice | ConvertTo-Json) + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Output "Saved selection: windows-powershell ($statePath)"
}

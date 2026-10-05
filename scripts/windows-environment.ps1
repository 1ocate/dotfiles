#Requires -Version 5.1
# Windows adapter for the common registration tool; owns no state format or writer.
function Invoke-DotfilesEnvironment {
    param([string]$RepoPath, [string[]]$CommandArguments)
    $script = Join-Path $RepoPath 'scripts/environment.py'
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'Common scripts/environment.py is missing.' }
    $python = Get-Command py -ErrorAction SilentlyContinue
    $prefix = @('-3')
    if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue; $prefix = @() }
    if (-not $python) { throw 'Python 3.10+ is required for common environment registration before Windows installation.' }
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $python.Source @prefix $script @CommandArguments 2>&1 | ForEach-Object { $_.ToString() }
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldPreference }
    if ($exitCode -ne 0) { throw ('Environment registration failed: ' + ($output -join "`n")) }
    return ($output -join "`n") | ConvertFrom-Json
}
function Get-WindowsEnvironmentSelection {
    param([Parameter(Mandatory = $true)][string]$RepoPath)
    return (Invoke-DotfilesEnvironment -RepoPath $RepoPath -CommandArguments @('status')).selection
}
function Write-WindowsSelectionStatus {
    param([Parameter(Mandatory = $true)][string]$RepoPath)
    $state = Get-WindowsEnvironmentSelection -RepoPath $RepoPath
    if ($state) { Write-Output "Saved environment: $($state.environment); host: $($state.host). Installation will validate approval and host match." }
    else { Write-Output 'No saved environment. Register explicitly with scripts/environment.py or use -ApprovePowerShell.' }
}
function Assert-WindowsPowerShellSelection {
    param([Parameter(Mandatory = $true)][string]$RepoPath, [switch]$ApprovePowerShell)
    if ($env:OS -ne 'Windows_NT') { throw 'This adapter requires native Windows; WSL/macOS/Linux are not targets.' }
    if ($ApprovePowerShell) {
        $registered = Invoke-DotfilesEnvironment -RepoPath $RepoPath -CommandArguments @('select', '--environment', 'windows-powershell')
        Write-Output "Environment selection $($registered.result): windows-powershell"
    }
    $null = Invoke-DotfilesEnvironment -RepoPath $RepoPath -CommandArguments @('require', '--environment', 'windows-powershell')
    Write-Output 'Reusing approved common environment selection: windows-powershell'
}

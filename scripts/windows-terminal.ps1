#Requires -Version 5.1
# Directory-junction helpers only; dot-sourcing has no installation side effects.
function Get-WindowsTerminalTarget {
    param([ValidateSet('stable', 'preview', 'unpackaged')][string]$Channel = 'stable')
    if ($env:OS -ne 'Windows_NT') { throw 'Windows Terminal requires native Windows.' }
    if (-not $env:LOCALAPPDATA -or -not [IO.Path]::IsPathRooted($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA must be an absolute Windows path.' }
    switch ($Channel) {
        'stable' { $relative = 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json' }
        'preview' { $relative = 'Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json' }
        'unpackaged' { $relative = 'Microsoft/Windows Terminal/settings.json' }
    }
    return [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA $relative))
}

function Get-WindowsTerminalConnection {
    param([Parameter(Mandatory=$true)][string]$SourcePath, [Parameter(Mandatory=$true)][string]$TargetPath)
    $source = [IO.Path]::GetFullPath($SourcePath)
    $target = [IO.Path]::GetFullPath($TargetPath)
    $sourceDirectory = Split-Path -Parent $source
    $targetDirectory = Split-Path -Parent $target
    $separator = [IO.Path]::DirectorySeparatorChar
    if ($sourceDirectory -eq $targetDirectory -or $sourceDirectory.StartsWith($targetDirectory + $separator, [StringComparison]::OrdinalIgnoreCase) -or $targetDirectory.StartsWith($sourceDirectory + $separator, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Windows Terminal source and target directories must be separate and non-nested.'
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Windows Terminal JSON source is missing.' }
    $null = [IO.File]::ReadAllText($source) | ConvertFrom-Json -ErrorAction Stop
    $item = Get-Item -LiteralPath $targetDirectory -Force -ErrorAction SilentlyContinue
    $status = 'not-linked'
    if ($item) {
        if (-not $item.PSIsContainer) { throw 'Windows Terminal settings directory is a file; it was not changed.' }
        if ($item.LinkType -eq 'Junction') {
            $link = [string](@($item.Target)[0])
            if ([IO.Path]::GetFullPath($link).TrimEnd('\') -eq $sourceDirectory.TrimEnd('\')) { $status = 'linked' }
            else { $status = 'other-link' }
        } elseif ($item.LinkType) { $status = 'other-link' }
        else { $status = 'existing-directory' }
    }
    return [pscustomobject]@{Source=$source;Target=$target;SourceDirectory=$sourceDirectory;TargetDirectory=$targetDirectory;Status=$status}
}

function New-WindowsTerminalDirectoryLink {
    param([string]$LinkPath, [string]$SourceDirectory)
    New-Item -ItemType Junction -Path $LinkPath -Value $SourceDirectory -ErrorAction Stop | Out-Null
}

function Connect-WindowsTerminalSource {
    param([Parameter(Mandatory=$true)][string]$SourcePath, [Parameter(Mandatory=$true)][string]$TargetPath)
    if ($env:OS -ne 'Windows_NT') { throw 'Windows Terminal requires native Windows.' }
    $connection = Get-WindowsTerminalConnection -SourcePath $SourcePath -TargetPath $TargetPath
    if ($connection.Status -eq 'linked') { return $connection }
    $parent = Split-Path -Parent $connection.TargetDirectory
    if (-not $parent -or $connection.TargetDirectory -eq [IO.Path]::GetPathRoot($connection.TargetDirectory)) { throw 'Refusing a root-directory settings target.' }
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $stage = Join-Path $parent ('dotfiles-terminal-junction-' + [guid]::NewGuid().ToString('N'))
    $backup = $null
    # Create the junction before moving existing settings. No elevated privileges,
    # policy changes, recursive deletes, or copies of the configuration are used.
    New-WindowsTerminalDirectoryLink -LinkPath $stage -SourceDirectory $connection.SourceDirectory
    try {
        if (Get-Item -LiteralPath $connection.TargetDirectory -Force -ErrorAction SilentlyContinue) {
            $backup = $connection.TargetDirectory + '.backup-' + [guid]::NewGuid().ToString('N')
            # Resolved absolute source/backup share this explicit settings parent.
            if ((Split-Path -Parent ([IO.Path]::GetFullPath($backup))) -ne $parent) { throw 'Backup escaped the settings parent.' }
            [IO.Directory]::Move($connection.TargetDirectory, $backup)
        }
        [IO.Directory]::Move($stage, $connection.TargetDirectory)
    } catch {
        if ($backup -and -not (Get-Item -LiteralPath $connection.TargetDirectory -Force -ErrorAction SilentlyContinue)) {
            [IO.Directory]::Move($backup, $connection.TargetDirectory)
        }
        throw
    } finally {
        # Remove only this known junction entry; never recurse into its source.
        if (Get-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue) { [IO.Directory]::Delete($stage, $false) }
    }
    $result = Get-WindowsTerminalConnection -SourcePath $connection.Source -TargetPath $connection.Target
    if ($result.Status -ne 'linked') { throw 'Windows Terminal directory link verification failed.' }
    if ($backup) { $result | Add-Member -NotePropertyName Backup -NotePropertyValue $backup }
    return $result
}

function Assert-WindowsTerminalPrograms {
    param([ValidateSet('stable','preview','unpackaged')][string]$Channel, [string]$TargetPath)
    $terminal = Get-Command wt -CommandType Application -ErrorAction SilentlyContinue
    if (-not $terminal) { throw 'Windows Terminal (wt.exe) is missing; functions and aliases are not executable prerequisites.' }
    if (-not (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue)) { throw 'PowerShell 7 is required by the repository Terminal profile.' }
    if ($Channel -eq 'unpackaged') {
        $aliases = Join-Path $env:LOCALAPPDATA 'Microsoft/WindowsApps'
        if ($terminal.Source.StartsWith($aliases + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unpackaged channel requires its actual wt.exe in PATH, not a Store app execution alias.'
        }
    } else {
        if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) { throw 'Cannot verify the selected Store channel: Get-AppxPackage is unavailable.' }
        $packageName = if ($Channel -eq 'preview') { 'Microsoft.WindowsTerminalPreview' } else { 'Microsoft.WindowsTerminal' }
        $package = Get-AppxPackage -Name $packageName | Select-Object -First 1
        if (-not $package -or -not (Test-Path -LiteralPath (Join-Path $package.InstallLocation 'WindowsTerminal.exe') -PathType Leaf)) {
            throw ('Selected Windows Terminal channel is not installed: ' + $Channel)
        }
        if (-not (Test-Path -LiteralPath (Split-Path -Parent (Split-Path -Parent $TargetPath)) -PathType Container)) {
            throw 'Selected package settings parent is missing. Launch the selected installed channel once before linking.'
        }
    }
}

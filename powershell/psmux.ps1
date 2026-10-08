# Runtime source, loaded by both user profiles and the WezTerm launcher.
if ($env:OS -ne 'Windows_NT') { return }
$dotfilesMuxRepo = Split-Path -Parent $PSScriptRoot
$muxStatusReader = {
    [CmdletBinding()]
    param()
    $reasons = @()
    $actions = @()
    $environment = $null
    $feature = $null
    try {
        $environment = Get-Content -LiteralPath (Join-Path $dotfilesMuxRepo '.local/environment.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    } catch {
        $reasons += 'Environment record is missing or invalid.'
        $actions += 'Review the host environment selection using scripts/environment.py; do not copy another host approval.'
    }
    try {
        $feature = Get-Content -LiteralPath (Join-Path $dotfilesMuxRepo '.local/psmux.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    } catch {
        $reasons += 'psmux feature record is missing or invalid.'
        $actions += 'Review the optional psmux setup in README.md.'
    }
    if ($environment) {
        if ($environment.schemaVersion -ne 1 -or $environment.environment -ne 'windows-powershell') { $reasons += 'Environment record does not select supported Windows PowerShell.' }
        if ($environment.approved -isnot [bool] -or $environment.approved -ne $true) { $reasons += 'Environment approval must be boolean true.' }
        if ($environment.host -ne [Environment]::MachineName) { $reasons += 'Environment host differs from this computer.' }
    }
    if ($feature) {
        if ($feature.schemaVersion -ne 1) { $reasons += 'psmux record schema is unsupported.' }
        if ($feature.enabled -isnot [bool] -or $feature.enabled -ne $true) { $reasons += 'psmux activation must be boolean true.' }
        if ($feature.host -ne [Environment]::MachineName) { $reasons += 'psmux host differs from this computer.' }
    }
    $bin = Join-Path $env:LOCALAPPDATA 'Programs/psmux/3.3.8'
    $psmuxPresent = Test-Path -LiteralPath (Join-Path $bin 'psmux.exe') -PathType Leaf
    $tmuxPresent = Test-Path -LiteralPath (Join-Path $bin 'tmux.exe') -PathType Leaf
    if (-not $psmuxPresent -or -not $tmuxPresent) { $reasons += 'Pinned psmux/tmux 3.3.8 executable is missing.' }
    $pwshPresent = [bool](Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue)
    if (-not $pwshPresent) { $reasons += 'PowerShell 7 (pwsh), required by psmux panes, is missing.' }
    if ($reasons.Count) {
        $actions += 'Review the local records and README.md. Host or approval changes require explicit approval; this command does not change them.'
    }
    [pscustomobject]@{
        Status = $(if ($reasons.Count) { 'Blocked' } else { 'Ready' })
        Reason = $(if ($reasons.Count) { $reasons -join ' ' } else { 'Runtime prerequisites are valid; open a new PowerShell tab after setup.' })
        Action = $(if ($actions.Count) { ($actions | Select-Object -Unique) -join ' ' } else { 'Run mux; existing user mux/t commands are preserved.' })
        Repository = $dotfilesMuxRepo
        CurrentHost = [Environment]::MachineName
        Environment = $environment.environment
        EnvironmentHost = $environment.host
        Approved = $environment.approved
        FeatureHost = $feature.host
        Enabled = $feature.enabled
        PsmuxPresent = $psmuxPresent
        TmuxPresent = $tmuxPresent
        PowerShell7Present = $pwshPresent
    }
}.GetNewClosure()
Set-Item Function:\global:Get-DotfilesMuxStatus -Value $muxStatusReader
try {
    $muxEnvironment = Get-Content (Join-Path $dotfilesMuxRepo '.local/environment.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
    $muxFeature = Get-Content (Join-Path $dotfilesMuxRepo '.local/psmux.json') -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
} catch { return }
if ($muxEnvironment.approved -isnot [bool] -or $muxEnvironment.approved -ne $true -or
    $muxEnvironment.schemaVersion -ne 1 -or $muxEnvironment.environment -ne 'windows-powershell' -or
    $muxEnvironment.host -ne [Environment]::MachineName -or $muxFeature.schemaVersion -ne 1 -or
    $muxFeature.enabled -isnot [bool] -or $muxFeature.enabled -ne $true -or
    $muxFeature.host -ne [Environment]::MachineName) { return }
$dotfilesMuxBin = Join-Path $env:LOCALAPPDATA 'Programs/psmux/3.3.8'
if (-not (Test-Path (Join-Path $dotfilesMuxBin 'psmux.exe') -PathType Leaf) -or
    -not (Test-Path (Join-Path $dotfilesMuxBin 'tmux.exe') -PathType Leaf)) { return }
$env:Path = $dotfilesMuxBin + ';' + (($env:Path -split ';' | Where-Object { $_ -and $_ -ne $dotfilesMuxBin }) -join ';')
$env:DOTFILES_ROOT = $dotfilesMuxRepo

function global:Test-DotfilesMuxPane {
    if ($env:TMUX -notmatch '^/tmp/psmux-\d+/default,\d+,0$' -or
        -not $env:PSMUX_SESSION -or -not $env:DOTFILES_ROOT -or -not $env:PSMUX_CONFIG_FILE) { return $false }
    try {
        if (-not [IO.Path]::IsPathRooted($env:DOTFILES_ROOT) -or -not [IO.Path]::IsPathRooted($env:PSMUX_CONFIG_FILE)) { return $false }
        $expected = [IO.Path]::GetFullPath((Join-Path $env:DOTFILES_ROOT 'tmux/psmux.conf')).TrimEnd('\', '/')
        $actual = [IO.Path]::GetFullPath($env:PSMUX_CONFIG_FILE).TrimEnd('\', '/')
        return [string]::Equals($expected, $actual, [StringComparison]::OrdinalIgnoreCase)
    } catch { return $false }
}

function global:Invoke-DotfilesMux {
    [CmdletBinding()]
    param([string]$Session = 'main', [string]$Path = (Get-Location).Path)
    if ($Session -notmatch '^[a-zA-Z0-9_-]+$' -or $Session.Contains('__')) { throw 'Use letters, numbers, underscore or hyphen; double underscore is reserved by psmux.' }
    $directory = (Get-Item -LiteralPath $Path -ErrorAction Stop)
    if (-not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') { throw 'A filesystem directory is required.' }
    $muxExe = Join-Path $env:LOCALAPPDATA 'Programs/psmux/3.3.8/psmux.exe'
    $muxConfig = Join-Path $env:DOTFILES_ROOT 'tmux/psmux.conf'
    if ($env:TMUX -and -not (Test-DotfilesMuxPane)) { throw 'Exit the named or other multiplexer before entering default dotfiles psmux.' }
    & $muxExe -f $muxConfig has-session -t "=$Session" 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $muxExe -f $muxConfig new-session -d -s $Session -c $directory.FullName
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the psmux session.' }
    }
    # Do not silently adopt a default session that belongs to another configuration.
    $serverEnvironment = @(& $muxExe -t $Session show-environment)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the psmux session configuration.' }
    $configMarker = @($serverEnvironment | Where-Object { $_ -like 'PSMUX_CONFIG_FILE=*' })
    $owned = $false
    if ($configMarker.Count -eq 1) {
        try {
            $serverConfig = $configMarker[0].Substring('PSMUX_CONFIG_FILE='.Length)
            $owned = [IO.Path]::IsPathRooted($serverConfig) -and [string]::Equals(
                [IO.Path]::GetFullPath($serverConfig), [IO.Path]::GetFullPath($muxConfig), [StringComparison]::OrdinalIgnoreCase)
        } catch { $owned = $false }
    }
    if (-not $owned) { throw "Session '$Session' uses another configuration. Choose an unused session name; existing sessions were not changed." }
    # Quote-aware CLI writes a reload binding referencing this checkout.
    & $muxExe -t $Session bind-key r source-file $muxConfig
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure the psmux reload binding.' }
    if ($env:TMUX) { & $muxExe switch-client -t "=$Session" }
    else { & $muxExe attach-session -t "=$Session" }
    if ($LASTEXITCODE -ne 0) { throw 'Could not attach/switch to the psmux session.' }
}

function global:Invoke-DotfilesProject {
    [CmdletBinding()]
    param([string]$Path)
    if (-not $Path) {
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { throw 'fzf is required for project selection; use t <directory> instead.' }
        $rootsFile = Join-Path $env:DOTFILES_ROOT '.local/project-paths.txt'
        $roots = @((Get-Location).Path)
        if (Test-Path -LiteralPath $rootsFile -PathType Leaf) {
            $roots = @(Get-Content -LiteralPath $rootsFile -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.StartsWith('#') })
        }
        $directories = @($roots | ForEach-Object {
            if (Test-Path -LiteralPath $_ -PathType Container) {
                (Get-Item -LiteralPath $_).FullName
                Get-ChildItem -LiteralPath $_ -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
            }
        } | Sort-Object -Unique)
        $previousOutputEncoding = $OutputEncoding
        $previousConsoleEncoding = [Console]::OutputEncoding
        try {
            $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
            $Path = $directories | & fzf --prompt 'Project> '
        } finally {
            $OutputEncoding = $previousOutputEncoding
            [Console]::OutputEncoding = $previousConsoleEncoding
        }
        if (-not $Path) { return }
    }
    $directory = Get-Item -LiteralPath $Path -ErrorAction Stop
    if (-not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') { throw 'A filesystem directory is required.' }
    $normalized = $directory.FullName.TrimEnd('\').ToLowerInvariant()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalized)) }
    finally { $sha.Dispose() }
    $suffix = ([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 12).ToLowerInvariant()
    $name = (($directory.Name -replace '[^a-zA-Z0-9_-]', '_') -replace '_+', '_').Trim('_')
    if (-not $name) { $name = 'project' }
    Invoke-DotfilesMux -Session ($name + '-' + $suffix) -Path $directory.FullName
}

# No nested shell quoting is needed for the source-checkout project key.
function global:Invoke-DotfilesConfigProject { & t $env:DOTFILES_ROOT }
if (-not (Get-Command mux -ErrorAction SilentlyContinue)) { Set-Alias -Name mux -Value Invoke-DotfilesMux -Scope Global }
if (-not (Get-Command t -ErrorAction SilentlyContinue)) { Set-Alias -Name t -Value Invoke-DotfilesProject -Scope Global }

if ((Test-DotfilesMuxPane) -and (Get-Command prompt -ErrorAction SilentlyContinue)) {
    $originalMuxPrompt = (Get-Item Function:\prompt).ScriptBlock
    if ($originalMuxPrompt.ToString() -notmatch 'ResetDotfilesPsmuxForeground') {
        $muxPrompt = {
            # ResetDotfilesPsmuxForeground: a shell prompt ends the previous command.
            $renderedPrompt = & $originalMuxPrompt
            [Console]::Write([char]27 + ']133;A' + [char]7)
            $renderedPrompt
        }.GetNewClosure()
        Set-Item Function:\global:prompt -Value $muxPrompt
    }
}

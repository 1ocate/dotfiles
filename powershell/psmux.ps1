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
    $pinnedVersion = '3.4.0'
    $activeVersion = $pinnedVersion
    $dataDirectory = $env:PSMUX_DATA_DIR
    if ($env:TMUX) {
        $activeVersion = $null
        $owned = $false
        if ($env:TMUX -match '^/tmp/psmux-(\d+)/default,\d+,0$' -and $env:PSMUX_SESSION) {
            $serverProcessId = $Matches[1]
            try {
                if ([IO.Path]::IsPathRooted($env:DOTFILES_ROOT) -and [IO.Path]::IsPathRooted($env:PSMUX_CONFIG_FILE)) {
                    $expectedRoot = [IO.Path]::GetFullPath($dotfilesMuxRepo).TrimEnd('\', '/')
                    $actualRoot = [IO.Path]::GetFullPath($env:DOTFILES_ROOT).TrimEnd('\', '/')
                    $expectedConfig = [IO.Path]::GetFullPath((Join-Path $dotfilesMuxRepo 'tmux/psmux.conf')).TrimEnd('\', '/')
                    $actualConfig = [IO.Path]::GetFullPath($env:PSMUX_CONFIG_FILE).TrimEnd('\', '/')
                    $owned = [string]::Equals($expectedRoot, $actualRoot, [StringComparison]::OrdinalIgnoreCase) -and
                        [string]::Equals($expectedConfig, $actualConfig, [StringComparison]::OrdinalIgnoreCase)
                }
            } catch { $owned = $false }
            if ($owned) {
                try {
                    # The live process path is authoritative; a version marker
                    # alone cannot identify a server left running by an upgrade.
                    $serverProcess = Get-Process -Id ([int]$serverProcessId) -ErrorAction Stop
                    if (-not $serverProcess.Path) { throw 'Server process path is unavailable.' }
                    $serverPath = [IO.Path]::GetFullPath([string]$serverProcess.Path)
                    foreach ($knownVersion in @('3.3.8', $pinnedVersion)) {
                        foreach ($executable in @('psmux.exe', 'tmux.exe')) {
                            $knownPath = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA "Programs/psmux/$knownVersion/$executable"))
                            if ([string]::Equals($serverPath, $knownPath, [StringComparison]::OrdinalIgnoreCase)) {
                                $activeVersion = $knownVersion
                            }
                        }
                    }
                    if (-not $activeVersion) { $reasons += 'Running mux server executable is not a known installed version.' }
                } catch { $reasons += 'Running mux server process is unavailable or its executable path cannot be read.' }
            }
        }
        if (-not $owned) { $reasons += 'Current pane belongs to another or unrecognized mux configuration.' }
    } elseif (-not $dataDirectory) {
        $dataDirectory = Join-Path $env:LOCALAPPDATA "psmux/$pinnedVersion"
    }
    $bin = $null
    if ($activeVersion) { $bin = Join-Path $env:LOCALAPPDATA "Programs/psmux/$activeVersion" }
    $psmuxPresent = $false
    $tmuxPresent = $false
    if ($bin) {
        $psmuxPresent = Test-Path -LiteralPath (Join-Path $bin 'psmux.exe') -PathType Leaf
        $tmuxPresent = Test-Path -LiteralPath (Join-Path $bin 'tmux.exe') -PathType Leaf
    }
    if ($activeVersion -and (-not $psmuxPresent -or -not $tmuxPresent)) { $reasons += "Selected psmux/tmux $activeVersion executable is missing." }
    $pwshPresent = [bool](Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue)
    if (-not $pwshPresent) { $reasons += 'PowerShell 7 (pwsh), required by psmux panes, is missing.' }
    if ($reasons.Count) {
        $actions += 'Review the local records and README.md. Host or approval changes require explicit approval; this command does not change them.'
    }
    [pscustomobject]@{
        Status = $(if ($reasons.Count) { 'Blocked' } else { 'Ready' })
        Reason = $(if ($reasons.Count) { $reasons -join ' ' } elseif ($activeVersion -eq '3.3.8') { 'Legacy 3.3.8 server retained; this pane has not switched to pinned 3.4.0.' } else { 'Runtime prerequisites are valid; open a new PowerShell tab after setup.' })
        Action = $(if ($actions.Count) { ($actions | Select-Object -Unique) -join ' ' } elseif ($activeVersion -eq '3.3.8') { 'Open a new PowerShell tab outside mux for 3.4.0; keep this legacy pane and its data root for existing work.' } else { 'Run mux; existing user mux/t commands are preserved.' })
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
        PinnedVersion = $pinnedVersion
        ActiveVersion = $activeVersion
        IsLegacy = ($activeVersion -eq '3.3.8')
        DataDirectory = $dataDirectory
    }
}.GetNewClosure()
Set-Item Function:\global:Get-DotfilesMuxStatus -Value $muxStatusReader
$muxSelection = Get-DotfilesMuxStatus
if ($muxSelection.Status -ne 'Ready') { return }
$dotfilesMuxBin = Join-Path $env:LOCALAPPDATA "Programs/psmux/$($muxSelection.ActiveVersion)"
$env:Path = $dotfilesMuxBin + ';' + (($env:Path -split ';' | Where-Object { $_ -and $_ -ne $dotfilesMuxBin }) -join ';')
$env:DOTFILES_ROOT = $dotfilesMuxRepo
$env:DOTFILES_PSMUX_VERSION = $muxSelection.ActiveVersion
if (-not $env:TMUX -and -not $env:PSMUX_DATA_DIR) { $env:PSMUX_DATA_DIR = $muxSelection.DataDirectory }

function global:Test-DotfilesMuxPane {
    return [bool]($env:TMUX -and (Get-DotfilesMuxStatus).Status -eq 'Ready')
}

function global:Invoke-DotfilesMux {
    [CmdletBinding()]
    param([string]$Session = 'main', [string]$Path = (Get-Location).Path)
    if ($Session -notmatch '^[a-zA-Z0-9_-]+$' -or $Session.Contains('__')) { throw 'Use letters, numbers, underscore or hyphen; double underscore is reserved by psmux.' }
    $directory = (Get-Item -LiteralPath $Path -ErrorAction Stop)
    if (-not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') { throw 'A filesystem directory is required.' }
    $selection = Get-DotfilesMuxStatus
    if ($selection.Status -ne 'Ready') { throw $selection.Reason }
    $muxExe = Join-Path $env:LOCALAPPDATA "Programs/psmux/$($selection.ActiveVersion)/psmux.exe"
    $muxConfig = Join-Path $selection.Repository 'tmux/psmux.conf'
    & $muxExe -f $muxConfig has-session -t "=$Session" 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $muxExe -f $muxConfig new-session -d -s $Session -c $directory.FullName
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the psmux session.' }
    }
    $serverVersion = @(& $muxExe -t $Session display-message -p '#{version}')
    if ($LASTEXITCODE -ne 0 -or $serverVersion.Count -ne 1 -or $serverVersion[0] -cne $selection.ActiveVersion) {
        throw "Session '$Session' uses a different or unknown psmux version. Use a separate data directory; existing sessions were not attached or reconfigured."
    }
    # Do not silently adopt a default session that belongs to another configuration.
    $serverEnvironment = @(& $muxExe -t $Session show-environment)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the psmux session configuration.' }
    $configMarker = @($serverEnvironment | Where-Object { $_ -like 'PSMUX_CONFIG_FILE=*' })
    if ($configMarker.Count -eq 0) {
        # psmux 3.4.0 lists the server's startup config only in its global environment.
        $serverEnvironment = @(& $muxExe -t $Session show-environment -g)
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the psmux server configuration.' }
        $configMarker = @($serverEnvironment | Where-Object { $_ -like 'PSMUX_CONFIG_FILE=*' })
    }
    $owned = $false
    if ($configMarker.Count -eq 1) {
        try {
            $serverConfig = $configMarker[0].Substring('PSMUX_CONFIG_FILE='.Length)
            $owned = [IO.Path]::IsPathRooted($serverConfig) -and [string]::Equals(
                [IO.Path]::GetFullPath($serverConfig), [IO.Path]::GetFullPath($muxConfig), [StringComparison]::OrdinalIgnoreCase)
        } catch { $owned = $false }
    }
    if (-not $owned) { throw "Session '$Session' uses another configuration. Choose an unused session name; existing sessions were not changed." }
    # All bindings live in the source config; its reload key reads this path.
    # (A partial source-file would reset the config's other bindings.)
    & $muxExe -t $Session set-option -g '@dotfiles_config' $muxConfig
    if ($LASTEXITCODE -ne 0) { throw 'Could not record the psmux config path for reload.' }
    if ($env:TMUX) { & $muxExe switch-client -t "=$Session" }
    elseif ($env:PSMUX_POPUP -eq '1') {
        # A popup has no TMUX. psmux runs one server per session and routes
        # switch-client by the port in TMUX, so point it at the server of the
        # session whose client opened the popup.
        if ($env:PSMUX_SESSION -notmatch '^[a-zA-Z0-9_-]+$') { throw 'The popup does not identify its psmux session.' }
        $dataRoot = if ($env:PSMUX_DATA_DIR) { $env:PSMUX_DATA_DIR } else { Join-Path $env:USERPROFILE '.psmux' }
        $port = (Get-Content -LiteralPath (Join-Path $dataRoot "$env:PSMUX_SESSION.port") -Raw -ErrorAction Stop).Trim()
        if ($port -notmatch '^\d+$') { throw 'The popup session has no valid psmux port.' }
        try {
            $env:TMUX = "popup,$port,0"
            & $muxExe switch-client -t "=$Session"
        } finally { $env:TMUX = $null }
    }
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

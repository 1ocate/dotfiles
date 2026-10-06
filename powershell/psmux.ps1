# Runtime source, loaded by both user profiles and the WezTerm launcher.
if ($env:OS -ne 'Windows_NT') { return }
$dotfilesMuxRepo = Split-Path -Parent $PSScriptRoot
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

function global:Invoke-DotfilesMux {
    [CmdletBinding()]
    param([string]$Session = 'main', [string]$Path = (Get-Location).Path)
    if ($Session -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use letters, numbers, underscore or hyphen for the session name.' }
    $directory = (Get-Item -LiteralPath $Path -ErrorAction Stop)
    if (-not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') { throw 'A filesystem directory is required.' }
    $muxExe = Join-Path $env:LOCALAPPDATA 'Programs/psmux/3.3.8/psmux.exe'
    $muxConfig = Join-Path $env:DOTFILES_ROOT 'tmux/psmux.conf'
    if ($env:TMUX -and $env:TMUX -notmatch '/dotfiles,') { throw 'Exit the other multiplexer before entering dotfiles psmux.' }
    & $muxExe -L dotfiles -f $muxConfig has-session -t "=$Session" 2>$null
    if ($LASTEXITCODE -ne 0) {
        & $muxExe -L dotfiles -f $muxConfig new-session -d -s $Session -c $directory.FullName
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the psmux session.' }
    }
    # Quote-aware CLI writes a reload binding referencing this checkout.
    & $muxExe -L dotfiles -t $Session bind-key r source-file $muxConfig
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure the psmux reload binding.' }
    if ($env:TMUX) { & $muxExe -L dotfiles switch-client -t "=$Session" }
    else { & $muxExe -L dotfiles attach-session -t "=$Session" }
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
    $name = ($directory.Name -replace '[^a-zA-Z0-9_-]', '_')
    if (-not $name) { $name = 'project' }
    Invoke-DotfilesMux -Session ($name + '-' + $suffix) -Path $directory.FullName
}

if (-not (Get-Command mux -ErrorAction SilentlyContinue)) { Set-Alias -Name mux -Value Invoke-DotfilesMux -Scope Global }
if (-not (Get-Command t -ErrorAction SilentlyContinue)) { Set-Alias -Name t -Value Invoke-DotfilesProject -Scope Global }

if ($env:TMUX -match '/dotfiles,' -and (Get-Command prompt -ErrorAction SilentlyContinue)) {
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

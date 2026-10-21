# Native Windows PSReadLine history selector. Never evaluates the selected command.
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return }

function Get-DotfilesHistoryCandidates {
    param([string]$HistoryPath, [string[]]$SessionHistory = @())
    $commands = [Collections.Generic.List[string]]::new()
    if ($HistoryPath -and [IO.File]::Exists($HistoryPath)) {
        try {
            $pending = ''
            foreach ($line in [IO.File]::ReadAllLines($HistoryPath, [Text.Encoding]::UTF8)) {
                if ($line.EndsWith('`')) {
                    $pending += $line.Substring(0, $line.Length - 1) + "`n"
                } else {
                    $commands.Add($pending + $line)
                    $pending = ''
                }
            }
            # An incomplete trailing record may be another shell's in-progress write.
        } catch { }
    }
    foreach ($command in $SessionHistory) { $commands.Add($command) }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    for ($index = $commands.Count - 1; $index -ge 0; $index--) {
        $command = $commands[$index]
        if (-not [string]::IsNullOrWhiteSpace($command) -and $seen.Add($command)) { $command }
    }
}

function Select-DotfilesHistory {
    param([string[]]$Candidates, [string]$Query = '')
    $fzfCommand = Get-Command fzf.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $fzfCommand) { return [pscustomobject]@{ Status = 'unavailable'; Value = $null } }
    if (-not $Candidates.Count) { return [pscustomobject]@{ Status = 'cancelled'; Value = $null } }
    # Stable IDs map single-line display rows back to exact multiline command text.
    $rows = @(for ($index = 0; $index -lt $Candidates.Count; $index++) {
        [string]$index + "`t" + [regex]::Replace($Candidates[$index], '[\r\n\t\x00-\x1f\x7f]', ' ')
    })
    $savedOptions = $env:FZF_DEFAULT_OPTS
    $savedOptionsFile = $env:FZF_DEFAULT_OPTS_FILE
    $savedEncoding = $OutputEncoding
    $savedExit = $global:LASTEXITCODE
    try {
        $env:FZF_DEFAULT_OPTS = ''
        $env:FZF_DEFAULT_OPTS_FILE = ''
        $OutputEncoding = [Text.UTF8Encoding]::new($false)
        $selected = @($rows | & $fzfCommand.Source --height=40% --layout=reverse --border --no-multi --no-sort '--delimiter=\t' '--with-nth=2..' '--nth=2..' '--prompt=History> ' ('--query=' + $Query))
        $selectorExit = $LASTEXITCODE
        if ($selectorExit -eq 130 -or $selectorExit -eq 1) {
            return [pscustomobject]@{ Status = 'cancelled'; Value = $null }
        }
        if ($selectorExit -eq 0 -and $selected.Count -eq 1 -and $rows -ccontains $selected[0]) {
            $selectedIndex = [int]($selected[0] -split "`t", 2)[0]
            return [pscustomobject]@{ Status = 'selected'; Value = $Candidates[$selectedIndex] }
        }
    } catch { } finally {
        $env:FZF_DEFAULT_OPTS = $savedOptions
        $env:FZF_DEFAULT_OPTS_FILE = $savedOptionsFile
        $OutputEncoding = $savedEncoding
        $global:LASTEXITCODE = $savedExit
    }
    [pscustomobject]@{ Status = 'unavailable'; Value = $null }
}

if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key Ctrl+r -BriefDescription FzfHistory -LongDescription 'Search history with fzf; Enter inserts without executing' -ScriptBlock {
        param($key, $arg)
        $line = $null
        $cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        try {
            $options = Get-PSReadLineOption
            $historyPath = $options.HistorySavePath
            if ([string]$options.HistorySaveStyle -eq 'SaveNothing') { $historyPath = '' }
            $session = @([Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() | ForEach-Object CommandLine)
            $candidates = @(Get-DotfilesHistoryCandidates -HistoryPath $historyPath -SessionHistory $session)
            $selection = Select-DotfilesHistory -Candidates $candidates -Query $line
            if ($selection.Status -eq 'selected') {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $selection.Value)
            }
            if ($selection.Status -ne 'unavailable') {
                [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
                return
            }
        } catch { }
        [Microsoft.PowerShell.PSConsoleReadLine]::ReverseSearchHistory($key, $arg)
    }
}

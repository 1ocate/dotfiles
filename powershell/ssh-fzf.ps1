# SSH-only selector. Other completion stays with PSReadLine MenuComplete.
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return }

function Get-DotfilesSshTabCandidates {
    param([string]$Line, [int]$Cursor)
    $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($Line, $Cursor, $null)
    if ($completion.ReplacementIndex -lt 0 -or $Cursor -lt $completion.ReplacementIndex) { return }
    $word = $Line.Substring($completion.ReplacementIndex, $Cursor - $completion.ReplacementIndex)
    if ($word.StartsWith('-')) { return }
    $userPrefix = ''
    $query = $word
    if ($word -match '^(.*@)([^@]*)$') {
        $userPrefix = $Matches[1]
        $query = $Matches[2]
    }
    # Give fzf all hosts, so the initial query can be edited or cleared there.
    $candidateLine = $Line.Remove($completion.ReplacementIndex, $completion.ReplacementLength).Insert($completion.ReplacementIndex, $userPrefix)
    $allHosts = [System.Management.Automation.CommandCompletion]::CompleteInput(
        $candidateLine, $completion.ReplacementIndex + $userPrefix.Length, $null)
    $candidates = @($allHosts.CompletionMatches | Where-Object ToolTip -eq 'SSH Host alias')
    if ($candidates.Count -eq 0) { return }
    [pscustomobject]@{
        Candidates = @($candidates | ForEach-Object CompletionText)
        Start = $completion.ReplacementIndex
        Length = $completion.ReplacementLength
        Query = $query
    }
}

function Select-DotfilesSshHost {
    param([string[]]$Candidates, [string]$Query = '')
    $fzfCommand = Get-Command fzf.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $fzfCommand) { return [pscustomobject]@{ Status = 'unavailable'; Value = $null } }
    # Keep global fzf bindings/options from changing single-selection output or running actions.
    $savedOptions = $env:FZF_DEFAULT_OPTS
    $savedOptionsFile = $env:FZF_DEFAULT_OPTS_FILE
    try {
        $env:FZF_DEFAULT_OPTS = ''
        $env:FZF_DEFAULT_OPTS_FILE = ''
        $selected = @($Candidates | & $fzfCommand.Source --height=40% --layout=reverse --border --no-multi --no-sort '--prompt=SSH> ' ('--query=' + $Query))
        $selectorExit = $LASTEXITCODE
        if ($selectorExit -eq 130 -or $selectorExit -eq 1) {
            return [pscustomobject]@{ Status = 'cancelled'; Value = $null }
        }
        if ($selectorExit -eq 0 -and $selected.Count -eq 1 -and $Candidates -ccontains $selected[0]) {
            return [pscustomobject]@{ Status = 'selected'; Value = $selected[0] }
        }
    } catch {
        # Optional selector failure must not disable normal completion.
    } finally {
        $env:FZF_DEFAULT_OPTS = $savedOptions
        $env:FZF_DEFAULT_OPTS_FILE = $savedOptionsFile
    }
    [pscustomobject]@{ Status = 'unavailable'; Value = $null }
}

if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key Tab -BriefDescription SshHostMenu -LongDescription 'Select SSH hosts with fzf; otherwise use MenuComplete' -ScriptBlock {
        param($key, $arg)
        $line = $null
        $cursor = 0
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $completion = Get-DotfilesSshTabCandidates -Line $line -Cursor $cursor
        if ($completion) {
            $selection = Select-DotfilesSshHost -Candidates $completion.Candidates -Query $completion.Query
            if ($selection.Status -eq 'selected') {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace($completion.Start, $completion.Length, $selection.Value)
            }
            if ($selection.Status -ne 'unavailable') {
                [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
                return
            }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete($key, $arg)
    }
}

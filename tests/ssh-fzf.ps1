$ErrorActionPreference = 'Stop'
Import-Module PSReadLine
. (Join-Path $PSScriptRoot '../powershell/tab-completion.ps1')
$script:fixture = @('Host alpha beta')
function Test-Path { param($LiteralPath, $PathType) return $true }
function Get-Content { param($LiteralPath, $ErrorAction) return $script:fixture }
$completion = Get-DotfilesSshTabCandidates -Line 'ssh user@b' -Cursor 10
if ($completion.Start -ne 4 -or $completion.Length -ne 6 -or
    ($completion.Candidates -join ',') -ne 'user@alpha,user@beta' -or $completion.Query -ne 'b') { throw 'Wrong replacement range/candidates/query' }
$completion = Get-DotfilesSshTabCandidates -Line 'ssh ' -Cursor 4
if ($completion.Query -ne '' -or ($completion.Candidates -join ',') -ne 'alpha,beta') { throw 'Empty query lost hosts' }
$completion = Get-DotfilesSshTabCandidates -Line 'ssh pha' -Cursor 7
if ($completion.Query -ne 'pha' -or ($completion.Candidates -join ',') -ne 'alpha,beta') { throw 'Substring query cannot access all hosts' }
$completion = Get-DotfilesSshTabCandidates -Line 'ssh unknown' -Cursor 11
if ($completion.Query -ne 'unknown' -or $completion.Candidates.Count -ne 2) { throw 'Unmatched query lost hosts' }
if (Get-DotfilesSshTabCandidates -Line 'ssh -p ' -Cursor 7) { throw 'Option value intercepted' }
if (Get-DotfilesSshTabCandidates -Line 'ssh alpha echo b' -Cursor 16) { throw 'Remote command intercepted' }
if (Get-DotfilesSshTabCandidates -Line 'Write-Output b' -Cursor 14) { throw 'Other command intercepted' }
Remove-Item Function:\Get-Content, Function:\Test-Path

$script:fakeFzf = Join-Path ([IO.Path]::GetTempPath()) ('ssh-fzf-' + [guid]::NewGuid().ToString('N') + '.ps1')
@'
$global:dotfilesTestFzfArgs = @($args)
$global:dotfilesTestFzfCandidates = @($input)
if ($env:FZF_DEFAULT_OPTS -or $env:FZF_DEFAULT_OPTS_FILE) { throw 'Options not isolated' }
$global:LASTEXITCODE = $global:dotfilesTestFzfExit
if ($global:dotfilesTestFzfExit -eq 0) { $global:dotfilesTestFzfValue }
'@ | Set-Content -LiteralPath $script:fakeFzf
function Get-Command {
    param($Name, $CommandType, $ErrorAction)
    if ($script:missingFzf) { return }
    [pscustomobject]@{ Source = $script:fakeFzf }
}
$savedOptions = $env:FZF_DEFAULT_OPTS
$savedFile = $env:FZF_DEFAULT_OPTS_FILE
try {
    $env:FZF_DEFAULT_OPTS = '--multi'
    $env:FZF_DEFAULT_OPTS_FILE = 'fixture-options'
    $global:dotfilesTestFzfExit = 0
    $global:dotfilesTestFzfValue = 'beta'
    $result = Select-DotfilesSshHost -Candidates @('alpha', 'beta') -Query 'pha'
    if ($result.Status -ne 'selected' -or $result.Value -ne 'beta') { throw 'Selection failed' }
    if ($global:dotfilesTestFzfArgs -notcontains '--query=pha' -or
        ($global:dotfilesTestFzfCandidates -join ',') -ne 'alpha,beta') { throw 'Initial query or full host list not passed to fzf' }
    $null = Select-DotfilesSshHost -Candidates @('alpha', 'beta')
    if ($global:dotfilesTestFzfArgs -notcontains '--query=') { throw 'Empty initial query not passed to fzf' }
    if ($env:FZF_DEFAULT_OPTS -ne '--multi' -or $env:FZF_DEFAULT_OPTS_FILE -ne 'fixture-options') { throw 'Options not restored' }
    $global:dotfilesTestFzfExit = 130
    if ((Select-DotfilesSshHost @('alpha')).Status -ne 'cancelled') { throw 'Cancel failed' }
    $global:dotfilesTestFzfExit = 2
    if ((Select-DotfilesSshHost @('alpha')).Status -ne 'unavailable') { throw 'Failure fallback failed' }
    $global:dotfilesTestFzfExit = 0
    $global:dotfilesTestFzfValue = 'unexpected'
    if ((Select-DotfilesSshHost @('alpha')).Status -ne 'unavailable') { throw 'Unexpected output accepted' }
    $script:missingFzf = $true
    if ((Select-DotfilesSshHost @('alpha')).Status -ne 'unavailable') { throw 'Missing fzf fallback failed' }
} finally {
    $env:FZF_DEFAULT_OPTS = $savedOptions
    $env:FZF_DEFAULT_OPTS_FILE = $savedFile
    Remove-Item Function:\Get-Command
    Remove-Item -LiteralPath $script:fakeFzf
    Remove-Variable dotfilesTestFzfExit, dotfilesTestFzfValue -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable dotfilesTestFzfArgs, dotfilesTestFzfCandidates -Scope Global -ErrorAction SilentlyContinue
}
if ((Get-PSReadLineKeyHandler -Chord Tab).Function -ne 'SshHostMenu') { throw 'SSH Tab binding missing' }
Write-Output 'SSH fzf routing, replacement, selection, cancellation and fallback checks passed.'

$ErrorActionPreference = 'Stop'
Import-Module PSReadLine
. (Join-Path $PSScriptRoot '../powershell/history-fzf.ps1')
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) ('fzf-history-' + [guid]::NewGuid().ToString('N'))
$fakeFzf = $fixturePath + '.ps1'
$savedOptions = $env:FZF_DEFAULT_OPTS
$savedFile = $env:FZF_DEFAULT_OPTS_FILE
try {
    $fixtureText = @('older', '한글 명령', 'first`', 'second', 'older', 'incomplete`') -join "`n"
    [IO.File]::WriteAllText($fixturePath, $fixtureText, [Text.UTF8Encoding]::new($false))
    $items = @(Get-DotfilesHistoryCandidates $fixturePath @('session', 'older'))
    if ($items.Count -ne 4 -or $items[0] -ne 'older' -or $items[1] -ne 'session' -or $items[2] -ne "first`nsecond" -or $items[3] -ne '한글 명령') { throw 'Order/dedup/multiline/Unicode failed' }
    if (@(Get-DotfilesHistoryCandidates ($fixturePath + '-missing')).Count) { throw 'Missing history not empty' }
    [IO.File]::WriteAllText($fixturePath, '')
    if (@(Get-DotfilesHistoryCandidates $fixturePath).Count) { throw 'Empty history not empty' }
    @'
$global:testHistoryArgs = @($args)
$global:testHistoryRows = @($input)
if ($env:FZF_DEFAULT_OPTS -or $env:FZF_DEFAULT_OPTS_FILE) { throw 'Options leaked' }
$global:LASTEXITCODE = $global:testHistoryExit
if ($global:testHistoryExit -eq 0) {
    if ($global:testHistoryInvalid) { 'invalid row' } else { $global:testHistoryRows[1] }
}
'@ | Set-Content -Encoding UTF8 $fakeFzf
    function Get-Command {
        param($Name, $CommandType, $ErrorAction)
        if (-not $script:missingFzf) { [pscustomobject]@{ Source = $fakeFzf } }
    }
    $originalEncoding = $OutputEncoding
    $env:FZF_DEFAULT_OPTS = '--print-query --multi'
    $env:FZF_DEFAULT_OPTS_FILE = 'fixture-file'
    $global:testHistoryExit = 0
    $global:LASTEXITCODE = 73
    $command = "Write-Output '한글'`nWrite-Output 'second'"
    $result = Select-DotfilesHistory @('older', $command) '한글'
    if ($result.Status -ne 'selected' -or $result.Value -cne $command) { throw 'Original command not restored' }
    $runtimeFzfArgs = @($global:testHistoryArgs)
    if ($global:testHistoryArgs -notcontains '--query=한글' -or $global:testHistoryRows.Count -ne 2 -or $global:testHistoryRows[1].Contains("`n")) { throw 'Query/display mapping failed' }
    if ($env:FZF_DEFAULT_OPTS -ne '--print-query --multi' -or $env:FZF_DEFAULT_OPTS_FILE -ne 'fixture-file' -or $LASTEXITCODE -ne 73 -or $OutputEncoding -ne $originalEncoding) { throw 'Caller state not restored' }
    foreach ($exitCode in @(1, 130, 2)) {
        $global:testHistoryExit = $exitCode
        $expected = if ($exitCode -eq 2) { 'unavailable' } else { 'cancelled' }
        if ((Select-DotfilesHistory @('a', 'b')).Status -ne $expected) { throw 'Cancellation/failure failed' }
    }
    $global:testHistoryExit = 0
    $global:testHistoryInvalid = $true
    if ((Select-DotfilesHistory @('a', 'b')).Status -ne 'unavailable') { throw 'Invalid row accepted' }
    $script:missingFzf = $true
    if ((Select-DotfilesHistory @('a')).Status -ne 'unavailable') { throw 'Missing fzf fallback failed' }
    Remove-Item Function:\Get-Command
    if ((Get-PSReadLineKeyHandler | Where-Object Key -eq 'Ctrl+r').Function -ne 'FzfHistory') { throw 'Key binding missing' }
    $realFzf = Get-Command fzf.exe -CommandType Application -ErrorAction Stop
    $env:FZF_DEFAULT_OPTS = ''
    $env:FZF_DEFAULT_OPTS_FILE = ''
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $selected = @(@("0`tfixture-old", "1`tfixture-한글") | & $realFzf.Source @runtimeFzfArgs --filter=한글)
    if ($LASTEXITCODE -ne 0 -or $selected.Count -ne 1 -or $selected[0] -ne "1`tfixture-한글") { throw 'Real fzf Unicode selection failed' }
    'PASS: history order, dedup, Unicode, multiline mapping, query, cancellation/failure, state restoration, binding and real fzf.'
} finally {
    if (Test-Path Function:\Get-Command) { Remove-Item Function:\Get-Command }
    $env:FZF_DEFAULT_OPTS = $savedOptions
    $env:FZF_DEFAULT_OPTS_FILE = $savedFile
    Remove-Item -LiteralPath $fixturePath, $fakeFzf -ErrorAction SilentlyContinue
    Remove-Variable testHistoryArgs, testHistoryRows, testHistoryExit, testHistoryInvalid -Scope Global -ErrorAction SilentlyContinue
}

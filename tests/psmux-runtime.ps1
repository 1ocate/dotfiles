#Requires -Version 5.1
# Runtime approval, alias preservation, PATH order and project naming without installs.
$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/psmux.ps1'
$testRoot = Join-Path $env:TEMP ('dotfiles-psmux-runtime-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $testRoot 'powershell') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot '.local') | Out-Null
$runtime = Join-Path $testRoot 'powershell/psmux.ps1'
Copy-Item -LiteralPath $source -Destination $runtime
$selectionPath = Join-Path $testRoot '.local/environment.json'
$featurePath = Join-Path $testRoot '.local/psmux.json'
$selection = @{ schemaVersion=1; environment='windows-powershell'; host=[Environment]::MachineName; approved=$true }
$feature = @{ schemaVersion=1; host=[Environment]::MachineName; enabled=$true; version='3.3.8' }
function Save-TestStates {
    $selection | ConvertTo-Json | Set-Content -LiteralPath $selectionPath -Encoding UTF8
    $feature | ConvertTo-Json | Set-Content -LiteralPath $featurePath -Encoding UTF8
}
function Assert-NoActivation {
    $beforePath = $env:Path
    $output = . $runtime
    if ($output) { throw 'Unapproved profile emitted unsolicited output.' }
    if (Get-Command Invoke-DotfilesMux -ErrorAction SilentlyContinue) { throw 'Unapproved runtime activated.' }
    $status = Get-DotfilesMuxStatus
    if ($status.Status -ne 'Blocked' -or -not $status.Reason -or -not $status.Action -or $status.Repository -ne $testRoot) { throw 'Blocked runtime lacks actionable diagnostics rooted in its checkout.' }
    if ($env:Path -ne $beforePath) { throw 'Diagnostics changed PATH.' }
}
Assert-NoActivation
if ((Get-DotfilesMuxStatus).Reason -notmatch 'missing or invalid') { throw 'Missing records not diagnosed.' }
Save-TestStates
$selection.environment='windows-wsl'; Save-TestStates; Assert-NoActivation
$selection.environment='windows-powershell'; $selection.host='other-host'; Save-TestStates; Assert-NoActivation
if ((Get-DotfilesMuxStatus).Reason -notmatch 'Environment host differs') { throw 'Environment host mismatch not diagnosed.' }
$selection.host=[Environment]::MachineName; $selection.approved='true'; Save-TestStates; Assert-NoActivation
if ((Get-DotfilesMuxStatus).Reason -notmatch 'boolean true') { throw 'String approval not diagnosed.' }
$selection.approved=$true; $feature.host='other-host'; Save-TestStates; Assert-NoActivation
if ((Get-DotfilesMuxStatus).Reason -notmatch 'psmux host differs') { throw 'Feature host mismatch not diagnosed.' }
$feature.host=[Environment]::MachineName; $feature.enabled=$false; Save-TestStates; Assert-NoActivation
$feature.enabled='true'; Save-TestStates; Assert-NoActivation
$feature.enabled=$true; Save-TestStates
$originalLocalAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = $testRoot
    Assert-NoActivation
    if ((Get-DotfilesMuxStatus).Reason -notmatch 'executable is missing') { throw 'Missing pinned binaries not diagnosed.' }
} finally { $env:LOCALAPPDATA = $originalLocalAppData }
function global:t { 'user-project-command' }
function global:mux { 'user-mux-command' }
. $runtime
if (-not (Get-Command Invoke-DotfilesMux -ErrorAction SilentlyContinue)) { throw 'Approved runtime did not activate; installed binaries required.' }
$stateBefore = @((Get-FileHash $selectionPath).Hash, (Get-FileHash $featurePath).Hash)
$status = Get-DotfilesMuxStatus
if ($status.Status -ne 'Ready' -or -not $status.PsmuxPresent -or -not $status.TmuxPresent) { throw 'Valid runtime prerequisites not diagnosed.' }
if ($stateBefore[0] -ne (Get-FileHash $selectionPath).Hash -or $stateBefore[1] -ne (Get-FileHash $featurePath).Hash) { throw 'Diagnostics wrote approval records.' }
if ((t) -ne 'user-project-command' -or (mux) -ne 'user-mux-command') { throw 'Existing user commands were overwritten.' }
$expectedTmux = Join-Path $env:LOCALAPPDATA 'Programs/psmux/3.3.8/tmux.exe'
if ((Get-Command tmux).Source -ne $expectedTmux) { throw 'Pinned tmux.exe is not first on PATH.' }
# Replace only the server entry in this isolated test process.
function global:Invoke-DotfilesMux { param($Session,$Path); [pscustomobject]@{Session=$Session;Path=$Path} }
$projectA = Join-Path $testRoot 'one/프로젝트 이름'
$projectB = Join-Path $testRoot 'two/프로젝트 이름'
New-Item -ItemType Directory -Path $projectA,$projectB -Force | Out-Null
$a=Invoke-DotfilesProject -Path $projectA
$b=Invoke-DotfilesProject -Path $projectB
$repeat=Invoke-DotfilesProject -Path $projectA
if ($a.Session -eq $b.Session -or $a.Session -ne $repeat.Session -or $a.Path -ne $projectA) { throw 'Project names collided or Unicode path changed.' }
# A pane prompt must clear stale editor identity without changing prompt content.
$env:TMUX='/tmp/psmux-test/dotfiles,1,0'
function global:prompt { 'custom-prompt>' }
. $runtime
$wrappedPrompt=(Get-Item Function:\prompt).ScriptBlock.ToString()
. $runtime
if($wrappedPrompt -ne (Get-Item Function:\prompt).ScriptBlock.ToString()){throw 'Repeat wrapped prompt twice.'}
$previousWriter=[Console]::Out
$writer=[System.IO.StringWriter]::new()
try {
    [Console]::SetOut($writer)
    $promptText=prompt
} finally { [Console]::SetOut($previousWriter) }
if($promptText -ne 'custom-prompt>' -or $writer.ToString() -ne ([char]27 + ']133;A' + [char]7)){throw 'Prompt content or stale identity reset changed.'}
function global:prompt { "success=$?;exit=$LASTEXITCODE" }
. $runtime
$writer=[System.IO.StringWriter]::new()
try {
    [Console]::SetOut($writer)
    & cmd.exe /c exit 7
    $statusPrompt=prompt
} finally { [Console]::SetOut($previousWriter) }
if($statusPrompt -ne 'success=False;exit=7'){throw "Prompt command status changed: $statusPrompt"}
Write-Output 'PASS: pane prompt preserves user content and resets stale editor identity once.'
Write-Output 'PASS: runtime approvals, host/environment isolation, user commands, pinned PATH, Unicode paths and stable distinct project names.'
Write-Output 'PASS: explicit read-only diagnostics explain missing records, host mismatch and invalid approval without profile output.'
Write-Output "Only temporary test files were written: $testRoot"

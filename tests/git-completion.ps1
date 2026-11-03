# Run in a shell that loads the real user profile after setup-git-completion.
param([switch]$LoadSource)
$ErrorActionPreference = 'Stop'
if ($LoadSource) {
    $beforeImport = (Get-Item Function:\prompt).ScriptBlock.ToString()
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/git-completion.ps1')
    if ((Get-Item Function:\prompt).ScriptBlock.ToString() -ne $beforeImport) { throw 'First import changed the prompt.' }
    Write-Output 'PASS: first import preserves the default prompt.'
}
if (-not (Get-Command Import-DotfilesGitCompletion -ErrorAction SilentlyContinue)) { throw 'Git completion was not registered by the user profile.' }
if (Get-Module posh-git) { throw 'posh-git was imported at startup instead of on the first git Tab.' }
Write-Output 'PASS: posh-git is not imported at startup.'
$promptBeforeTab = (Get-Item Function:\prompt).ScriptBlock.ToString()
foreach ($line in @('git checkout feat/', 'git switch feat/')) {
    $matches = (TabExpansion2 $line $line.Length).CompletionMatches.CompletionText
    if ($matches -notcontains 'feat/windows-native-setup') { throw "Branch completion failed: $line" }
    Write-Output "PASS: $line -> feat/windows-native-setup"
}
if (-not (Get-Module posh-git)) { throw 'The first git Tab did not import posh-git.' }
if ((Get-Item Function:\prompt).ScriptBlock.ToString() -ne $promptBeforeTab) { throw 'Lazy import changed the prompt.' }
Write-Output 'PASS: first git Tab imports posh-git and preserves the prompt.'
$originalPrompt = (Get-Item Function:\prompt).ScriptBlock.ToString()
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/git-completion.ps1')
if ((Get-Item Function:\prompt).ScriptBlock.ToString() -ne $originalPrompt) { throw 'Completion changed the prompt.' }
Write-Output 'PASS: existing prompt preserved.'

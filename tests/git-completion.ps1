# Run in a shell that loads the real user profile after setup-git-completion.
param([switch]$LoadSource)
$ErrorActionPreference = 'Stop'
if ($LoadSource) {
    $beforeImport = (Get-Item Function:\prompt).ScriptBlock.ToString()
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/git-completion.ps1')
    if ((Get-Item Function:\prompt).ScriptBlock.ToString() -ne $beforeImport) { throw 'First import changed the prompt.' }
    Write-Output 'PASS: first import preserves the default prompt.'
}
if (-not (Get-Module posh-git)) { throw 'posh-git was not loaded by the user profile.' }
foreach ($line in @('git checkout feat/', 'git switch feat/')) {
    $matches = (TabExpansion2 $line $line.Length).CompletionMatches.CompletionText
    if ($matches -notcontains 'feat/windows-native-setup') { throw "Branch completion failed: $line" }
    Write-Output "PASS: $line -> feat/windows-native-setup"
}
$originalPrompt = (Get-Item Function:\prompt).ScriptBlock.ToString()
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/git-completion.ps1')
if ((Get-Item Function:\prompt).ScriptBlock.ToString() -ne $originalPrompt) { throw 'Completion changed the prompt.' }
Write-Output 'PASS: existing prompt preserved.'

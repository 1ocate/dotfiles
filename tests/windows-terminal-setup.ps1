#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$setup = Join-Path $repo 'scripts/setup-windows.ps1'
$testRoot = Join-Path $env:TEMP ('dotfiles-terminal-setup-' + [guid]::NewGuid())
$testScripts = Join-Path $testRoot 'scripts'
New-Item -ItemType Directory -Path $testScripts | Out-Null
Copy-Item -LiteralPath $setup -Destination $testScripts
'function Write-WindowsSelectionStatus { param($RepoPath) "mock selection (read-only)" }' | Set-Content (Join-Path $testScripts 'windows-environment.ps1')
'param([switch]$Plan, [switch]$Check); if (-not ($Plan -or $Check)) { throw "Unexpected apply" }; "mock adapter Plan=$Plan Check=$Check"' | Set-Content (Join-Path $testScripts 'use-windows-terminal.ps1')
'param([switch]$Plan, [switch]$Check); if (-not ($Plan -or $Check)) { throw "Unexpected font apply" }; "mock font Plan=$Plan Check=$Check"' | Set-Content (Join-Path $testScripts 'setup-meslo-font.ps1')
'param([switch]$Plan, [switch]$Check); if (-not ($Plan -or $Check)) { throw "Unexpected aliases apply" }; "mock aliases Plan=$Plan Check=$Check"' | Set-Content (Join-Path $testScripts 'setup-powershell-aliases.ps1')
$testSetup = Join-Path $testScripts 'setup-windows.ps1'
$common = @{ Plan=$true; SkipGitCompletion=$true; SkipAutoHotkey=$true }
$defaultPlan = (& $testSetup @common) -join "`n"
if ($defaultPlan -notmatch 'Microsoft.WindowsTerminal' -or $defaultPlan -match 'wez.wezterm' -or $defaultPlan -notmatch 'mock adapter Plan=True Check=False' -or $defaultPlan -notmatch 'mock font Plan=True Check=False') { throw 'Default terminal Plan regression.' }
if ($defaultPlan -notmatch 'mock aliases Plan=True Check=False') { throw 'Default setup omitted PowerShell aliases.' }
$weztermPlan = (& $testSetup @common -Terminal wezterm) -join "`n"
if ($weztermPlan -notmatch 'wez.wezterm' -or $weztermPlan -match 'Microsoft.WindowsTerminal|mock adapter') { throw 'Explicit WezTerm Plan regression.' }
if (Test-Path (Join-Path $testRoot '.local')) { throw 'Plan wrote local state.' }
$oldOS = $env:OS
try {
    $env:OS = 'Linux'
    try { & $testSetup @common; throw 'Expected native Windows rejection.' }
    catch { if ($_.Exception.Message -notmatch 'requires native Windows') { throw } }
} finally { $env:OS = $oldOS }
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Setup AST syntax errors.' }
$aliasCalls = @($ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
    $node.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and
    $node.Extent.Text -match 'setup-powershell-aliases\.ps1'
}, $true))
if ($aliasCalls.Count -ne 3 -or @($aliasCalls | Where-Object { $_.Extent.Text -match '\s-Plan\b' }).Count -ne 1 -or
    @($aliasCalls | Where-Object { $_.Extent.Text -match '\s-Check\b' }).Count -ne 1) { throw 'Alias setup must be called in Plan, Check and apply.' }
$prerequisite = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-SetupPrerequisites' }, $true)
Invoke-Expression $prerequisite.Extent.Text
$SkipGitCompletion = $true
$SkipPlugins = $true
$SkipAutoHotkey = $true
$RegisterAutoHotkeyStartup = $false
function Get-Command { param($Name, $CommandType, $ErrorAction) if ($Name -ne $script:missingTool) { [pscustomobject]@{Source=$Name} } }
foreach ($terminalCommand in @('wt', 'wezterm')) {
    $script:missingTool = if ($terminalCommand -eq 'wt') { 'wezterm' } else { 'wt' }
    Test-SetupPrerequisites | Out-Null
    $script:missingTool = $terminalCommand
    try { Test-SetupPrerequisites; throw 'Expected selected terminal prerequisite failure.' }
    catch { if ($_.Exception.Message -notlike "Missing required tools: $terminalCommand.*") { throw } }
}
Write-Output 'PASS: default/explicit terminal Plan, no approval write, non-Windows guard, selected terminal prerequisites, AST.'
Write-Output "Only temporary mock files were written: $testRoot"

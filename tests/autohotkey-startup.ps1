$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../scripts/setup-windows.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Resolve-AutoHotkeyStartup' }, $true)
Invoke-Expression $function.Extent.Text
function Read-Host { throw 'Startup registration must not prompt.' }
foreach ($case in @(
    @($false, $false, $false, $true),
    @($true, $false, $false, $true),
    @($false, $true, $false, $false),
    @($false, $false, $true, $false),
    @($false, $true, $true, $false),
    @($true, $false, $true, $true)
)) {
    $actual = Resolve-AutoHotkeyStartup -Register $case[0] -Skip $case[1] -SkipCurrentRun $case[2]
    if ($actual -ne $case[3]) { throw "Startup choice failed: $case" }
}
$registrationOnly = & $source -Plan -SkipAutoHotkey -RegisterAutoHotkeyStartup | Out-String
if ($registrationOnly -notmatch 'Register AutoHotkey to start at Windows login' -or $registrationOnly -match 'Start the AutoHotkey v2 script') { throw 'Registration-only Plan is incorrect.' }
$plan = & $source -Plan | Out-String
if ($plan -notmatch 'Register AutoHotkey to start at Windows login') { throw 'Default Plan omits startup registration.' }
foreach ($option in @('SkipAutoHotkeyStartup', 'SkipAutoHotkey')) {
    $options = @{Plan=$true}; $options[$option] = $true
    if ((& $source @options | Out-String) -match 'Register AutoHotkey to start at Windows login') { throw "Plan ignores $option" }
}
try {
    & $source -Plan -RegisterAutoHotkeyStartup -SkipAutoHotkeyStartup
    throw 'Conflicting options were accepted.'
} catch {
    if ($_.Exception.Message -notmatch 'cannot be combined') { throw }
}
Write-Output 'AutoHotkey startup choices and syntax passed; no installation or startup registration performed.'

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../scripts/setup-windows.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Resolve-AutoHotkeyStartup' }, $true)
Invoke-Expression $function.Extent.Text
$script:promptCount = 0
function Read-Host { param($Prompt) $script:promptCount++; return $script:answer }
foreach ($case in @(
    @($true, $false, $false, $false, '', $true, 0),
    @($false, $true, $false, $true, 'y', $false, 0),
    @($false, $false, $true, $true, 'y', $false, 0),
    @($true, $false, $true, $true, '', $true, 0),
    @($false, $false, $false, $false, 'y', $false, 0),
    @($false, $false, $false, $true, '', $false, 1),
    @($false, $false, $false, $true, 'n', $false, 1),
    @($false, $false, $false, $true, 'unexpected', $false, 1),
    @($false, $false, $false, $true, 'y', $true, 1),
    @($false, $false, $false, $true, 'YES', $true, 1)
)) {
    $script:answer = $case[4]
    $script:promptCount = 0
    $actual = Resolve-AutoHotkeyStartup -Register $case[0] -Skip $case[1] -SkipCurrentRun $case[2] -Interactive $case[3]
    if ($actual -ne $case[5] -or $script:promptCount -ne $case[6]) { throw "Startup choice failed: $case" }
}
try {
    & $source -Plan -RegisterAutoHotkeyStartup -SkipAutoHotkeyStartup
    throw 'Conflicting options were accepted.'
} catch {
    if ($_.Exception.Message -notmatch 'cannot be combined') { throw }
}
Write-Output 'AutoHotkey startup choices and syntax passed; no installation or startup registration performed.'

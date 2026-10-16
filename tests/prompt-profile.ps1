#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$setup = Join-Path $repo 'scripts/setup-windows.ps1'
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Setup syntax errors.' }
$loop = $ast.Find({ param($node) $node -is [Management.Automation.Language.ForEachStatementAst] -and $node.Variable.VariablePath.UserPath -eq 'profileFolder' }, $true)
$configAssignment = $ast.Find({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$promptConfigPath' }, $true)
if (-not $loop -or -not $configAssignment) { throw 'Profile setup block not found.' }
$setupBlock = [scriptblock]::Create($configAssignment.Extent.Text + "`n" + $loop.Extent.Text)
$testRoot = Join-Path $env:TEMP ("dotfiles-prompt-'profile-" + [guid]::NewGuid())
$documentsPath = Join-Path $testRoot 'Documents'
$repoPath = Join-Path $testRoot ('source with space ' + [char]0xD55C)
New-Item -ItemType Directory -Path $documentsPath -Force | Out-Null
$ps7 = Join-Path $documentsPath 'PowerShell/Microsoft.PowerShell_profile.ps1'
$ps51 = Join-Path $documentsPath 'WindowsPowerShell/Microsoft.PowerShell_profile.ps1'
. $setupBlock
$created7 = [IO.File]::ReadAllText($ps7)
$created51 = [IO.File]::ReadAllText($ps51)
if ($created7 -notmatch "--config '((?:''|[^'])*)'") { throw 'PowerShell 7 did not pin the theme.' }
$resolvedConfig = $Matches[1].Replace("''", "'")
if ($resolvedConfig -ne (Join-Path $repoPath 'powershell/prompt.omp.json')) { throw 'Checkout path quoting failed.' }
if ($created51 -match '--config' -or $created51 -notmatch 'oh-my-posh init pwsh --eval') { throw 'Windows PowerShell 5.1 initializer changed.' }
foreach ($profile in @($ps7, $ps51)) {
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($profile, [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count) { throw 'Generated profile is not valid PowerShell.' }
}
. $setupBlock
if ([IO.File]::ReadAllText($ps7) -cne $created7 -or [IO.File]::ReadAllText($ps51) -cne $created51) { throw 'Re-run changed existing profiles.' }
$custom = '# user custom theme' + "`r`n" + 'oh-my-posh init pwsh --config user-custom.json | Invoke-Expression'
[IO.File]::WriteAllText($ps7, $custom, [Text.Encoding]::Unicode)
$customBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ps7))
. $setupBlock
if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($ps7)) -cne $customBytes) { throw 'Existing user theme or encoding was replaced.' }
$preserved = '# preserved text ' + [char]0xD55C + "`r`n"
[IO.File]::WriteAllText($ps7, $preserved, [Text.Encoding]::Unicode)
. $setupBlock
$updatedBytes = [IO.File]::ReadAllBytes($ps7)
if ($updatedBytes[0] -ne 255 -or $updatedBytes[1] -ne 254 -or -not [IO.File]::ReadAllText($ps7).StartsWith($preserved)) { throw 'Existing profile encoding/text lost.' }
$backups = @(Get-ChildItem -LiteralPath (Split-Path $ps7) -Filter '*.backup-*')
if ($backups.Count -ne 1 -or [IO.File]::ReadAllText($backups[0].FullName) -cne $preserved) { throw 'Existing profile backup missing or incorrect.' }
. $setupBlock
if (@(Get-ChildItem -LiteralPath (Split-Path $ps7) -Filter '*.backup-*').Count -ne 1) { throw 'Re-run added backups or duplicate initialization.' }
$theme = [IO.File]::ReadAllText((Join-Path $repo 'powershell/prompt.omp.json')) | ConvertFrom-Json
if ($theme.streaming -ne 100 -or $theme.blocks[0].segments[0].type -ne 'session') { throw 'Built-in theme snapshot or streaming missing.' }
if (@($theme.blocks[0].segments | Where-Object { $_.type -eq 'status' })[0].template -match 'CONFIG NOT FOUND|CONFIG ERROR') { throw 'Exported an error fallback instead of the built-in default.' }
Write-Output 'PASS: fresh PS7 source reference, PS5.1 compatibility, quote/space/Unicode paths, valid syntax, re-run, custom theme preservation, encoding and backup.'
Write-Output "Only temporary mock profiles were changed: $testRoot"

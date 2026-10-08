#Requires -Version 5.1
# Temporary targets only; no real Windows Terminal settings or profiles are changed.
$ErrorActionPreference='Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts/windows-terminal.ps1')
$stage = Join-Path $repo ('.local/windows-terminal-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
$stagedRepo = Join-Path $stage 'repo 한글'
New-Item -ItemType Directory -Path (Join-Path $stagedRepo 'scripts'), (Join-Path $stagedRepo 'windows-terminal') -Force | Out-Null
foreach ($name in @('windows-terminal.ps1','use-windows-terminal.ps1','windows-environment.ps1','environment.py')) {
    Copy-Item -LiteralPath (Join-Path $repo ('scripts/' + $name)) -Destination (Join-Path $stagedRepo ('scripts/' + $name))
}
$source = Join-Path $stagedRepo 'windows-terminal/settings.json'
Copy-Item -LiteralPath (Join-Path $repo 'windows-terminal/settings.json') -Destination $source
Copy-Item -LiteralPath (Join-Path $repo 'windows-terminal/.gitignore') -Destination (Join-Path $stagedRepo 'windows-terminal/.gitignore')
$beforeLocalAppData = $env:LOCALAPPDATA
$beforeOS = $env:OS
$realFactory = (Get-Item Function:\New-WindowsTerminalDirectoryLink).ScriptBlock
try {
    $env:LOCALAPPDATA = Join-Path $stage 'appdata'
    $stable = Get-WindowsTerminalTarget
    $preview = Get-WindowsTerminalTarget -Channel preview
    $unpackaged = Get-WindowsTerminalTarget -Channel unpackaged
    if (@($stable,$preview,$unpackaged | Select-Object -Unique).Count -ne 3) { throw 'Channels must have separate paths.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $stable) -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path (Split-Path -Parent $stable) 'state.json'), '{"runtime":"private"}')
    $original = '{"privateProfile":"do-not-publish"}'
    [IO.File]::WriteAllText($stable,$original)
    & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') -Plan -ApprovePowerShell | Out-Null
    & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') -Check | Out-Null
    if (Test-Path (Join-Path $stagedRepo '.local')) { throw 'Plan/Check created local state.' }
    if ([IO.File]::ReadAllText($stable) -ne $original) { throw 'Plan/Check changed existing settings.' }
    Write-Output 'PASS: explicit channel paths; Plan/Check preserve settings and do not create approval/state.'
    $blocked=$false
    try { & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null } catch { $blocked=$true }
    if (-not $blocked -or [IO.File]::ReadAllText($stable) -ne $original) { throw 'Unapproved apply changed settings.' }
    Write-Output 'PASS: unapproved apply stops without touching settings.'
    Set-Item Function:\New-WindowsTerminalDirectoryLink -Value { param($LinkPath,$SourceDirectory); throw 'Simulated denied junction creations' }
    $denied=$false
    try { Connect-WindowsTerminalSource -SourcePath $source -TargetPath $stable | Out-Null } catch { $denied=$true }
    if (-not $denied -or [IO.File]::ReadAllText($stable) -ne $original -or @(Get-ChildItem (Split-Path -Parent (Split-Path -Parent $stable)) -Filter '*.backup-*').Count) { throw 'Denied linking must precede backup/move.' }
    Set-Item Function:\New-WindowsTerminalDirectoryLink -Value $realFactory
    Write-Output 'PASS: junction creation failure preserves original before any backup/move.'
    $env:OS='not-Windows'
    $blocked=$false
    try { Connect-WindowsTerminalSource -SourcePath $source -TargetPath $stable | Out-Null } catch { $blocked=$true }
    $env:OS=$beforeOS
    if (-not $blocked) { throw 'Non-Windows must not apply.' }
    Write-Output 'PASS: non-Windows apply is blocked.'
    & py -3 (Join-Path $stagedRepo 'scripts/environment.py') select --environment windows-powershell | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test-local approval registration failed.' }
    & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null
    $setupPath = Join-Path $stagedRepo '.local/setup-state.json'
    $firstState = [IO.File]::ReadAllText($setupPath)
    & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null
    if ([IO.File]::ReadAllText($setupPath) -ne $firstState) { throw 'Repeated apply rewrote verified local state.' }
    $connection = Get-WindowsTerminalConnection -SourcePath $source -TargetPath $stable
    $backupItem = @(Get-ChildItem (Split-Path -Parent (Split-Path -Parent $stable)) -Filter '*.backup-*')
    if ($backupItem.Count -ne 1) { throw 'Expected one directory backup.' }
    $connection | Add-Member -NotePropertyName Backup -NotePropertyValue $backupItem[0].FullName
    Write-Output 'PASS: approved adapter automatically connects the source and records verified local state once.'
    $savedState = $firstState | ConvertFrom-Json
    if (-not $savedState.components.windows_terminal.backup) { throw 'Settings backup path was not recorded.' }
    $changedHost = $firstState | ConvertFrom-Json
    $changedHost.host = 'another-test-host'
    $changedHost | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $setupPath -Encoding UTF8
    $blocked=$false
    try { & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null } catch { $blocked=$true }
    if (-not $blocked) { throw 'Other-host progress was silently reused.' }
    & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') -ArchivePreviousProgress | Out-Null
    $newState = Get-Content -LiteralPath $setupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $newState.previous_progress_backup) -or $newState.host -ne [Environment]::MachineName) { throw 'Explicit progress archive did not preserve old state and create current state.' }
    $archivedState = Get-Content -LiteralPath $newState.previous_progress_backup -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($archivedState.components.windows_terminal.backup -ne $savedState.components.windows_terminal.backup) { throw 'Archived progress lost the prior recovery path.' }
    [IO.File]::WriteAllText($setupPath,$firstState)
    Write-Output 'PASS: other-host progress blocks apply; explicit archive preserves prior state without importing completed stages.'
    $priorChannel = $firstState | ConvertFrom-Json
    $priorChannel.components.windows_terminal.channel='preview'
    $priorChannel.components.windows_terminal.target=$preview
    $priorChannel | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $setupPath -Encoding UTF8
    $previewDirectory = Split-Path -Parent $preview
    New-Item -ItemType Directory -Path (Split-Path -Parent $previewDirectory) -Force | Out-Null
    New-WindowsTerminalDirectoryLink -LinkPath $previewDirectory -SourceDirectory (Split-Path -Parent $source)
    $blocked=$false
    try { & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null } catch { $blocked=$true }
    if (-not $blocked) { throw 'Two channels sharing runtime source were allowed.' }
    $otherHostWithChannel = Get-Content -LiteralPath $setupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $otherHostWithChannel.host='another-test-host'
    $otherHostWithChannel | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $setupPath -Encoding UTF8
    $blocked=$false
    try { & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') -ArchivePreviousProgress | Out-Null } catch { $blocked=$true }
    if (-not $blocked) { throw 'Archiving progress bypassed real channel isolation.' }
    [IO.File]::Delete($setupPath)
    $blocked=$false
    try { & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null } catch { $blocked=$true }
    if (-not $blocked) { throw 'Missing progress bypassed real channel isolation.' }
    [IO.File]::WriteAllText($setupPath,$firstState)
    [IO.Directory]::Delete($previewDirectory,$false)
    New-Item -ItemType Directory -Path $previewDirectory | Out-Null
    [IO.File]::WriteAllText($preview,'{"restored":true}')
    & (Join-Path $stagedRepo 'scripts/use-windows-terminal.ps1') | Out-Null
    [IO.File]::WriteAllText($setupPath,$firstState)
    Write-Output 'PASS: active other channel blocks apply; restored previous channel allows transition.'
    $oldPath=$env:PATH
    try {
        $env:PATH=$stage
        $blocked=$false
        & { function wt {}; function pwsh {}; try { Assert-WindowsTerminalPrograms -Channel stable -TargetPath $stable } catch { $script:blocked=$true } }
        if (-not $blocked) { throw 'Functions were accepted as executable prerequisites.' }
    } finally { $env:PATH=$oldPath }
    Write-Output 'PASS: functions without actual executables do not satisfy terminal prerequisites.'

    if ($connection.Status -ne 'linked' -or [IO.File]::ReadAllText((Join-Path $connection.Backup 'settings.json')) -ne $original) { throw 'Existing settings were not backed up and linked.' }
    if ([IO.File]::ReadAllText((Join-Path $connection.Backup 'state.json')) -ne '{"runtime":"private"}') { throw 'Old runtime state was not backed up.' }
    $backupCount = @(Get-ChildItem (Split-Path -Parent (Split-Path -Parent $stable)) -Filter '*.backup-*').Count
    $repeat = Connect-WindowsTerminalSource -SourcePath $source -TargetPath $stable
    if ($repeat.Status -ne 'linked' -or @(Get-ChildItem (Split-Path -Parent (Split-Path -Parent $stable)) -Filter '*.backup-*').Count -ne $backupCount) { throw 'Repeat created another backup.' }
    Write-Output 'PASS: real directory junction backs up private settings and repeated apply preserves the link.'
    $replacement = $source + '.new'
    [IO.File]::WriteAllText($replacement,'{"revision":2}')
    [IO.File]::Delete($source)
    [IO.File]::Move($replacement,$source)
    if ([IO.File]::ReadAllText($stable) -ne '{"revision":2}') { throw 'Source replacement broke the link.' }
    Write-Output 'PASS: source replacement (Git checkout behavior) remains visible through the link.'
    $uiTemporary = Join-Path (Split-Path -Parent $stable) 'settings.ui-temp'
    [IO.File]::WriteAllText($uiTemporary,'{"revision":3}')
    [IO.File]::Delete($stable)
    [IO.File]::Move($uiTemporary,$stable)
    if ([IO.File]::ReadAllText($source) -ne '{"revision":3}' -or (Get-WindowsTerminalConnection -SourcePath $source -TargetPath $stable).Status -ne 'linked') { throw 'UI-style atomic file replacement broke source linkage.' }
    Write-Output 'PASS: atomic replacement through the target changes the Git source and keeps the directory junction.'
} finally {
    $env:LOCALAPPDATA=$beforeLocalAppData
    $env:OS=$beforeOS
    Set-Item Function:\New-WindowsTerminalDirectoryLink -Value $realFactory
    # Delete only this test's known file links before walking its ordinary directories.
    $targetDirectory = if ($stable) { Split-Path -Parent $stable } else { $null }
    if ($preview -and (Get-Item -LiteralPath (Split-Path -Parent $preview) -Force -ErrorAction SilentlyContinue).LinkType -eq 'Junction') { [IO.Directory]::Delete((Split-Path -Parent $preview), $false) }
    if ($targetDirectory -and (Get-Item -LiteralPath $targetDirectory -Force -ErrorAction SilentlyContinue).LinkType -eq 'Junction') { [IO.Directory]::Delete($targetDirectory, $false) }
    $resolved = [IO.Path]::GetFullPath($stage)
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.local')) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Test cleanup escaped .local.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

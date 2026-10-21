#Requires -Version 5.1
# Temporary profiles and -u NONE only; no real profile or Neovim state changes.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts/setup-powershell-aliases.ps1')
$stage = Join-Path $repo ('.local/aliases-test-' + [guid]::NewGuid().ToString('N'))
$stagedRepo = Join-Path $stage "repo ' 한글"
$documents = Join-Path $stage 'documents'
New-Item -ItemType Directory -Path (Join-Path $stagedRepo 'powershell'), (Join-Path $stagedRepo 'scripts') -Force | Out-Null
$runtime = Join-Path $stagedRepo 'powershell/aliases.ps1'
Copy-Item -LiteralPath (Join-Path $repo 'powershell/aliases.ps1') -Destination $runtime
# This adapter must never be loaded: aliases are independent of environment approval.
@'
function Assert-WindowsPowerShellSelection {
    param($RepoPath)
    throw 'Aliases must not require environment approval.'
}
'@ | Set-Content -LiteralPath (Join-Path $stagedRepo 'scripts/windows-environment.ps1') -Encoding UTF8
function Expect-AliasFailure {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action; throw 'Expected failure was not raised.' }
    catch { if ($_.Exception.Message -notmatch $Pattern) { throw } }
}
$arguments = @{RepoPath=$stagedRepo;DocumentsPath=$documents}
Invoke-PowerShellAliasesSetup @arguments -Plan | Out-Null
Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments -Check } 'loader is missing'
if ((Test-Path $documents) -or (Test-Path (Join-Path $stagedRepo '.local'))) { throw 'Plan/Check created state or profiles.' }
Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments -Plan -Check } 'cannot be combined'
$stateDirectory = Join-Path $stagedRepo '.local'
New-Item -ItemType Directory -Path $stateDirectory | Out-Null
$selectionPath = Join-Path $stateDirectory 'environment.json'
$selection = [ordered]@{schemaVersion=1;approved=$true;host='unrelated-device';environment='windows-powershell'}
function Save-AliasSelection { $selection | ConvertTo-Json | Set-Content -LiteralPath $selectionPath -Encoding UTF8 }
Save-AliasSelection
$profiles = @('WindowsPowerShell','PowerShell') | ForEach-Object { Join-Path $documents "$_/Microsoft.PowerShell_profile.ps1" }
$originals = @()
for ($index=0; $index -lt $profiles.Count; $index++) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $profiles[$index]) -Force | Out-Null
    $encoding = if ($index -eq 0) { [Text.Encoding]::Unicode } else { [Text.UTF8Encoding]::new($true) }
    [IO.File]::WriteAllText($profiles[$index], "# user profile preserved`r`n", $encoding)
    $originals += ,([IO.File]::ReadAllBytes($profiles[$index]))
}
[IO.File]::WriteAllBytes($profiles[0], [byte[]]@(35,32,199,209,177,219,13,10))
$ambiguousBytes = [IO.File]::ReadAllBytes($profiles[0])
Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments } 'ambiguous without a BOM'
if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($profiles[0])) -ne [Convert]::ToBase64String($ambiguousBytes)) { throw 'Ambiguous encoding was changed.' }
[IO.File]::WriteAllText($profiles[0], '# 한글', [Text.UTF8Encoding]::new($false))
Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments } 'ambiguous without a BOM'
[IO.File]::WriteAllText($profiles[0], '# ASCII without BOM', [Text.UTF8Encoding]::new($false))
Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments } 'ambiguous without a BOM'
if ((Test-Path (Join-Path $stateDirectory 'powershell-aliases.json')) -or @(Get-ChildItem $documents -Recurse -Filter '*.backup-*').Count -or
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($profiles[1])) -ne [Convert]::ToBase64String($originals[1])) { throw 'Rejected encoding changed another profile or created backups/state.' }
[IO.File]::WriteAllBytes($profiles[0], $originals[0])
$legacyStatePath = Join-Path $stateDirectory 'setup-state.json'
$progress = @{host='unrelated-device';environment='windows-powershell';components=@{unrelated=@{status='preserved'}}}
$progress | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $legacyStatePath -Encoding UTF8
$legacyStateBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($legacyStatePath))
$statePath = Join-Path $stateDirectory 'powershell-aliases.json'
'{}' | Set-Content -LiteralPath $statePath -Encoding UTF8
Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments } 'progress record is invalid'
if (@(Get-ChildItem $documents -Recurse -Filter '*.backup-*').Count) { throw 'Rejected apply made profile backups.' }
Remove-Item -LiteralPath $statePath
Remove-Item -LiteralPath $selectionPath
Invoke-PowerShellAliasesSetup @arguments | Out-Null
Invoke-PowerShellAliasesSetup @arguments -Check | Out-Null
$firstState = [IO.File]::ReadAllText($statePath)
$savedState = $firstState | ConvertFrom-Json
if ($savedState.PSObject.Properties['host'] -or $savedState.components.powershell_aliases.status -ne 'linked') { throw 'Host identity stored or progress unverified.' }
if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($legacyStatePath)) -ne $legacyStateBytes) { throw 'Legacy setup-state changed.' }
for ($index=0; $index -lt $profiles.Count; $index++) {
    $backup = @(Get-ChildItem -LiteralPath (Split-Path -Parent $profiles[$index]) -Filter '*.backup-*')
    if ($backup.Count -ne 1 -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($backup[0].FullName)) -ne [Convert]::ToBase64String($originals[$index])) { throw 'Original profile backup differs.' }
    $profileBytes = [IO.File]::ReadAllBytes($profiles[$index])
    for ($byte=0; $byte -lt $originals[$index].Length; $byte++) {
        if ($profileBytes[$byte] -ne $originals[$index][$byte]) { throw 'Profile encoding or original content changed.' }
    }
}
Invoke-PowerShellAliasesSetup @arguments | Out-Null
if ([IO.File]::ReadAllText($statePath) -ne $firstState -or @(Get-ChildItem $documents -Recurse -Filter '*.backup-*').Count -ne 2) { throw 'Repeated setup changed state/backups.' }
Write-Output 'PASS: read-only Plan/Check, no approval required, host-free progress, legacy state preservation, encoding/backups and idempotence.'
$asciiRepo = Join-Path $stage 'ascii-repo'
Copy-Item -LiteralPath $stagedRepo -Destination $asciiRepo -Recurse
$asciiDocuments = Join-Path $stage 'ascii-documents'
$asciiProfile = Join-Path $asciiDocuments 'PowerShell/Microsoft.PowerShell_profile.ps1'
New-Item -ItemType Directory -Path (Split-Path -Parent $asciiProfile) -Force | Out-Null
[IO.File]::WriteAllText($asciiProfile, '# ASCII without BOM', [Text.UTF8Encoding]::new($false))
$asciiPrefix = [Convert]::ToBase64String([IO.File]::ReadAllBytes($asciiProfile))
Invoke-PowerShellAliasesSetup -RepoPath $asciiRepo -DocumentsPath $asciiDocuments | Out-Null
$asciiBytes = [IO.File]::ReadAllBytes($asciiProfile)
if ([Convert]::ToBase64String($asciiBytes[0..18]) -ne $asciiPrefix) { throw 'BOM-less ASCII content was rewritten.' }
Write-Output 'PASS: ambiguous BOM-less encodings rejected before writes; BOM-less ASCII prefix preserved and missing profile created.'
$beforeOS = $env:OS
$beforePath = $env:Path
$beforeNeovimLog = $env:NVIM_LOG_FILE
$env:NVIM_LOG_FILE = Join-Path $stage 'nvim.log'
$priorAliases = @{}
foreach ($name in @('vi','vim')) { $priorAliases[$name] = Get-Alias -Name $name -ErrorAction SilentlyContinue }
try {
    foreach ($invalid in @('missing','malformed','unapproved','string-approval','other-host','wsl','schema','non-Windows')) {
        Save-AliasSelection
        switch ($invalid) {
            'missing' { Remove-Item -LiteralPath $selectionPath }
            'malformed' { '{' | Set-Content -LiteralPath $selectionPath }
            'unapproved' { $selection.approved=$false; Save-AliasSelection; $selection.approved=$true }
            'string-approval' { $selection.approved='true'; Save-AliasSelection; $selection.approved=$true }
            'other-host' { $selection.host='other-host'; Save-AliasSelection }
            'wsl' { $selection.environment='windows-wsl'; Save-AliasSelection; $selection.environment='windows-powershell' }
            'schema' { $selection.schemaVersion=2; Save-AliasSelection; $selection.schemaVersion=1 }
            'non-Windows' { $env:OS='Linux' }
        }
        Set-Alias vi Get-Date -Scope Global
        Set-Alias vim Get-Location -Scope Global
        . $runtime
        if ($invalid -eq 'non-Windows') {
            if ((Get-Alias vi).Definition -ne 'Get-Date' -or (Get-Alias vim).Definition -ne 'Get-Location') { throw 'Non-Windows changed aliases.' }
            Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments } 'native Windows'
        } else {
            $expectedNeovim = (Get-Command nvim -CommandType Application | Select-Object -First 1).Source
            if ((Get-Alias vi).Definition -ne $expectedNeovim -or (Get-Alias vim).Definition -ne $expectedNeovim) { throw "Alias depends on selection: $invalid" }
        }
        $env:OS=$beforeOS
    }
    Save-AliasSelection
    Set-Alias vi Get-Date -Scope Global
    Set-Alias vim Get-Location -Scope Global
    $env:Path=''
    . $runtime
    if ((Get-Alias vi).Definition -ne 'Get-Date' -or (Get-Alias vim).Definition -ne 'Get-Location') { throw 'Missing nvim changed aliases.' }
    Expect-AliasFailure { Invoke-PowerShellAliasesSetup @arguments } 'nvim.exe.*missing'
    $env:Path=$beforePath
    Set-Alias vi Get-Date -Scope Global -Option ReadOnly
    $warnings = @(& { . $runtime } 3>&1)
    if ((Get-Alias vi).Definition -ne 'Get-Date' -or -not ($warnings -match 'Could not set vi')) { throw 'ReadOnly alias was overwritten or not reported.' }
    Remove-Item Alias:\vi -Force
    # Test generated loaders, including a checkout path with spaces, apostrophe and Unicode.
    foreach ($profilePath in $profiles) { . $profilePath }
    . $runtime
    $neovim = (Get-Command nvim -CommandType Application | Select-Object -First 1).Source
    foreach ($name in @('vi','vim')) {
        if ((Get-Alias $name).Definition -ne $neovim) { throw "$name does not resolve to Neovim." }
        $fixture = Join-Path $stage 'file with spaces 한글.txt'
        $output = & $name --headless -u NONE -i NONE -n $fixture '+lua io.stdout:write(vim.api.nvim_buf_get_name(0))' '+qa!' 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $output -notmatch 'file with spaces') { throw "$name lost arguments or failed: $output" }
    }
    Write-Output 'PASS: selection-independent Windows aliases, non-Windows exclusion, missing executable, ReadOnly preservation, real vi/vim argument forwarding with -u NONE -i NONE.'
} finally {
    $env:OS=$beforeOS
    $env:Path=$beforePath
    $env:NVIM_LOG_FILE=$beforeNeovimLog
    foreach ($name in @('vi','vim')) {
        Remove-Item -LiteralPath ("Alias:\" + $name) -Force -ErrorAction SilentlyContinue
        if ($priorAliases[$name]) { Set-Alias $name $priorAliases[$name].Definition -Scope Global -Option $priorAliases[$name].Options }
    }
}
Write-Output "Only temporary profiles/state were written: $stage"

#Requires -Version 5.1
# Only process environment and mocked command discovery; never contacts Kubernetes.
$ErrorActionPreference = 'Stop'
$runtime = Join-Path (Split-Path -Parent $PSScriptRoot) 'powershell/aliases.ps1'
$savedEditor = $env:EDITOR
$savedKubeEditor = $env:KUBE_EDITOR
$savedOS = $env:OS
$savedAliases = @{}
foreach ($name in @('vi', 'vim')) {
    $savedAliases[$name] = Get-Alias $name -ErrorAction SilentlyContinue
}
try {
    $script:editorMissing = $false
    function Get-Command {
        param($Name, $CommandType, $ErrorAction)
        if ($Name -ne 'nvim') { throw 'Unexpected discovery' }
        if (-not $script:editorMissing) { [pscustomobject]@{ Source = 'C:\fixture path\nvim.exe' } }
    }
    $env:OS = 'Windows_NT'
    $env:EDITOR = $null
    $env:KUBE_EDITOR = $null
    . $runtime
    if ($env:EDITOR -ne 'nvim' -or $env:KUBE_EDITOR -ne 'nvim') { throw 'Defaults missing' }
    . $runtime
    if ($env:EDITOR -ne 'nvim' -or $env:KUBE_EDITOR -ne 'nvim') { throw 'Reload changed defaults' }
    if ((Get-Alias vi).Definition -ne 'C:\fixture path\nvim.exe') { throw 'Alias changed' }
    $env:EDITOR = 'custom --wait'
    $env:KUBE_EDITOR = 'another-editor'
    . $runtime
    if ($env:EDITOR -ne 'custom --wait' -or $env:KUBE_EDITOR -ne 'another-editor') { throw 'Explicit choice overwritten' }
    $env:KUBE_EDITOR = $null
    . $runtime
    if ($env:EDITOR -ne 'custom --wait' -or $env:KUBE_EDITOR -ne 'nvim') { throw 'Independent kube default failed' }
    $env:EDITOR = ' '
    $env:KUBE_EDITOR = 'another-editor'
    . $runtime
    if ($env:EDITOR -ne 'nvim' -or $env:KUBE_EDITOR -ne 'another-editor') { throw 'Independent editor default failed' }
    $env:EDITOR = $null
    $env:KUBE_EDITOR = $null
    $script:editorMissing = $true
    . $runtime
    if ($env:EDITOR -or $env:KUBE_EDITOR) { throw 'Defaults set without nvim' }
    $script:editorMissing = $false
    $env:OS = 'non-Windows'
    . $runtime
    if ($env:EDITOR -or $env:KUBE_EDITOR) { throw 'Non-Windows changed environment' }
    'PASS: editor defaults, independent explicit choices, reload, missing nvim, Windows isolation and existing alias.'
} finally {
    Remove-Item Function:\Get-Command -ErrorAction SilentlyContinue
    $env:EDITOR = $savedEditor
    $env:KUBE_EDITOR = $savedKubeEditor
    $env:OS = $savedOS
    foreach ($name in @('vi', 'vim')) {
        if ($savedAliases[$name]) { Set-Alias -Name $name -Value $savedAliases[$name].Definition -Scope Global }
        else { Remove-Item ('Alias:' + $name) -ErrorAction SilentlyContinue }
    }
}

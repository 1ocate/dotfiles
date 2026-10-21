# Windows PowerShell profile runtime; optional PSReadLine dependency.
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return }
if (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

. (Join-Path $PSScriptRoot 'ssh-completion.ps1')
. (Join-Path $PSScriptRoot 'ssh-fzf.ps1')

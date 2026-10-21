$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../powershell/ssh-completion.ps1')
# Do not read personal SSH config in tests.
$script:fixture = @('Host alpha beta', '  host ALPHA', 'Host *.example !blocked',
    'Host =gamma # comment', 'Host=gamma', 'Host = gamma', 'Host "quoted"', 'HostName ignored.example')
function Test-Path { param($LiteralPath, $PathType) return $true }
function Get-Content { param($LiteralPath, $ErrorAction) return $script:fixture }
function Assert-Completion($inputText, $expected) {
    $actual = @([System.Management.Automation.CommandCompletion]::CompleteInput(
        $inputText, $inputText.Length, $null).CompletionMatches |
        Where-Object ToolTip -eq 'SSH Host alias' | ForEach-Object CompletionText)
    if (($actual -join ',') -ne ($expected -join ',')) {
        throw "Unexpected SSH completion for '$inputText': $($actual -join ',')"
    }
}
Assert-Completion 'ssh ' @('ALPHA', 'beta', 'gamma')
Assert-Completion 'ssh b' @('beta')
Assert-Completion 'ssh user@g' @('user@gamma')
Assert-Completion 'ssh.exe b' @('beta')
Assert-Completion 'ssh -p ' @()
Assert-Completion 'ssh alpha ' @()
Assert-Completion 'ssh -' @()
$script:fixture = @()
Assert-Completion 'ssh ' @()
Remove-Item Function:\Get-Content, Function:\Test-Path
Write-Output 'SSH completion fixture checks passed.'

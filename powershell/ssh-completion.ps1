# Optional native SSH completion. Read aliases only; never execute SSH/config directives.
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return }
Register-ArgumentCompleter -Native -CommandName ssh, ssh.exe -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    # Only the first destination argument; leave options and remote commands alone.
    $preceding = @($commandAst.CommandElements | Select-Object -Skip 1 |
        Where-Object { $_.Extent.StartOffset -lt ($cursorPosition - $wordToComplete.Length) })
    if ($preceding.Count -gt 0 -or $wordToComplete.StartsWith('-')) { return }
    $configPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh/config'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return }
    $userPrefix = ''
    $hostPrefix = $wordToComplete
    if ($wordToComplete -match '^(.*@)([^@]*)$') {
        $userPrefix = $Matches[1]
        $hostPrefix = $Matches[2]
    }
    try { $lines = Get-Content -LiteralPath $configPath -ErrorAction Stop }
    catch { return }
    $aliases = foreach ($line in $lines) {
        if ($line -match '^\s*Host(?:\s*=\s*|\s+)(.+)$') {
            $hostList = ($Matches[1] -split '#', 2)[0]
            foreach ($alias in ($hostList -split '\s+')) {
                # Restrict to literal, shell-safe aliases; exclude patterns and negation.
                if ($alias -match '^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$' -and
                    $alias.StartsWith($hostPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                    $alias
                }
            }
        }
    }
    $aliases | Sort-Object -Unique | ForEach-Object {
        $candidate = $userPrefix + $_
        [System.Management.Automation.CompletionResult]::new($candidate, $candidate, 'ParameterValue', 'SSH Host alias')
    }
}

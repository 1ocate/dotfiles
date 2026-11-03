# Project directory picker shared by `t` and the psmux F popup.
# Kept free of the mux runtime so the popup can show fzf before loading it.
function global:Select-DotfilesProjectPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Repository)
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { throw 'fzf is required for project selection; use t <directory> instead.' }
    $rootsFile = Join-Path $Repository '.local/project-paths.txt'
    $roots = @((Get-Location).Path)
    if (Test-Path -LiteralPath $rootsFile -PathType Leaf) {
        $roots = @(Get-Content -LiteralPath $rootsFile -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.StartsWith('#') })
    }
    $directories = @($roots | ForEach-Object {
        if (Test-Path -LiteralPath $_ -PathType Container) {
            (Get-Item -LiteralPath $_).FullName
            Get-ChildItem -LiteralPath $_ -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
        }
    } | Sort-Object -Unique)
    $previousOutputEncoding = $OutputEncoding
    $previousConsoleEncoding = [Console]::OutputEncoding
    try {
        $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $directories | & fzf --prompt 'Project> '
    } finally {
        $OutputEncoding = $previousOutputEncoding
        [Console]::OutputEncoding = $previousConsoleEncoding
    }
}

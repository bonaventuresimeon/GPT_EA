$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

$python = Get-Command py -ErrorAction SilentlyContinue
if ($python) {
    & py -3 tools/run_release_checks.py
    exit $LASTEXITCODE
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & python tools/run_release_checks.py
    exit $LASTEXITCODE
}

Write-Error 'Python 3 was not found. Install Python 3 or run the checker from an environment where Python is available.'
exit 2

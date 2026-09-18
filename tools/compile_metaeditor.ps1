param(
    [string]$Source = "",
    [string]$MetaEditorPath = "",
    [string]$Mql5Root = "",
    [switch]$SyntaxOnly,
    [int]$MaxErrors = 20
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($Source)) {
    $Source = Join-Path $repoRoot "GPT_EA.mq5"
}
$Source = (Resolve-Path $Source).Path

function Find-MetaEditor {
    param([string]$Explicit)
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { $candidates += $Explicit }
    if (-not [string]::IsNullOrWhiteSpace($env:METAEDITOR_PATH)) { $candidates += $env:METAEDITOR_PATH }

    $candidates += @(
        "C:\Program Files\MetaTrader 5\metaeditor64.exe",
        "C:\Program Files (x86)\MetaTrader 5\metaeditor.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    foreach ($root in @("C:\Program Files", "C:\Program Files (x86)")) {
        if (Test-Path -LiteralPath $root) {
            $found = Get-ChildItem -LiteralPath $root -Filter "metaeditor64.exe" -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    throw "MetaEditor64.exe was not found. Pass -MetaEditorPath or set METAEDITOR_PATH."
}

function Find-Mql5Root {
    param([string]$Explicit)
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { $candidates += $Explicit }
    if (-not [string]::IsNullOrWhiteSpace($env:MQL5_ROOT)) { $candidates += $env:MQL5_ROOT }

    $terminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path -LiteralPath $terminalRoot) {
        $tradeHeader = Get-ChildItem -LiteralPath $terminalRoot -Filter "Trade.mqh" -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\MQL5\\Include\\Trade\\Trade\.mqh$" } |
            Select-Object -First 1
        if ($tradeHeader) {
            $includeDir = Split-Path (Split-Path $tradeHeader.FullName -Parent) -Parent
            $candidates += (Split-Path $includeDir -Parent)
        }
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $root = $candidate
        if ((Split-Path $root -Leaf) -ieq "Include") { $root = Split-Path $root -Parent }
        $trade = Join-Path $root "Include\Trade\Trade.mqh"
        if (Test-Path -LiteralPath $trade) { return (Resolve-Path -LiteralPath $root).Path }
    }
    throw "MQL5 root containing Include\Trade\Trade.mqh was not found. Pass -Mql5Root or set MQL5_ROOT."
}

$metaEditor = Find-MetaEditor $MetaEditorPath
$mql5 = Find-Mql5Root $Mql5Root

$sourceDir = Split-Path $Source -Parent
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($Source)
$logPath = Join-Path $sourceDir ($baseName + ".log")
$firstErrorsPath = Join-Path $repoRoot "metaeditor-first-errors.txt"

Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $firstErrorsPath -Force -ErrorAction SilentlyContinue

$args = @(
    "/compile:`"$Source`"",
    "/include:`"$mql5`"",
    "/log"
)
if ($SyntaxOnly) { $args += "/s" }

Write-Host "MetaEditor: $metaEditor"
Write-Host "Source:     $Source"
Write-Host "MQL5 root:  $mql5"
Write-Host "Mode:       $(if ($SyntaxOnly) { 'syntax-only' } else { 'compile' })"
Write-Host ""

$process = Start-Process -FilePath $metaEditor -ArgumentList $args -Wait -PassThru

if (-not (Test-Path -LiteralPath $logPath)) {
    throw "MetaEditor did not create the expected log: $logPath"
}

$log = Get-Content -LiteralPath $logPath -Encoding Unicode -ErrorAction SilentlyContinue
if (-not $log -or $log.Count -eq 0) {
    $log = Get-Content -LiteralPath $logPath -ErrorAction Stop
}

$summary = $log | Where-Object { $_ -match "(?i)\b\d+\s+errors?\b.*\b\d+\s+warnings?\b" } | Select-Object -Last 1
$errors = $log | Where-Object {
    $_ -match "(?i)\berror\b" -and $_ -notmatch "(?i)\b0\s+errors?\b"
} | Select-Object -First $MaxErrors

$warnings = $log | Where-Object {
    $_ -match "(?i)\bwarning\b" -and $_ -notmatch "(?i)\b0\s+warnings?\b"
} | Select-Object -First 10

$report = @()
$report += "GPT_EA MetaEditor compile report"
$report += "Source: $Source"
$report += "MetaEditor: $metaEditor"
$report += "MQL5 root: $mql5"
$report += "Process exit code: $($process.ExitCode)"
$report += "Summary: $summary"
$report += ""
$report += "FIRST ERRORS:"
if ($errors) { $report += $errors } else { $report += "(none)" }
$report += ""
$report += "FIRST WARNINGS:"
if ($warnings) { $report += $warnings } else { $report += "(none)" }

$report | Set-Content -LiteralPath $firstErrorsPath -Encoding UTF8
$report | ForEach-Object { Write-Host $_ }

if ($errors -or ($summary -and $summary -notmatch "(?i)\b0\s+errors?\b")) {
    Write-Error "MetaEditor compile failed. See $logPath and $firstErrorsPath"
    exit 1
}

if (-not $summary) {
    Write-Warning "MetaEditor log did not contain a standard error/warning summary. Review $logPath manually."
}

Write-Host ""
Write-Host "MetaEditor compile completed without reported errors."
exit 0

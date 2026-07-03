<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

<#
.SYNOPSIS
    Verifies the mggraph-intune-samples repository: runs PSScriptAnalyzer linting and
    a copyright-header check across all PowerShell sample scripts.

.DESCRIPTION
    Intended as the one-command verification loop for contributors and CI. Runs
    PSScriptAnalyzer (if available) over every *.ps1 file and confirms each carries
    the required Microsoft copyright header. Exits with a non-zero code if any
    error-level analyzer finding or missing header is detected.

.PARAMETER Severity
    Minimum PSScriptAnalyzer severity to treat as a failure. Defaults to 'Error'.

.EXAMPLE
    ./scripts/verify.ps1

.EXAMPLE
    ./scripts/verify.ps1 -Severity Warning
#>

[CmdletBinding()]
param(
    [ValidateSet('Error', 'Warning', 'Information')]
    [string]$Severity = 'Error'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = 0

Write-Host "Verifying repository at $repoRoot" -ForegroundColor Cyan

$scripts = Get-ChildItem -Path $repoRoot -Recurse -Filter *.ps1 -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

# 1. Copyright-header check ------------------------------------------------
Write-Host "`n[1/2] Checking copyright headers..." -ForegroundColor Cyan
$missingHeader = @()
foreach ($script in $scripts) {
    $head = Get-Content -Path $script.FullName -TotalCount 5 -ErrorAction SilentlyContinue
    if (($head -join "`n") -notmatch 'Copyright \(c\) Microsoft Corporation') {
        $missingHeader += $script.FullName
    }
}
if ($missingHeader.Count -gt 0) {
    $failures += $missingHeader.Count
    Write-Host "Missing copyright header in $($missingHeader.Count) file(s):" -ForegroundColor Red
    $missingHeader | ForEach-Object { Write-Host "  - $($_.Replace($repoRoot, '.'))" -ForegroundColor Red }
}
else {
    Write-Host "All $($scripts.Count) script(s) have the copyright header." -ForegroundColor Green
}

# 2. PSScriptAnalyzer ------------------------------------------------------
Write-Host "`n[2/2] Running PSScriptAnalyzer..." -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "PSScriptAnalyzer is not installed. Install it with:" -ForegroundColor Yellow
    Write-Host "  Install-Module PSScriptAnalyzer -Scope CurrentUser" -ForegroundColor Yellow
}
else {
    Import-Module PSScriptAnalyzer
    $findings = Invoke-ScriptAnalyzer -Path $repoRoot -Recurse -Severity $Severity
    if ($findings) {
        $failures += $findings.Count
        Write-Host "PSScriptAnalyzer reported $($findings.Count) $Severity finding(s):" -ForegroundColor Red
        $findings | Format-Table RuleName, Severity, ScriptName, Line -AutoSize | Out-String | Write-Host
    }
    else {
        Write-Host "No $Severity findings from PSScriptAnalyzer." -ForegroundColor Green
    }
}

# Result -------------------------------------------------------------------
if ($failures -gt 0) {
    Write-Host "`nVerification FAILED with $failures issue(s)." -ForegroundColor Red
    exit 1
}
Write-Host "`nVerification passed." -ForegroundColor Green
exit 0

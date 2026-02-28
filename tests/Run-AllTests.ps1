#Requires -Version 5.1
<#
.SYNOPSIS
    Runs all tests in the correct order.

.DESCRIPTION
    1. Unit tests     -- fast, no system changes, no Syncthing required
    2. Integration    -- checks that setup-windows.ps1 ran correctly (needs Admin)
    3. Holistic       -- end-to-end smoke test (needs Syncthing running + phone paired)

.PARAMETER Unit
    Run unit tests only (Pester required).

.PARAMETER Integration
    Run integration tests only.

.PARAMETER Holistic
    Run holistic smoke test only.

.PARAMETER All
    Run all tests in sequence (default).

.EXAMPLE
    .\tests\Run-AllTests.ps1
    .\tests\Run-AllTests.ps1 -Unit
    .\tests\Run-AllTests.ps1 -Integration
    .\tests\Run-AllTests.ps1 -Holistic
#>
param(
    [switch]$Unit,
    [switch]$Integration,
    [switch]$Holistic,
    [switch]$All
)

$RunAll = $All -or (-not $Unit -and -not $Integration -and -not $Holistic)
$ScriptDir = $PSScriptRoot
$overallFail = $false

function Write-Banner { param([string]$T)
    Write-Host ""
    Write-Host "  =" -ForegroundColor DarkCyan
    Write-Host "  $T" -ForegroundColor Cyan
    Write-Host "  =" -ForegroundColor DarkCyan
}

# - Unit tests (Pester) -
if ($Unit -or $RunAll) {
    Write-Banner "1/3  Unit Tests (Pester)"

    $pesterAvailable = $null -ne (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge "5.0" })
    if (-not $pesterAvailable) {
        Write-Host "  Pester v5 not installed. Installing..." -ForegroundColor Yellow
        try {
            Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.0 -ErrorAction Stop
        } catch {
            Write-Host "  Could not install Pester: $_" -ForegroundColor Red
            Write-Host "  Run manually: Install-Module Pester -Force -Scope CurrentUser" -ForegroundColor Yellow
            $overallFail = $true
        }
    }

    if ($null -ne (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge "5.0" })) {
        Import-Module Pester -MinimumVersion 5.0
        $config = New-PesterConfiguration
        $config.Run.Path = Join-Path $ScriptDir "setup-windows.Tests.ps1"
        $config.Output.Verbosity = "Detailed"
        $result = Invoke-Pester -Configuration $config -PassThru
        if ($result.FailedCount -gt 0) { $overallFail = $true }
    }
}

# - Integration tests -
if ($Integration -or $RunAll) {
    Write-Banner "2/3  Integration Tests"
    & (Join-Path $ScriptDir "Test-Integration.ps1")
    if ($LASTEXITCODE -ne 0) { $overallFail = $true }
}

# - Holistic smoke test -
if ($Holistic -or $RunAll) {
    Write-Banner "3/3  Holistic Smoke Test"
    & (Join-Path $ScriptDir "Test-Holistic.ps1")
    if ($LASTEXITCODE -ne 0) { $overallFail = $true }
}

Write-Host ""
if ($overallFail) {
    Write-Host "  OVERALL: Some tests failed. Address the issues above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "  OVERALL: All tests passed." -ForegroundColor Green
    exit 0
}

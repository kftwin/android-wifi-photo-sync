#Requires -Version 5.1
<#
.SYNOPSIS
    Integration tests -- verify the Windows machine is correctly set up.

.DESCRIPTION
    Checks that all components installed by setup-windows.ps1 are present and
    correctly configured. Run this AFTER setup-windows.ps1 has completed.

    Does NOT require Syncthing to be fully synced -- just that it is installed
    and configured correctly.

    Must be run as Administrator to check firewall rules.

.EXAMPLE
    .\tests\Test-Integration.ps1
#>

$ErrorActionPreference = "Continue"
$InstallDir  = Join-Path $env:LOCALAPPDATA "Syncthing"
$ExePath     = Join-Path $InstallDir "syncthing.exe"
$ConfigPath  = Join-Path $InstallDir "config.xml"
$BackupRoot  = "H:\android-backup"
$TaskName    = "Syncthing"

$pass = 0; $fail = 0; $warn = 0

function Pass  { param([string]$T) Write-Host "  [PASS] $T" -ForegroundColor Green;  $script:pass++ }
function Fail  { param([string]$T) Write-Host "  [FAIL] $T" -ForegroundColor Red;    $script:fail++ }
function Warn  { param([string]$T) Write-Host "  [WARN] $T" -ForegroundColor Yellow; $script:warn++ }
function Check { param([string]$Label, [scriptblock]$Test, [string]$FailMsg = "")
    try {
        if (& $Test) { Pass $Label } else { Fail "$Label -- $FailMsg" }
    } catch {
        Fail "$Label -- Exception: $_"
    }
}

Write-Host ""
Write-Host "  +=+" -ForegroundColor DarkCyan
Write-Host "  |   Android Backup -- Integration Tests        |" -ForegroundColor DarkCyan
Write-Host "  +=+" -ForegroundColor DarkCyan

# - 1. Syncthing installation -
Write-Host "`n  [1] Syncthing Installation" -ForegroundColor Cyan

Check "syncthing.exe exists at $ExePath" {
    Test-Path $ExePath
} "Run setup-windows.ps1 first"

Check "syncthing.exe is a valid executable" {
    (Get-Item $ExePath -ErrorAction SilentlyContinue).Length -gt 1MB
} "File may be corrupt -- re-run setup-windows.ps1"

Check "config.xml exists" {
    Test-Path $ConfigPath
} "Syncthing has not been initialized -- re-run setup-windows.ps1"

# - 2. Backup folders -
Write-Host "`n  [2] Backup Folders ($BackupRoot)" -ForegroundColor Cyan

foreach ($folder in @("Camera","Screenshots","Downloads","Documents","Signal","WhatsApp")) {
    $path = Join-Path $BackupRoot $folder
    Check "Folder exists: $folder" { Test-Path $path } "Run setup-windows.ps1 or create $path manually"
}

# - 3. Firewall rules -
Write-Host "`n  [3] Windows Firewall Rules" -ForegroundColor Cyan

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    foreach ($ruleName in @("Syncthing-TCP","Syncthing-UDP","Syncthing-Discovery")) {
        Check "Firewall rule exists: $ruleName" {
            $null -ne (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)
        } "Re-run setup-windows.ps1 as Administrator"
    }
} else {
    Warn "Skipping firewall checks -- not running as Administrator"
}

# - 4. Config.xml contents -
Write-Host "`n  [4] Syncthing Configuration" -ForegroundColor Cyan

if (Test-Path $ConfigPath) {
    [xml]$cfg = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue

    Check "GUI bound to 127.0.0.1:8384" {
        $cfg.configuration.gui.address -eq "127.0.0.1:8384"
    } "Re-run setup-windows.ps1 to patch config"

    Check "Global discovery disabled" {
        $cfg.configuration.options.globalAnnounceEnabled -eq "false"
    } "Re-run setup-windows.ps1 to patch config"

    Check "Relays disabled" {
        $cfg.configuration.options.relaysEnabled -eq "false"
    } "Re-run setup-windows.ps1 to patch config"

    Check "Local discovery enabled" {
        $cfg.configuration.options.localAnnounceEnabled -eq "true"
    } "Re-run setup-windows.ps1 to patch config"

    Check "API key is present" {
        -not [string]::IsNullOrWhiteSpace($cfg.configuration.gui.apikey)
    } "config.xml may be corrupt"
} else {
    Fail "config.xml missing -- cannot check configuration"
}

# - 5. Task Scheduler -
Write-Host "`n  [5] Task Scheduler" -ForegroundColor Cyan

Check "Task '$TaskName' exists in Task Scheduler" {
    $null -ne (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
} "Re-run setup-windows.ps1"

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Check "Task action executes syncthing.exe" {
        $task.Actions[0].Execute -like "*syncthing.exe"
    } "Task action may be misconfigured -- re-run setup-windows.ps1"

    Check "Task trigger is AtLogon" {
        $task.Triggers[0].CimClass.CimClassName -like "*LogonTrigger*"
    } "Task trigger may be wrong -- re-run setup-windows.ps1"

    Check "Task is enabled" {
        $task.Settings.Enabled
    } "Enable the task in Task Scheduler"
}

# - 6. Process running -
Write-Host "`n  [6] Syncthing Process" -ForegroundColor Cyan

$proc = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue
Check "Syncthing process is running" {
    $null -ne $proc
} "Start Syncthing: Start-ScheduledTask -TaskName Syncthing"

if ($proc) {
    # Give it a moment to start API if it just launched
    $apiReady = $false
    if (Test-Path $ConfigPath) {
        [xml]$cfg = Get-Content $ConfigPath -Raw
        $apiKey = $cfg.configuration.gui.apikey
        try {
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:8384/rest/system/ping" `
                -Headers @{"X-API-Key"=$apiKey} -TimeoutSec 5 -UseBasicParsing
            $apiReady = ($response.ping -eq "pong")
        } catch {}
    }
    Check "Syncthing REST API responds at 127.0.0.1:8384" { $apiReady } `
        "API not ready yet -- wait a few seconds and retry"
}

# - Summary -
Write-Host ""
Write-Host ("  Results: {0} passed, {1} failed, {2} warnings" -f $pass, $fail, $warn) -ForegroundColor $(
    if ($fail -gt 0) { "Red" } elseif ($warn -gt 0) { "Yellow" } else { "Green" }
)

if ($fail -gt 0) {
    Write-Host "  Re-run setup-windows.ps1 to fix failed checks." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "  All integration checks passed! Follow ANDROID-SETUP.md to pair your phone." -ForegroundColor Green
    exit 0
}

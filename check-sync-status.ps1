#Requires -Version 5.1
<#
.SYNOPSIS
    Check the current status of the Syncthing backup sync.

.DESCRIPTION
    Queries the Syncthing REST API to report:
    - Whether Syncthing is running
    - Uptime and version
    - Per-folder sync completion for all six backup folders
    - Any errors
    Offers to start Syncthing if it is not running.

.EXAMPLE
    .\check-sync-status.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

$ConfigDir  = Join-Path $env:LOCALAPPDATA "Syncthing"
$ConfigPath = Join-Path $ConfigDir "config.xml"
$ExePath    = Join-Path $ConfigDir "syncthing.exe"
$ApiBase    = "http://127.0.0.1:8384"

$BackupRoot    = "H:\android-backup"
$FolderLabels  = @("Camera","Screenshots","Downloads","Documents","Signal","WhatsApp")

# - Helpers -
function Write-Header { param([string]$T) Write-Host "`n  $T" -ForegroundColor Cyan }
function Write-Row    { param([string]$Label,[string]$Value,[string]$Color="White")
    Write-Host ("  {0,-18} {1}" -f $Label, $Value) -ForegroundColor $Color }

# - Get API key from config.xml -
function Get-ApiKey {
    if (-not (Test-Path $ConfigPath)) { return $null }
    [xml]$cfg = Get-Content $ConfigPath -Raw -ErrorAction SilentlyContinue
    return $cfg.configuration.gui.apikey
}

# - Task 3.1: Check process -
Write-Host ""
Write-Host "  +=======================================+" -ForegroundColor DarkCyan
Write-Host "  |     Syncthing Backup Status           |" -ForegroundColor DarkCyan
Write-Host "  +=======================================+" -ForegroundColor DarkCyan

Write-Header "Process"
$proc = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Row "Syncthing" "[X] NOT RUNNING" "Red"

    # Task 3.4: Offer to start it
    Write-Host ""
    $answer = Read-Host "  Syncthing is not running. Start it now? [Y/n]"
    if ($answer -ne "n" -and $answer -ne "N") {
        if (Test-Path $ExePath) {
            Start-Process -FilePath $ExePath -ArgumentList "--no-browser --no-restart" -WindowStyle Hidden
            Write-Host "  Started Syncthing. Waiting for API..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            $proc = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Row "Syncthing" "[OK] Started (PID $($proc.Id))" "Green"
            } else {
                Write-Row "Syncthing" "[X] Failed to start -- check $ExePath" "Red"
                exit 1
            }
        } else {
            Write-Host "  syncthing.exe not found at $ExePath" -ForegroundColor Red
            Write-Host "  Run setup-windows.ps1 first." -ForegroundColor Yellow
            exit 1
        }
    } else {
        exit 0
    }
} else {
    Write-Row "Syncthing" "[OK] Running (PID $($proc.Id))" "Green"
}

# - Task 3.2: Query REST API -
$apiKey = Get-ApiKey
if (-not $apiKey) {
    Write-Row "API Key" "[X] Could not read from config.xml" "Red"
    exit 1
}

$headers = @{ "X-API-Key" = $apiKey }

try {
    $status = Invoke-RestMethod -Uri "$ApiBase/rest/system/status" -Headers $headers `
                                -TimeoutSec 5 -UseBasicParsing
} catch {
    Write-Row "API" "[X] Not responding at $ApiBase -- Syncthing may still be starting" "Red"
    Write-Host "  Try again in a few seconds." -ForegroundColor Yellow
    exit 1
}

Write-Header "System"
Write-Row "Version"  $status.version
$uptime = [TimeSpan]::FromSeconds($status.uptime)
Write-Row "Uptime"   ("{0}d {1}h {2}m" -f [int]$uptime.TotalDays, $uptime.Hours, $uptime.Minutes)
Write-Row "Device ID" ($status.myID.Substring(0,10) + "...")

# - Task 3.3: Folder completion -
Write-Header "Folder Sync Status"

try {
    $folders = Invoke-RestMethod -Uri "$ApiBase/rest/config/folders" -Headers $headers `
                                 -TimeoutSec 5 -UseBasicParsing
} catch {
    Write-Row "Folders" "[X] Could not retrieve folder list from API" "Red"
    $folders = @()
}

if ($folders.Count -eq 0) {
    Write-Host "  No folders paired yet. Follow ANDROID-SETUP.md to pair your phone." -ForegroundColor Yellow
} else {
    Write-Host ("  {0,-20} {1,-12} {2,-10} {3}" -f "Folder","Completion","Files","Local Path") -ForegroundColor DarkGray

    foreach ($folder in $folders) {
        try {
            $comp = Invoke-RestMethod -Uri "$ApiBase/rest/db/completion?folder=$($folder.id)" `
                                      -Headers $headers -TimeoutSec 5 -UseBasicParsing
            $pct   = [int]$comp.completion
            $color = if ($pct -eq 100) { "Green" } elseif ($pct -gt 50) { "Yellow" } else { "Red" }
            $localPath = $folder.path
            $fileCount = if (Test-Path $localPath) {
                (Get-ChildItem -Recurse -File $localPath -ErrorAction SilentlyContinue).Count
            } else { "?" }
            Write-Host ("  {0,-20} {1,-12} {2,-10} {3}" -f `
                $folder.label, "$pct%", $fileCount, $localPath) -ForegroundColor $color
        } catch {
            Write-Host ("  {0,-20} [X] error" -f $folder.label) -ForegroundColor Red
        }
    }
}

# - Errors -
Write-Header "Errors"
try {
    $errors = Invoke-RestMethod -Uri "$ApiBase/rest/system/error" -Headers $headers `
                                -TimeoutSec 5 -UseBasicParsing
    if ($errors.errors -and $errors.errors.Count -gt 0) {
        foreach ($e in $errors.errors) {
            Write-Row $e.time $e.message "Red"
        }
    } else {
        Write-Row "Errors" "None [OK]" "Green"
    }
} catch {
    Write-Row "Errors" "Could not retrieve error list" "Yellow"
}

# - Backup folder sizes -
Write-Header "Backup Folder Sizes ($BackupRoot)"
Write-Host ("  {0,-16} {1,-10} {2}" -f "Folder","Files","Size") -ForegroundColor DarkGray
foreach ($label in $FolderLabels) {
    $path = Join-Path $BackupRoot $label
    if (Test-Path $path) {
        $items = Get-ChildItem -Recurse -File $path -ErrorAction SilentlyContinue
        $count = $items.Count
        $bytes = ($items | Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
        $size  = if ($bytes -gt 1GB)  { "{0:N1} GB" -f ($bytes/1GB) }
                 elseif ($bytes -gt 1MB) { "{0:N1} MB" -f ($bytes/1MB) }
                 else { "{0:N0} KB" -f ($bytes/1KB) }
        $color = if ($count -gt 0) { "White" } else { "DarkGray" }
        Write-Host ("  {0,-16} {1,-10} {2}" -f $label, $count, $size) -ForegroundColor $color
    } else {
        Write-Host ("  {0,-16} folder missing" -f $label) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  Open http://127.0.0.1:8384 for the full Syncthing web UI." -ForegroundColor DarkGray
Write-Host ""

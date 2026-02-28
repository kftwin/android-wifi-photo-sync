#Requires -Version 5.1
<#
.SYNOPSIS
    Holistic / end-to-end smoke test -- run after pairing your phone.

.DESCRIPTION
    Verifies the full backup pipeline is working end-to-end:
    - Syncthing running and API healthy
    - All six folders paired and syncing
    - At least one file present in Camera backup (proves first sync completed)
    - No Syncthing errors
    - Versioning configured on all receive folders
    - Backup folder sizes reported

.EXAMPLE
    .\tests\Test-Holistic.ps1
#>

$ErrorActionPreference = "Continue"
$ConfigPath = Join-Path $env:LOCALAPPDATA "Syncthing\config.xml"
$BackupRoot = "H:\android-backup"
$ApiBase    = "http://127.0.0.1:8384"

$ExpectedFolders = @{
    "Camera"      = "H:\android-backup\Camera"
    "Screenshots" = "H:\android-backup\Screenshots"
    "Downloads"   = "H:\android-backup\Downloads"
    "Documents"   = "H:\android-backup\Documents"
    "Signal"      = "H:\android-backup\Signal"
    "WhatsApp"    = "H:\android-backup\WhatsApp"
}

$pass = 0; $fail = 0; $warn = 0

function Pass { param([string]$T) Write-Host "  [PASS] $T" -ForegroundColor Green;  $script:pass++ }
function Fail { param([string]$T) Write-Host "  [FAIL] $T" -ForegroundColor Red;    $script:fail++ }
function Warn { param([string]$T) Write-Host "  [WARN] $T" -ForegroundColor Yellow; $script:warn++ }
function Info { param([string]$T) Write-Host "  [INFO] $T" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  +=+" -ForegroundColor DarkCyan
Write-Host "  |   Android Backup -- Holistic Smoke Test      |" -ForegroundColor DarkCyan
Write-Host "  +=+" -ForegroundColor DarkCyan

# - Get API key -
$apiKey = $null
if (Test-Path $ConfigPath) {
    [xml]$cfg = Get-Content $ConfigPath -Raw
    $apiKey = $cfg.configuration.gui.apikey
}
$headers = @{ "X-API-Key" = $apiKey }

# - 1. API health -
Write-Host "`n  [1] API Health" -ForegroundColor Cyan

$systemStatus = $null
try {
    $ping = Invoke-RestMethod -Uri "$ApiBase/rest/system/ping" -Headers $headers -TimeoutSec 5
    if ($ping.ping -eq "pong") {
        Pass "Syncthing REST API is responding"
        $systemStatus = Invoke-RestMethod -Uri "$ApiBase/rest/system/status" -Headers $headers -TimeoutSec 5
        $uptime = [TimeSpan]::FromSeconds($systemStatus.uptime)
        Info "Version: $($systemStatus.version) | Uptime: $([int]$uptime.TotalHours)h $($uptime.Minutes)m"
    }
} catch {
    Fail "Syncthing API not responding at $ApiBase -- is Syncthing running?"
    Write-Host "  Start it: Start-ScheduledTask -TaskName Syncthing" -ForegroundColor Yellow
    exit 1
}

# - 2. Connected devices -
Write-Host "`n  [2] Connected Devices" -ForegroundColor Cyan

$connections = $null
try {
    $connections = Invoke-RestMethod -Uri "$ApiBase/rest/system/connections" -Headers $headers -TimeoutSec 5
    $connected = ($connections.connections.PSObject.Properties | Where-Object { $_.Value.connected }).Count
    if ($connected -gt 0) {
        Pass "$connected device(s) currently connected"
    } else {
        Warn "No devices currently connected -- phone may be away or on mobile data"
        Info "This is expected when the phone is not on home WiFi"
    }
} catch {
    Warn "Could not retrieve connection status"
}

# - 3. Folder sync status -
Write-Host "`n  [3] Folder Sync Completion" -ForegroundColor Cyan

$configuredFolders = @()
try {
    $configuredFolders = Invoke-RestMethod -Uri "$ApiBase/rest/config/folders" -Headers $headers -TimeoutSec 5
} catch {
    Fail "Could not retrieve folder list from Syncthing"
}

if ($configuredFolders.Count -eq 0) {
    Warn "No folders configured in Syncthing yet -- complete ANDROID-SETUP.md pairing steps"
} else {
    $pairedLabels = $configuredFolders | ForEach-Object { $_.label }
    foreach ($expectedLabel in $ExpectedFolders.Keys) {
        if ($pairedLabels -contains $expectedLabel) {
            # Check completion percentage
            try {
                $deviceId = if ($connections) {
                    ($connections.connections.PSObject.Properties | Where-Object { $_.Value.connected } | Select-Object -First 1).Name
                } else { "" }

                $comp = if ($deviceId) {
                    Invoke-RestMethod -Uri "$ApiBase/rest/db/completion?folder=$($expectedLabel.ToLower())&device=$deviceId" `
                        -Headers $headers -TimeoutSec 5
                } else {
                    Invoke-RestMethod -Uri "$ApiBase/rest/db/completion?folder=$($expectedLabel.ToLower())" `
                        -Headers $headers -TimeoutSec 5
                }

                $pct = [int]$comp.completion
                if ($pct -eq 100) {
                    Pass "Folder '$expectedLabel': 100% synced"
                } elseif ($pct -gt 0) {
                    Warn "Folder '$expectedLabel': $pct% synced (in progress)"
                } else {
                    Warn "Folder '$expectedLabel': 0% -- not yet synced (phone may be away)"
                }
            } catch {
                Info "Folder '$expectedLabel': paired but completion unavailable"
            }
        } else {
            Warn "Folder '$expectedLabel' is not yet paired -- complete ANDROID-SETUP.md"
        }
    }
}

# - 4. Backup folder content check -
Write-Host "`n  [4] Backup Folder Contents" -ForegroundColor Cyan

Write-Host ("  {0,-16} {1,-10} {2}" -f "Folder","Files","Size") -ForegroundColor DarkGray

foreach ($label in $ExpectedFolders.Keys) {
    $path = $ExpectedFolders[$label]
    if (Test-Path $path) {
        $items = Get-ChildItem -Recurse -File $path -ErrorAction SilentlyContinue |
                 Where-Object { $_.DirectoryName -notlike "*.stversions*" }
        $count = $items.Count
        $bytes = ($items | Measure-Object Length -Sum).Sum
        $size  = if ($bytes -gt 1GB)  { "{0:N1} GB" -f ($bytes/1GB) }
                 elseif ($bytes -gt 1MB) { "{0:N1} MB" -f ($bytes/1MB) }
                 elseif ($bytes)        { "{0:N0} KB" -f ($bytes/1KB) }
                 else { "0 KB" }
        $color = if ($count -gt 0) { "White" } else { "DarkGray" }
        Write-Host ("  {0,-16} {1,-10} {2}" -f $label, $count, $size) -ForegroundColor $color
    } else {
        Write-Host ("  {0,-16} MISSING" -f $label) -ForegroundColor Red
    }
}

# Key assertion: Camera should have at least one file after a successful first sync
$cameraPath = $ExpectedFolders["Camera"]
if (Test-Path $cameraPath) {
    $cameraFiles = (Get-ChildItem -Recurse -File $cameraPath -ErrorAction SilentlyContinue).Count
    if ($cameraFiles -gt 0) {
        Pass "Camera backup has $cameraFiles file(s) -- first sync confirmed"
    } else {
        Warn "Camera folder is empty -- phone may not have synced yet"
        Info "After pairing, wait for the phone to connect to home WiFi"
    }
} else {
    Fail "Camera backup folder does not exist -- run setup-windows.ps1"
}

# - 5. Versioning check -
Write-Host "`n  [5] Staggered Versioning" -ForegroundColor Cyan

if (Test-Path $ConfigPath) {
    [xml]$cfg = Get-Content $ConfigPath -Raw
    $folders = $cfg.configuration.folder
    if ($folders) {
        foreach ($folder in @($folders)) {
            if ($folder.type -in @("receiveonly","receive")) {
                $hasVersioning = ($folder.versioning -and $folder.versioning.type -eq "staggered")
                if ($hasVersioning) {
                    Pass "Folder '$($folder.id)' has staggered versioning"
                } else {
                    Warn "Folder '$($folder.id)' is missing staggered versioning"
                    Info "Re-run: . .\setup-windows.ps1; Set-StaggeredVersioning"
                }
            }
        }
    } else {
        Warn "No folders in config.xml yet -- pair your phone first, then re-run this test"
    }
}

# - 6. Error check -
Write-Host "`n  [6] Syncthing Errors" -ForegroundColor Cyan

try {
    $errs = Invoke-RestMethod -Uri "$ApiBase/rest/system/error" -Headers $headers -TimeoutSec 5
    if ($errs.errors -and $errs.errors.Count -gt 0) {
        foreach ($e in $errs.errors) {
            Fail "Syncthing error: $($e.message)"
        }
    } else {
        Pass "No Syncthing errors"
    }
} catch {
    Warn "Could not retrieve error list"
}

# - Summary -
Write-Host ""
$color = if ($fail -gt 0) { "Red" } elseif ($warn -gt 0) { "Yellow" } else { "Green" }
Write-Host ("  Results: {0} passed, {1} failed, {2} warnings" -f $pass, $fail, $warn) -ForegroundColor $color

if ($fail -gt 0) {
    Write-Host "  Address the failures above. Check ANDROID-SETUP.md for guidance." -ForegroundColor Yellow
    exit 1
} elseif ($warn -gt 0) {
    Write-Host "  Setup looks good -- some items need attention (see warnings above)." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "  Everything is working correctly. Backups are flowing." -ForegroundColor Green
    exit 0
}

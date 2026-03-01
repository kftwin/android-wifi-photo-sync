#Requires -Version 5.1
<#
.SYNOPSIS
    One-time Windows setup for Android phone backup via Syncthing.

.DESCRIPTION
    - Downloads and installs Syncthing (LAN-only, no cloud)
    - Creates <BackupRoot>\{Camera,Screenshots,Downloads,Documents,Signal,WhatsApp}
    - Opens Windows Firewall ports for Syncthing
    - Registers a Task Scheduler task so Syncthing starts on login automatically
    - Patches Syncthing config for local-only discovery (no global relay/discovery)

.PARAMETER BackupRoot
    Root folder for all backups. Default: C:\android-backup
    Subfolders Camera, Screenshots, Downloads, Documents, Signal, WhatsApp are created here.
    Change this to any drive or folder you prefer, e.g. "D:\Backups\Phone" or "E:\android-backup".

.EXAMPLE
    .\setup-windows.ps1
    .\setup-windows.ps1 -BackupRoot "D:\MyBackup"

.NOTES
    Must be run as Administrator.
    Run once. Re-running is safe (idempotent).
#>

[CmdletBinding()]
param(
    [string]$BackupRoot = "C:\android-backup"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Paths
$InstallDir  = Join-Path $env:LOCALAPPDATA "Syncthing"
$ExePath     = Join-Path $InstallDir "syncthing.exe"
$ConfigDir   = Join-Path $env:LOCALAPPDATA "Syncthing"
$ConfigPath  = Join-Path $ConfigDir "config.xml"
$TaskName    = "Syncthing"

$BackupFolders = @("Camera","Screenshots","Downloads","Documents","Signal","WhatsApp")

# Helpers
function Write-Step  { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "  [OK]   $Msg" -ForegroundColor Green }
function Write-Skip  { param([string]$Msg) Write-Host "  [--]   $Msg" -ForegroundColor DarkGray }
function Write-Warn  { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Msg) Write-Host "  [ERR]  $Msg" -ForegroundColor Red }

# Task 1.1: Admin check
function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Step "Checking privileges"
if (-not (Test-IsAdmin)) {
    Write-Fail "This script must be run as Administrator."
    Write-Host "  Right-click PowerShell -> 'Run as administrator', then re-run." -ForegroundColor Yellow
    exit 1
}
Write-Ok "Running as Administrator"

# Task 1.2 + 1.3: Download / install Syncthing
function Get-SyncthingVersion {
    param([string]$Exe)
    try {
        $out = & $Exe --version 2>&1 | Select-Object -First 1
        if ($out -match 'syncthing\s+v([\d.]+)') { return $Matches[1] }
    } catch {}
    return $null
}

function Install-Syncthing {
    Write-Step "Installing Syncthing"

    if (Test-Path $ExePath) {
        $ver = Get-SyncthingVersion $ExePath
        Write-Skip "Syncthing already installed (v$ver) at $ExePath"
        return
    }

    Write-Host "  Fetching latest release from GitHub..." -ForegroundColor DarkGray
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/syncthing/syncthing/releases/latest" `
                                 -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -like "*windows-amd64*.zip" } |
             Select-Object -First 1

    if (-not $asset) {
        throw "Could not find Windows amd64 release asset. Check https://github.com/syncthing/syncthing/releases"
    }

    $zipUrl  = $asset.browser_download_url
    $zipFile = Join-Path $env:TEMP "syncthing-windows-amd64.zip"

    Write-Host "  Downloading $($asset.name)..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    Write-Host "  Extracting..." -ForegroundColor DarkGray
    $extractDir = Join-Path $env:TEMP "syncthing-extract"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    Expand-Archive -Path $zipFile -DestinationPath $extractDir

    $exeSource = Get-ChildItem -Path $extractDir -Recurse -Filter "syncthing.exe" |
                 Select-Object -First 1

    if (-not $exeSource) { throw "syncthing.exe not found in zip archive." }

    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
    Copy-Item $exeSource.FullName -Destination $ExePath

    Remove-Item $zipFile -Force
    Remove-Item $extractDir -Recurse -Force

    $ver = Get-SyncthingVersion $ExePath
    Write-Ok "Installed Syncthing v$ver to $ExePath"
}

Install-Syncthing

# Task 1.4: Create backup folders
function New-BackupFolders {
    Write-Step "Creating backup folders under $BackupRoot"
    foreach ($folder in $BackupFolders) {
        $path = Join-Path $BackupRoot $folder
        if (Test-Path $path) {
            Write-Skip "$folder already exists"
        } else {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Ok "Created $path"
        }
    }
}

New-BackupFolders

# Task 1.5: Firewall rules
function Set-FirewallRules {
    Write-Step "Configuring Windows Firewall rules"

    $rules = @(
        @{ Name="Syncthing-TCP";       Protocol="TCP"; Port=22000; Direction="Both"    },
        @{ Name="Syncthing-UDP";       Protocol="UDP"; Port=22000; Direction="Both"    },
        @{ Name="Syncthing-Discovery"; Protocol="UDP"; Port=21027; Direction="Inbound" }
    )

    foreach ($rule in $rules) {
        $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Skip "Firewall rule '$($rule.Name)' already exists"
            continue
        }

        $params = @{
            DisplayName = $rule.Name
            Protocol    = $rule.Protocol
            LocalPort   = $rule.Port
            Action      = "Allow"
            Profile     = "Private"
            Program     = $ExePath
        }

        if ($rule.Direction -eq "Both") {
            New-NetFirewallRule @params -Direction Inbound  | Out-Null
            New-NetFirewallRule @params -Direction Outbound | Out-Null
            Write-Ok "Created '$($rule.Name)' (Inbound + Outbound)"
        } else {
            New-NetFirewallRule @params -Direction $rule.Direction | Out-Null
            Write-Ok "Created '$($rule.Name)' ($($rule.Direction))"
        }
    }
}

Set-FirewallRules

# Task 1.6: Generate initial config
function Initialize-SyncthingConfig {
    Write-Step "Initializing Syncthing configuration"
    if (Test-Path $ConfigPath) {
        Write-Skip "config.xml already exists -- skipping generation"
        return
    }
    Write-Host "  Running syncthing generate to create initial config..." -ForegroundColor DarkGray
    & $ExePath generate --home $ConfigDir | Out-Null
    if (-not (Test-Path $ConfigPath)) {
        throw "syncthing generate did not produce config.xml at $ConfigPath"
    }
    Write-Ok "Generated config.xml"
}

Initialize-SyncthingConfig

# Helper: set or create an XML element value
function Set-XmlValue {
    param([System.Xml.XmlElement]$Parent, [string]$Tag, [string]$Value)
    $node = $Parent[$Tag]
    if ($node) {
        $node.InnerText = $Value
    } else {
        $el = $Parent.OwnerDocument.CreateElement($Tag)
        $el.InnerText = $Value
        $Parent.AppendChild($el) | Out-Null
    }
}

# Task 1.7: Patch config.xml
function Invoke-PatchConfig {
    Write-Step "Patching Syncthing config.xml"

    [xml]$cfg = Get-Content $ConfigPath -Raw

    $gui = $cfg.configuration.gui
    if ($gui) {
        $gui.address = "127.0.0.1:8384"
        Write-Ok "GUI bound to 127.0.0.1:8384"
    }

    $opts = $cfg.configuration.options
    if ($opts) {
        Set-XmlValue $opts "globalAnnounceEnabled" "false"
        Set-XmlValue $opts "relaysEnabled"         "false"
        Set-XmlValue $opts "localAnnounceEnabled"  "true"
        Write-Ok "LAN-only mode: global discovery=off, relays=off, local discovery=on"
    }

    # Fix: syncthing generate writes whitespace into <encryptionPassword> elements in
    # the defaults template. When the phone pairs and Syncthing creates folder entries
    # from that template, the whitespace propagates into every folder's device entry.
    # Syncthing then advertises the PC as an "untrusted encrypted peer" in ClusterConfig,
    # causing the phone to immediately drop every connection. Clear all of them now.
    $pwNodes = $cfg.SelectNodes("//encryptionPassword")
    $cleaned = 0
    foreach ($node in $pwNodes) {
        if ($node.InnerText.Trim() -ne "") {
            $node.InnerText = ""
            $cleaned++
        }
    }
    if ($cleaned -gt 0) {
        Write-Ok "Cleared $cleaned whitespace encryptionPassword field(s) (syncthing generate artifact)"
    }

    $cfg.Save($ConfigPath)
    Write-Ok "config.xml saved"
}

Invoke-PatchConfig

# Task 7.1: Validate config
function Test-SyncthingConfig {
    Write-Step "Validating Syncthing configuration"
    [xml]$cfg = Get-Content $ConfigPath -Raw

    $issues = @()
    $addr = $cfg.configuration.gui.address
    if ($addr -ne "127.0.0.1:8384") {
        $issues += "GUI address is '$addr' (expected 127.0.0.1:8384)"
    }
    $opts = $cfg.configuration.options
    if ($opts.globalAnnounceEnabled -ne "false") {
        $issues += "globalAnnounceEnabled is not false"
    }
    if ($opts.relaysEnabled -ne "false") {
        $issues += "relaysEnabled is not false"
    }

    if ($issues.Count -gt 0) {
        foreach ($i in $issues) { Write-Warn "Config issue: $i" }
        return $false
    }

    Write-Ok "Config validation passed (localhost-only UI, LAN-only sync)"
    return $true
}

$null = Test-SyncthingConfig

# Task 7.2: Apply staggered versioning to existing receive folders
# (safe to re-run after pairing phone; call Set-StaggeredVersioning directly if needed)
function Set-StaggeredVersioning {
    Write-Step "Applying staggered versioning to existing folders"

    [xml]$cfg = Get-Content $ConfigPath -Raw
    $folders  = @($cfg.configuration.SelectNodes('folder'))
    if ($folders.Count -eq 0) {
        Write-Skip "No folders in config yet -- run again after pairing your phone"
        return
    }

    $changed = $false
    foreach ($folder in @($folders)) {
        if ($folder.type -notin @("receiveonly","receive")) { continue }

        $ver = $folder.SelectSingleNode('versioning')
        if (-not $ver) {
            $ver = $cfg.CreateElement("versioning")
            $folder.AppendChild($ver) | Out-Null
        }
        if ($ver.type -ne "staggered") {
            $ver.SetAttribute("type","staggered")
            $param = $cfg.CreateElement("param")
            $param.SetAttribute("key","maxAge")
            $param.SetAttribute("val","31536000")
            $ver.AppendChild($param) | Out-Null
            Write-Ok "Set staggered versioning on folder '$($folder.id)'"
            $changed = $true
        } else {
            Write-Skip "Folder '$($folder.id)' already has staggered versioning"
        }
    }

    if ($changed) { $cfg.Save($ConfigPath) }
}

Set-StaggeredVersioning

# Tasks 2.1 + 2.2 + 2.3: Task Scheduler
function Register-SyncthingTask {
    Write-Step "Registering Task Scheduler task '$TaskName'"

    $action   = New-ScheduledTaskAction -Execute $ExePath -Argument "--no-browser --no-restart --home `"$ConfigDir`""
    $trigger  = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
        -RestartCount 999 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
                          -Settings $settings -Principal $principal | Out-Null
        Write-Ok "Updated existing task '$TaskName'"
    } else {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
                               -Settings $settings -Principal $principal | Out-Null
        Write-Ok "Registered new task '$TaskName'"
    }

    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 3
    $state = (Get-ScheduledTask -TaskName $TaskName).State
    if ($state -eq "Running") {
        Write-Ok "Syncthing is now running"
    } else {
        Write-Warn "Task started but state is '$state' -- check Task Scheduler if Syncthing does not appear in processes"
    }
}

Register-SyncthingTask

# Final summary
Write-Host ""
Write-Host "+-----------------------------------------------------+" -ForegroundColor Green
Write-Host "|  Setup complete!                                    |" -ForegroundColor Green
Write-Host "+-----------------------------------------------------+" -ForegroundColor Green
Write-Host "|  Syncthing web UI : http://127.0.0.1:8384           |" -ForegroundColor Green
Write-Host "|  Backup root      : $BackupRoot" -ForegroundColor Green
Write-Host "|                                                     |" -ForegroundColor Green
Write-Host "|  Next steps:                                        |" -ForegroundColor Green
Write-Host "|  1. Open http://127.0.0.1:8384 in your browser      |" -ForegroundColor Green
Write-Host "|  2. Follow ANDROID-SETUP.md to pair your phone      |" -ForegroundColor Green
Write-Host "|  3. After pairing, re-run:                          |" -ForegroundColor Green
Write-Host "|       . .\setup-windows.ps1                         |" -ForegroundColor Green
Write-Host "|       Set-StaggeredVersioning                       |" -ForegroundColor Green
Write-Host "|  4. Run check-sync-status.ps1 to verify sync        |" -ForegroundColor Green
Write-Host "+-----------------------------------------------------+" -ForegroundColor Green

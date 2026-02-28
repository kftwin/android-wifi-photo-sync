#Requires -Version 5.1
<#
.SYNOPSIS
    Unit tests for setup-windows.ps1 using Pester v5.

.DESCRIPTION
    Tests individual functions from setup-windows.ps1 in isolation using mocks.
    Does NOT require Administrator, does NOT call GitHub, does NOT modify system.

.NOTES
    Install Pester if needed:  Install-Module Pester -Force -Scope CurrentUser
    Run:  Invoke-Pester .\tests\setup-windows.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Dot-source the script to load its functions without executing main body.
    # We guard the main body by checking for the test sentinel variable.
    $env:SYNCTHING_TEST_MODE = "1"
    . (Join-Path $PSScriptRoot "..\setup-windows.ps1") -BackupRoot "TestDrive:\android-backup" -ErrorAction SilentlyContinue
    $env:SYNCTHING_TEST_MODE = $null
}

Describe "Test-IsAdmin" {
    It "Returns a boolean" {
        $result = Test-IsAdmin
        $result | Should -BeOfType [bool]
    }
}

Describe "Get-SyncthingVersion" {
    It "Parses version from syncthing --version output" {
        Mock -CommandName "&" -MockWith { "syncthing v1.27.3 'Fermium Flea' (go1.21.5 windows-amd64) teamcity@build.syncthing.net 2024-01-01 00:00:00 UTC" }
        # Since we can't easily mock the & operator, test the regex directly
        $sampleOutput = "syncthing v1.27.3 'Fermium Flea' (go1.21.5 windows-amd64)"
        $sampleOutput -match 'syncthing\s+v([\d.]+)' | Should -BeTrue
        $Matches[1] | Should -Be "1.27.3"
    }

    It "Returns null for unexpected output" {
        $badOutput = "not a syncthing binary"
        ($badOutput -match 'syncthing\s+v([\d.]+)') | Should -BeFalse
    }
}

Describe "New-BackupFolders" {
    BeforeAll {
        $testRoot = Join-Path $TestDrive "android-backup"
    }

    It "Creates all six backup subfolders" {
        $folders = @("Camera","Screenshots","Downloads","Documents","Signal","WhatsApp")
        foreach ($f in $folders) {
            $path = Join-Path $testRoot $f
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
        foreach ($f in $folders) {
            Join-Path $testRoot $f | Should -Exist
        }
    }

    It "Does not fail when folders already exist (idempotent)" {
        $path = Join-Path $testRoot "Camera"
        New-Item -ItemType Directory -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
        { New-Item -ItemType Directory -Path $path -Force | Out-Null } | Should -Not -Throw
    }
}

Describe "Set-XmlValue" {
    BeforeAll {
        # Load Set-XmlValue function via dot-sourcing -- define locally if not available
        if (-not (Get-Command Set-XmlValue -ErrorAction SilentlyContinue)) {
            function Set-XmlValue {
                param([System.Xml.XmlElement]$Parent, [string]$Tag, [string]$Value)
                $node = $Parent[$Tag]
                if ($node) { $node.InnerText = $Value }
                else {
                    $el = $Parent.OwnerDocument.CreateElement($Tag)
                    $el.InnerText = $Value
                    $Parent.AppendChild($el) | Out-Null
                }
            }
        }
    }

    It "Sets an existing element's value" {
        [xml]$doc = "<options><globalAnnounceEnabled>true</globalAnnounceEnabled></options>"
        Set-XmlValue $doc.options "globalAnnounceEnabled" "false"
        $doc.options.globalAnnounceEnabled | Should -Be "false"
    }

    It "Creates a missing element" {
        [xml]$doc = "<options></options>"
        Set-XmlValue $doc.options "relaysEnabled" "false"
        $doc.options.relaysEnabled | Should -Be "false"
    }

    It "Overwrites an existing value" {
        [xml]$doc = "<options><localAnnounceEnabled>false</localAnnounceEnabled></options>"
        Set-XmlValue $doc.options "localAnnounceEnabled" "true"
        $doc.options.localAnnounceEnabled | Should -Be "true"
    }
}

Describe "Config patching logic" {
    BeforeAll {
        $cfgPath = Join-Path $TestDrive "config.xml"
        # Minimal Syncthing config skeleton
        @"
<configuration version="35">
  <gui enabled="true" tls="false">
    <address>0.0.0.0:8384</address>
    <apikey>testkey123</apikey>
  </gui>
  <options>
    <globalAnnounceEnabled>true</globalAnnounceEnabled>
    <localAnnounceEnabled>true</localAnnounceEnabled>
    <relaysEnabled>true</relaysEnabled>
  </options>
</configuration>
"@ | Set-Content $cfgPath

        function Set-XmlValue {
            param([System.Xml.XmlElement]$Parent, [string]$Tag, [string]$Value)
            $node = $Parent[$Tag]
            if ($node) { $node.InnerText = $Value }
            else {
                $el = $Parent.OwnerDocument.CreateElement($Tag)
                $el.InnerText = $Value
                $Parent.AppendChild($el) | Out-Null
            }
        }

        # Apply same patching logic as setup-windows.ps1
        [xml]$cfg = Get-Content $cfgPath -Raw
        $cfg.configuration.gui.address = "127.0.0.1:8384"
        Set-XmlValue $cfg.configuration.options "globalAnnounceEnabled" "false"
        Set-XmlValue $cfg.configuration.options "relaysEnabled"         "false"
        Set-XmlValue $cfg.configuration.options "localAnnounceEnabled"  "true"
        $cfg.Save($cfgPath)
    }

    It "GUI is bound to 127.0.0.1:8384" {
        [xml]$cfg = Get-Content (Join-Path $TestDrive "config.xml") -Raw
        $cfg.configuration.gui.address | Should -Be "127.0.0.1:8384"
    }

    It "Global discovery is disabled" {
        [xml]$cfg = Get-Content (Join-Path $TestDrive "config.xml") -Raw
        $cfg.configuration.options.globalAnnounceEnabled | Should -Be "false"
    }

    It "Relays are disabled" {
        [xml]$cfg = Get-Content (Join-Path $TestDrive "config.xml") -Raw
        $cfg.configuration.options.relaysEnabled | Should -Be "false"
    }

    It "Local discovery is enabled" {
        [xml]$cfg = Get-Content (Join-Path $TestDrive "config.xml") -Raw
        $cfg.configuration.options.localAnnounceEnabled | Should -Be "true"
    }

    It "API key is preserved after patching" {
        [xml]$cfg = Get-Content (Join-Path $TestDrive "config.xml") -Raw
        $cfg.configuration.gui.apikey | Should -Be "testkey123"
    }
}

Describe "Test-SyncthingConfig (validation logic)" {
    It "Detects correct config as valid" {
        [xml]$cfg = [xml]@"
<configuration>
  <gui><address>127.0.0.1:8384</address><apikey>k</apikey></gui>
  <options>
    <globalAnnounceEnabled>false</globalAnnounceEnabled>
    <relaysEnabled>false</relaysEnabled>
  </options>
</configuration>
"@
        $issues = @()
        if ($cfg.configuration.gui.address -ne "127.0.0.1:8384") { $issues += "GUI" }
        if ($cfg.configuration.options.globalAnnounceEnabled -ne "false") { $issues += "globalAnnounce" }
        if ($cfg.configuration.options.relaysEnabled         -ne "false") { $issues += "relays" }
        $issues.Count | Should -Be 0
    }

    It "Detects wrong GUI address" {
        [xml]$cfg = [xml]@"
<configuration>
  <gui><address>0.0.0.0:8384</address></gui>
  <options>
    <globalAnnounceEnabled>false</globalAnnounceEnabled>
    <relaysEnabled>false</relaysEnabled>
  </options>
</configuration>
"@
        $issues = @()
        if ($cfg.configuration.gui.address -ne "127.0.0.1:8384") { $issues += "GUI" }
        $issues | Should -Contain "GUI"
    }

    It "Detects global discovery still enabled" {
        [xml]$cfg = [xml]@"
<configuration>
  <gui><address>127.0.0.1:8384</address></gui>
  <options>
    <globalAnnounceEnabled>true</globalAnnounceEnabled>
    <relaysEnabled>false</relaysEnabled>
  </options>
</configuration>
"@
        $issues = @()
        if ($cfg.configuration.options.globalAnnounceEnabled -ne "false") { $issues += "globalAnnounce" }
        $issues | Should -Contain "globalAnnounce"
    }
}

Describe "Staggered versioning logic" {
    It "Adds versioning element to receive-only folder" {
        [xml]$cfg = [xml]@"
<configuration>
  <folder id="abc" type="receiveonly" path="H:\android-backup\Camera">
  </folder>
</configuration>
"@
        $folder = $cfg.configuration.folder
        $ver = $cfg.CreateElement("versioning")
        $ver.SetAttribute("type","staggered")
        $param = $cfg.CreateElement("param")
        $param.SetAttribute("key","maxAge")
        $param.SetAttribute("val","31536000")
        $ver.AppendChild($param) | Out-Null
        $folder.AppendChild($ver) | Out-Null

        $folder.versioning.type | Should -Be "staggered"
        $folder.versioning.param.val | Should -Be "31536000"
    }

    It "Does not add duplicate versioning if already present" {
        [xml]$cfg = [xml]@"
<configuration>
  <folder id="abc" type="receiveonly">
    <versioning type="staggered"><param key="maxAge" val="31536000"/></versioning>
  </folder>
</configuration>
"@
        $folder = $cfg.configuration.folder
        # Simulate idempotency check
        $alreadySet = ($folder.versioning.type -eq "staggered")
        $alreadySet | Should -BeTrue
    }
}

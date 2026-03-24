#Requires -RunAsAdministrator
# ============================================================================
# PHN16-72 Check v7.5
# ============================================================================
# Verifies all BSOD fixes from the Acer Community
# ============================================================================

param(
    [switch]$Debug  # Shows detailed info about what is detected
)

# Auto-relaunch as Administrator if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  Relaunching as Administrator..." -ForegroundColor Yellow

    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Debug) { $argList += "-Debug" }

    try {
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host "  ERROR: Run this script as Administrator!" -ForegroundColor Red
        exit 1
    }
}

$ErrorActionPreference = "SilentlyContinue"

# Stable versions
$DTT_STABLE = "9.0.11404"
$DTT_ACER_STABLE = "1.0.11401"
$IPF_STABLE = "1.0.11404"

# Counters
$OK = 0
$WARN = 0
$ERR = 0

function Write-Check {
    param([string]$Name, [string]$Status, [string]$Detail = "")

    $icon = switch ($Status) {
        "OK"   { "[OK]"; $script:OK++ }
        "WARN" { "[!]"; $script:WARN++ }
        "ERR"  { "[X]"; $script:ERR++ }
        default { "[-]" }
    }

    $color = switch ($Status) {
        "OK"   { "Green" }
        "WARN" { "Yellow" }
        "ERR"  { "Red" }
        default { "Gray" }
    }

    $msg = "  $icon $Name"
    if ($Detail) { $msg += " - $Detail" }
    Write-Host $msg -ForegroundColor $color
}

# Header
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "           PHN16-72 BSOD FIX CHECK v7.5" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Verifies fixes from Acer Community (artkirius, jihakkim, Puraw)" -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Read drivers
$drivers = Get-WmiObject Win32_PnPSignedDriver 2>$null |
    Select-Object DeviceName, DriverVersion, InfName, Manufacturer

if (!$drivers) {
    Write-Host "  ERROR: Unable to read drivers!" -ForegroundColor Red
    exit 1
}

# Debug: show what is detected
if ($Debug) {
    Write-Host ""
    Write-Host "=== DEBUG INFO ===" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "DPTF - ESIF Service:" -ForegroundColor Magenta
    $debugEsif = Get-Service "esifsvc*" 2>$null
    if ($debugEsif) {
        $debugEsif | ForEach-Object { Write-Host "  [FOUND] $($_.Name): $($_.Status)" -ForegroundColor Green }
    } else {
        Write-Host "  (no esifsvc* service)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "DPTF - Installation folders:" -ForegroundColor Magenta
    $dttPaths = @(
        "$env:ProgramFiles\Intel\Intel(R) Dynamic Tuning Technology",
        "$env:ProgramFiles\Intel\DPTF",
        "$env:ProgramFiles (x86)\Intel\Intel(R) Dynamic Tuning Technology"
    )
    foreach ($path in $dttPaths) {
        if (Test-Path $path) {
            Write-Host "  [FOUND] $path" -ForegroundColor Green
            Get-ChildItem $path -Filter "*.exe" 2>$null | ForEach-Object {
                Write-Host "    - $($_.Name) v$($_.VersionInfo.FileVersion)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [NO] $path" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "DPTF - Installed programs:" -ForegroundColor Magenta
    $debugDptfPkg = Get-Package "*Dynamic*","*DPTF*","*Thermal*" 2>$null | Where-Object { $_.Name -like "*Intel*" -or $_.Name -like "*Tuning*" }
    if ($debugDptfPkg) {
        $debugDptfPkg | ForEach-Object { Write-Host "  [FOUND] $($_.Name) v$($_.Version)" -ForegroundColor Green }
    } else {
        Write-Host "  (no DPTF/DTT program found)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "DPTF - Device Manager:" -ForegroundColor Magenta
    $debugDtt = $drivers | Where-Object {
        $_.DeviceName -like "*Dynamic*" -or
        $_.DeviceName -like "*DPTF*" -or
        $_.DeviceName -like "*DTT*" -or
        $_.DeviceName -like "*Thermal*" -or
        $_.InfName -like "*dptf*" -or
        $_.InfName -like "*dtt*" -or
        $_.InfName -like "*esif*"
    }
    if ($debugDtt) {
        $debugDtt | ForEach-Object { Write-Host "  [FOUND] $($_.DeviceName) | $($_.DriverVersion) | $($_.InfName)" -ForegroundColor Green }
    } else {
        Write-Host "  (no DPTF driver in Device Manager - normal for Acer!)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Killer - Packages:" -ForegroundColor Magenta
    $debugKiller = Get-Package "*Killer*" 2>$null
    if ($debugKiller) {
        $debugKiller | ForEach-Object {
            $isDriver = $_.Name -like "*Driver*" -or $_.Name -like "*WiFi*" -or $_.Name -like "*Wireless*"
            $tag = if ($isDriver) { "[DRIVER - OK]" } else { "[SOFTWARE]" }
            $color = if ($isDriver) { "Green" } else { "Yellow" }
            Write-Host "  $tag $($_.Name)" -ForegroundColor $color
        }
    } else {
        Write-Host "  (no Killer package)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Killer - Services:" -ForegroundColor Magenta
    $debugKillerSvc = Get-Service "*Killer*" 2>$null
    if ($debugKillerSvc) {
        $debugKillerSvc | ForEach-Object { Write-Host "  - $($_.Name): $($_.Status)" -ForegroundColor Gray }
    } else {
        Write-Host "  (no Killer service)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "=== END DEBUG ===" -ForegroundColor Magenta
    Write-Host ""
}

# ============================================================================
# SECTION 1: CRITICAL DRIVERS
# ============================================================================

Write-Host "-- CRITICAL DRIVERS --" -ForegroundColor Cyan
Write-Host ""

# 1. Intel PPM (should stay enabled on updated BIOS)
$intelppmKey = "HKLM:\SYSTEM\CurrentControlSet\Services\intelppm"
$intelppmStart = (Get-ItemProperty $intelppmKey -Name Start -EA 0).Start

if ($intelppmStart -eq 4) {
    Write-Check "Intel PPM (intelppm)" "WARN" "DISABLED (Start=4) - legacy workaround, usually not needed"
} elseif ($intelppmStart -eq 3 -or $intelppmStart -eq 1) {
    Write-Check "Intel PPM (intelppm)" "OK" "ACTIVE (Start=$intelppmStart) - expected on updated BIOS"
} else {
    Write-Check "Intel PPM (intelppm)" "WARN" "Start=$intelppmStart - unknown state"
}

# 2. DTT/DPTF - MULTI-METHOD DETECTION
# NOTE: The Acer DPTF package often does NOT appear in Device Manager!

$dptfFound = $false
$dptfVersion = ""
$dptfSource = ""

# Method 1: ESIF Service
$esifSvc = Get-Service "esifsvc*" 2>$null
if ($esifSvc) {
    $dptfFound = $true
    $dptfSource = "service $($esifSvc.Name)"
}

# Method 2: Installation folder
$dttPaths = @(
    "$env:ProgramFiles\Intel\Intel(R) Dynamic Tuning Technology",
    "$env:ProgramFiles\Intel\DPTF",
    "$env:ProgramFiles (x86)\Intel\Intel(R) Dynamic Tuning Technology"
)
foreach ($path in $dttPaths) {
    if (Test-Path $path) {
        $dptfFound = $true
        $esifExe = Get-ChildItem "$path\esif*.exe" -EA 0 | Select-Object -First 1
        if ($esifExe) {
            $dptfVersion = $esifExe.VersionInfo.FileVersion
            $dptfSource = "folder"
        }
        break
    }
}

# Method 3: Installed programs
$installedDptf = Get-Package "*Dynamic Tuning*","*DPTF*","*Thermal Framework*" 2>$null | Select-Object -First 1
if ($installedDptf) {
    $dptfFound = $true
    if (!$dptfVersion) { $dptfVersion = $installedDptf.Version }
    $dptfSource = "program"
}

# Method 4: Device Manager (fallback)
$dtt = $drivers | Where-Object {
    $_.DeviceName -like "*Dynamic Tuning*" -or
    $_.DeviceName -like "*Dynamic Platform*" -or
    $_.DeviceName -like "*DPTF*" -or
    $_.DeviceName -like "*DTT*" -or
    $_.DeviceName -like "*Thermal Framework*" -or
    $_.InfName -like "*dptf*" -or
    $_.InfName -like "*dtt*" -or
    $_.InfName -like "*esif*"
} | Select-Object -First 1

if ($dtt) {
    $dptfFound = $true
    if (!$dptfVersion) { $dptfVersion = $dtt.DriverVersion }
    $dptfSource = "device manager"
}

# Evaluate result
if ($dptfFound) {
    if ($dptfVersion) {
        if ($dptfVersion -match "11404|11401|11400|11399") {
            Write-Check "Intel DPTF/DTT" "OK" "$dptfVersion (stable)"
        } elseif ($dptfVersion -match "11405|11406|11407|117|118|119") {
            Write-Check "Intel DPTF/DTT" "ERR" "$dptfVersion (CAUSES BSOD!)"
        } else {
            Write-Check "Intel DPTF/DTT" "WARN" "$dptfVersion"
        }
    } else {
        Write-Check "Intel DPTF/DTT" "OK" "Installed ($dptfSource)"
    }
} else {
    Write-Check "Intel DPTF/DTT" "WARN" "Not installed - install Acer DPTF (without APO) 1.0.11401"
}

# 3. IPF
$ipf = $drivers | Where-Object {
    $_.DeviceName -like "*Innovation Platform*" -or
    $_.InfName -like "*ipf*"
} | Select-Object -First 1

if ($ipf) {
    $ver = $ipf.DriverVersion
    if ($ver -match "11404|11401|11400") {
        Write-Check "Intel IPF" "OK" "$ver (stable)"
    } elseif ($ver -match "11405|11406|117|118|119") {
        Write-Check "Intel IPF" "ERR" "$ver (problematic version)"
    } else {
        Write-Check "Intel IPF" "WARN" "$ver"
    }
} else {
    Write-Check "Intel IPF" "WARN" "Not installed"
}

# 4. GNA (must be ABSENT)
$gna = $drivers | Where-Object {
    $_.DeviceName -like "*GNA*" -or
    $_.DeviceName -like "*Gaussian*" -or
    $_.InfName -like "*gna*"
}
$gnaDevice = Get-PnpDevice -FriendlyName "*GNA*","*Gaussian*" 2>$null

if ($gna -or $gnaDevice) {
    $gnaStatus = if ($gnaDevice.Status -eq "Error" -or $gnaDevice.Status -eq "Degraded") { "disabled" } else { "ACTIVE" }
    if ($gnaStatus -eq "disabled") {
        Write-Check "Intel GNA" "OK" "Present but disabled"
    } else {
        Write-Check "Intel GNA" "ERR" "PRESENT AND ACTIVE - causes BSOD! Disable it!"
    }
} else {
    Write-Check "Intel GNA" "OK" "Not present (correct)"
}

# 5. HID Event Filter
$hid = $drivers | Where-Object {
    $_.DeviceName -like "*HID Event Filter*" -or
    $_.InfName -match "INTC1070|heci"
}
$hidDevice = Get-PnpDevice | Where-Object { $_.InstanceId -like "*INTC1070*" } 2>$null

if ($hid -or $hidDevice) {
    $hidStatus = if ($hidDevice.Status -eq "Error" -or $hidDevice.Status -eq "Degraded") { "disabled" } else { "active" }
    if ($hidStatus -eq "disabled") {
        Write-Check "Intel HID Event Filter" "OK" "Disabled"
    } else {
        Write-Check "Intel HID Event Filter" "WARN" "Active - may cause freezes"
    }
} else {
    Write-Check "Intel HID Event Filter" "OK" "Not present"
}

Write-Host ""

# ============================================================================
# SECTION 2: BLOATWARE
# ============================================================================

Write-Host "-- BLOATWARE --" -ForegroundColor Cyan
Write-Host ""

# Killer SOFTWARE (not the WiFi driver!)
# NOTE: Intel Killer AX1675i is the WiFi chip - the driver is required
# Search ONLY for bloatware software, NOT drivers
$killerSoftware = Get-Package 2>$null | Where-Object {
    $_.Name -like "*Killer*" -and
    $_.Name -notlike "*Driver*" -and
    $_.Name -notlike "*WiFi*" -and
    $_.Name -notlike "*Wireless*" -and
    $_.Name -notlike "*Bluetooth*" -and
    $_.Name -notlike "*Network*"
}
$killerServices = Get-Service 2>$null | Where-Object {
    $_.Name -like "*Killer*" -and $_.Status -eq "Running"
}

if ($killerSoftware -or $killerServices) {
    $swNames = ($killerSoftware | ForEach-Object { $_.Name }) -join ", "
    if ($swNames) {
        Write-Check "Killer SOFTWARE" "WARN" "$swNames - optional bloatware"
    } else {
        Write-Check "Killer SOFTWARE" "WARN" "Running services - optional bloatware"
    }
} else {
    Write-Check "Killer SOFTWARE" "OK" "Not present"
}

# Verify that the WiFi driver is present
$wifiKiller = $drivers | Where-Object { $_.DeviceName -like "*Killer*Wi-Fi*" -or $_.DeviceName -like "*Killer*Wireless*" }
if ($wifiKiller) {
    Write-Check "Killer WiFi Driver" "OK" "Present (required for AX1675i)"
}

Write-Host ""

# ============================================================================
# SECTION 3: WINDOWS UPDATE BLOCKS
# ============================================================================

Write-Host "-- WINDOWS UPDATE BLOCKS --" -ForegroundColor Cyan
Write-Host ""

# ExcludeWUDriversInQualityUpdate
$wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$excludeWU = (Get-ItemProperty $wuKey -Name "ExcludeWUDriversInQualityUpdate" -EA 0).ExcludeWUDriversInQualityUpdate

if ($excludeWU -eq 1) {
    Write-Check "ExcludeWUDriversInQualityUpdate" "OK" "Active (drivers blocked from WU)"
} else {
    Write-Check "ExcludeWUDriversInQualityUpdate" "WARN" "Not active - WU can reinstall drivers"
}

# SearchOrderConfig
$dsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
$searchOrder = (Get-ItemProperty $dsKey -Name "SearchOrderConfig" -EA 0).SearchOrderConfig

if ($searchOrder -eq 0) {
    Write-Check "SearchOrderConfig" "OK" "= 0 (online driver search disabled)"
} else {
    Write-Check "SearchOrderConfig" "WARN" "= $searchOrder (online driver search active)"
}

# Blocked Hardware IDs
$denyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs"
$blockedCount = 0
if (Test-Path $denyKey) {
    $blockedCount = (Get-Item $denyKey).Property.Count
}

if ($blockedCount -ge 50) {
    Write-Check "Blocked Hardware IDs" "OK" "$blockedCount devices (all drivers protected)"
} elseif ($blockedCount -gt 0) {
    Write-Check "Blocked Hardware IDs" "WARN" "$blockedCount devices (more blocks may be needed)"
} else {
    Write-Check "Blocked Hardware IDs" "WARN" "No blocks - WU can overwrite drivers"
}

Write-Host ""

# ============================================================================
# SECTION 4: ESSENTIAL DRIVERS
# ============================================================================

Write-Host "-- ESSENTIAL DRIVERS --" -ForegroundColor Cyan
Write-Host ""

# Intel Graphics
$igfx = $drivers | Where-Object {
    $_.DeviceName -like "*Intel*UHD*" -or
    $_.DeviceName -like "*Intel*Iris*" -or
    $_.DeviceName -like "*Intel*Graphics*"
} | Select-Object -First 1

if ($igfx) {
    Write-Check "Intel Graphics" "OK" "$($igfx.DriverVersion)"
} else {
    Write-Check "Intel Graphics" "WARN" "Not found - install Intel UMA VGA driver"
}

# NVIDIA
$nvidia = $drivers | Where-Object {
    $_.DeviceName -like "*NVIDIA*" -or
    $_.DeviceName -like "*GeForce*"
} | Select-Object -First 1

if ($nvidia) {
    Write-Check "NVIDIA GPU" "OK" "$($nvidia.DriverVersion)"
} else {
    Write-Check "NVIDIA GPU" "ERR" "Not found!"
}

# WiFi
$wifi = $drivers | Where-Object {
    $_.DeviceName -like "*Wi-Fi*" -or
    $_.DeviceName -like "*Wireless*" -or
    $_.DeviceName -like "*WLAN*"
} | Select-Object -First 1

if ($wifi) {
    # Intel Killer AX1675i is the standard chip - this is fine!
    Write-Check "WiFi" "OK" "$($wifi.DeviceName)"
} else {
    Write-Check "WiFi" "ERR" "Not found!"
}

# Serial IO / Touchpad
$serialio = $drivers | Where-Object {
    $_.InfName -like "*iaLPSS*" -or
    $_.DeviceName -like "*Serial IO*" -or
    $_.DeviceName -like "*I2C*"
}

if ($serialio -and $serialio.Count -gt 0) {
    Write-Check "Serial IO (touchpad)" "OK" "$($serialio.Count) driver(s)"
} else {
    Write-Check "Serial IO (touchpad)" "WARN" "Not found - touchpad support may be missing"
}

# ME (Management Engine)
$me = $drivers | Where-Object {
    $_.DeviceName -like "*Management Engine*" -or
    $_.InfName -like "*heci*" -or
    $_.InfName -like "*mei*"
} | Select-Object -First 1

if ($me) {
    Write-Check "Intel ME" "OK" "$($me.DriverVersion)"
} else {
    Write-Check "Intel ME" "WARN" "Not found"
}

# LAN (Ethernet)
$lan = $drivers | Where-Object {
    $_.DeviceName -like "*Ethernet*" -or
    $_.DeviceName -like "*LAN*" -or
    $_.DeviceName -like "*Killer E*" -or
    $_.InfName -like "*e1d*" -or
    $_.InfName -like "*e1r*"
} | Select-Object -First 1

if ($lan) {
    Write-Check "LAN Ethernet" "OK" "$($lan.DeviceName)"
} else {
    Write-Check "LAN Ethernet" "WARN" "Not found"
}

# Audio
$audio = $drivers | Where-Object {
    $_.DeviceName -like "*Realtek*" -or
    $_.DeviceName -like "*High Definition Audio*"
} | Select-Object -First 1

if ($audio) {
    Write-Check "Audio" "OK" "$($audio.DeviceName)"
} else {
    Write-Check "Audio" "WARN" "Not found"
}

Write-Host ""

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "                         SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  OK:        $OK" -ForegroundColor Green
Write-Host "  Warning:   $WARN" -ForegroundColor Yellow
Write-Host "  Errors:    $ERR" -ForegroundColor Red
Write-Host ""

if ($ERR -eq 0 -and $WARN -le 2) {
    Write-Host "  STATUS: System configured correctly!" -ForegroundColor Green
    Write-Host "          BSODs should be resolved." -ForegroundColor Green
} elseif ($ERR -eq 0) {
    Write-Host "  STATUS: System OK with some warnings" -ForegroundColor Yellow
    Write-Host "          Check the warnings above if you still have issues." -ForegroundColor Yellow
} else {
    Write-Host "  STATUS: ISSUES DETECTED!" -ForegroundColor Red
    Write-Host "          Run HeliosPHN16-72_Setup.ps1 to apply the fixes." -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

# Show recommended actions if there are errors
if ($ERR -gt 0) {
    Write-Host ""
    Write-Host "  RECOMMENDED ACTIONS:" -ForegroundColor Yellow

    # Specific checks
    if ($intelppmStart -eq 4) {
        Write-Host "  - Re-enable Intel PPM unless you intentionally need the legacy workaround" -ForegroundColor White
    }

    $gnaActive = Get-PnpDevice -FriendlyName "*GNA*","*Gaussian*" 2>$null | Where-Object { $_.Status -eq "OK" }
    if ($gnaActive) {
        Write-Host "  - Run Setup.ps1 to disable GNA" -ForegroundColor White
    }

    if (!$dptfFound) {
        Write-Host "  - Install Acer DPTF (without APO) v1.0.11401" -ForegroundColor White
    } elseif ($dptfVersion -match "11405|11406|11407|117|118|119") {
        Write-Host "  - Remove DTT 11405+/DPTF (APO) and install Acer DPTF (without APO) v1.0.11401" -ForegroundColor White
    }

    Write-Host ""
}

Write-Host ""

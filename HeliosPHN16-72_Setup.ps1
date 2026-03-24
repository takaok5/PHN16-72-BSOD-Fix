#Requires -RunAsAdministrator
# ============================================================================
# PHN16-72 Setup v7.6
# ============================================================================
# BASED ON DOCUMENTED SOLUTIONS FROM THE ACER COMMUNITY:
# - https://community.acer.com/en/discussion/723737 (artkirius - SOLVED)
# - https://community.acer.com/en/discussion/728746 (jihakkim - intelppm fix)
# - https://community.acer.com/en/discussion/728578 (Puraw - clean install)
# - https://community.acer.com/en/discussion/726672 (StevenGen - setup)
#
# IDENTIFIED PROBLEMATIC DRIVERS:
# 1. Intel DPTF/DTT (dtt_sw.inf) - thermal crashes, PredatorSense conflict
# 2. Intel GNA (gna.inf) - various BSOD
# 3. Intel HID Event Filter (INTC1070) - system freeze
# 4. Intel Chipset (RaptorLakeSystem.inf) - corrupt drivers
# 5. Intel PPM (intelppm.sys) - keep enabled on updated Acer BIOS
#    PredatorGuard is a separate optional tool for locking MSR writes
#
# APPLIED FIXES:
# - Removes/blocks all problematic drivers
# - Blocks reinstallation via Windows Update
# - Installs stable DTT/IPF versions
# - Removes Killer SOFTWARE (not the WiFi driver - it's needed!)
#
# NOTE: Intel Killer AX1675i is the standard WiFi chip of the PHN16-72.
#       Intel acquired Killer, so the "Killer" driver = Intel driver.
#       The BLOATWARE is the Killer Control Center software, not the driver.
#
# IMPORTANT: On the Acer site there are TWO versions of DPTF:
#   - DPTF (APO) = requires DTT 11405+ = CAUSES BSOD! DO NOT INSTALL!
#   - DPTF (without APO) = DTT 11401 or earlier = STABLE, install this one!
# ============================================================================

param(
    [switch]$SkipDownload,
    [switch]$SkipInstall,
    [switch]$DryRun,
    [switch]$DisableIntelppm  # Opt-in: disable intelppm (only for old BIOS)
)

# Auto-relaunch as Administrator if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  Relaunching as Administrator..." -ForegroundColor Yellow

    # Rebuild arguments
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($SkipDownload)     { $argList += "-SkipDownload" }
    if ($SkipInstall)      { $argList += "-SkipInstall" }
    if ($DryRun)           { $argList += "-DryRun" }
    if ($DisableIntelppm)  { $argList += "-DisableIntelppm" }

    try {
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host ""
        Write-Host "  ============================================================" -ForegroundColor Red
        Write-Host "  ERROR: Unable to obtain Administrator privileges!" -ForegroundColor Red
        Write-Host "  ============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "  How to do it manually:" -ForegroundColor Yellow
        Write-Host "  1. Search for 'PowerShell' in the Start menu" -ForegroundColor White
        Write-Host "  2. Right-click -> 'Run as administrator'" -ForegroundColor White
        Write-Host "  3. Navigate to the script folder and re-run it" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

$ErrorActionPreference = "SilentlyContinue"

# Paths
$DownloadPath = "$env:USERPROFILE\Downloads\AcerDrivers_PHN16-72"
$TempPath = "$env:TEMP\AcerDriverSetup"
$LogFile = "$env:USERPROFILE\Desktop\PHN16-72_Setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Stable versions (PRE-BSOD)
$DTT_STABLE = "9.0.11404"
$IPF_STABLE = "1.0.11404"

# URL
$Acer_URL = "https://www.acer.com/it-it/support/product-support/Predator_PHN16-72"

# Hardware IDs to block (prevents Windows Update from overwriting drivers)
# NOTE: We block ALL drivers we install manually to prevent automatic updates

$BLOCKED_HWIDS = @(
    # === PROBLEMATIC DRIVERS (ALWAYS BLOCKED) ===
    # GNA - Gaussian Neural Accelerator
    "PCI\VEN_8086&DEV_464F",
    "PCI\VEN_8086&DEV_4E11",
    "PCI\VEN_8086&DEV_A74F",
    "PCI\VEN_8086&DEV_7E4C",
    # HID Event Filter
    "ACPI\INTC1070",
    "ACPI\INTC1051",
    "ACPI\INTC1054",
    "ACPI\INTC1057",

    # === DTT/DPTF ===
    "ACPI\INTC1041",  # DTT Manager
    "ACPI\INTC1042",  # DTT Participant
    "ACPI\INTC1043",
    "ACPI\INTC1044",
    "ACPI\INTC1045",
    "ACPI\INTC1046",
    "ACPI\INTC1047",
    "ACPI\INTC1048",
    "ACPI\INTC1049",
    "ACPI\INTC104A",
    "ACPI\INTC10A0",
    "ACPI\INTC10A1",
    "ACPI\INTC10A2",
    "ACPI\INTC10A3",
    "ACPI\INTC10A4",

    # === CHIPSET / SERIAL IO ===
    "PCI\VEN_8086&DEV_7E20",  # Serial IO I2C
    "PCI\VEN_8086&DEV_7E21",
    "PCI\VEN_8086&DEV_7E22",
    "PCI\VEN_8086&DEV_7E23",
    "PCI\VEN_8086&DEV_7E24",
    "PCI\VEN_8086&DEV_7E25",
    "PCI\VEN_8086&DEV_7E30",  # Serial IO SPI
    "PCI\VEN_8086&DEV_7E32",
    "PCI\VEN_8086&DEV_7E4C",
    "PCI\VEN_8086&DEV_7E50",  # Serial IO UART
    "PCI\VEN_8086&DEV_7E52",
    "PCI\VEN_8086&DEV_A0C5",  # Tiger/Raptor Lake Serial IO
    "PCI\VEN_8086&DEV_A0C6",
    "PCI\VEN_8086&DEV_A0C7",
    "PCI\VEN_8086&DEV_A0D8",
    "PCI\VEN_8086&DEV_A0D9",
    "PCI\VEN_8086&DEV_A0DA",
    "PCI\VEN_8086&DEV_A0DB",
    "PCI\VEN_8086&DEV_A0DC",
    "PCI\VEN_8086&DEV_A0DD",
    "PCI\VEN_8086&DEV_A0DE",
    "PCI\VEN_8086&DEV_A0DF",
    "PCI\VEN_8086&DEV_A0E8",
    "PCI\VEN_8086&DEV_A0E9",
    "PCI\VEN_8086&DEV_A0EA",
    "PCI\VEN_8086&DEV_A0EB",

    # === ME (Management Engine) ===
    "PCI\VEN_8086&DEV_7E70",
    "PCI\VEN_8086&DEV_A0E0",
    "PCI\VEN_8086&DEV_A13A",

    # === VGA INTEL (UHD Graphics) ===
    "PCI\VEN_8086&DEV_A780",  # Intel UHD Graphics 14th Gen
    "PCI\VEN_8086&DEV_A781",
    "PCI\VEN_8086&DEV_A782",
    "PCI\VEN_8086&DEV_A788",  # Raptor Lake UHD
    "PCI\VEN_8086&DEV_A789",
    "PCI\VEN_8086&DEV_A78A",
    "PCI\VEN_8086&DEV_A78B",

    # === AUDIO REALTEK ===
    "HDAUDIO\FUNC_01&VEN_10EC*",  # Realtek HD Audio pattern
    "INTELAUDIO\FUNC_01&VEN_10EC*",

    # === LAN (ETHERNET) ===
    "PCI\VEN_8086&DEV_0DC5",  # Intel Ethernet
    "PCI\VEN_8086&DEV_0DC6",
    "PCI\VEN_8086&DEV_0DC7",
    "PCI\VEN_8086&DEV_0DC8",
    "PCI\VEN_8086&DEV_125B",
    "PCI\VEN_8086&DEV_125C",
    "PCI\VEN_8086&DEV_125D",
    "PCI\VEN_8086&DEV_15F2",  # Killer E3100X
    "PCI\VEN_8086&DEV_15F3",
    "PCI\VEN_8086&DEV_15F4",
    "PCI\VEN_8086&DEV_3100",
    "PCI\VEN_8086&DEV_3101",
    "PCI\VEN_8086&DEV_3102",

    # === WLAN (WIFI KILLER AX1675i) ===
    "PCI\VEN_8086&DEV_272B",  # Intel WiFi 6E AX211/AX1675
    "PCI\VEN_8086&DEV_2725",
    "PCI\VEN_8086&DEV_2726",
    "PCI\VEN_8086&DEV_7E40",
    "PCI\VEN_8086&DEV_A0F0",
    "PCI\VEN_8086&DEV_51F0",
    "PCI\VEN_8086&DEV_51F1",
    "PCI\VEN_8086&DEV_54F0",

    # === BLUETOOTH ===
    "USB\VID_8087&PID_0033",  # Intel Bluetooth AX211/AX1675
    "USB\VID_8087&PID_0032",
    "USB\VID_8087&PID_0029",
    "USB\VID_8087&PID_0026",
    "USB\VID_8087&PID_0025"
)

# Driver INFs to block/remove
$BLOCKED_INFS = @(
    "gna.inf",
    "intcaudiobus.inf"  # Sometimes causes issues
)

# Drivers that cause BSOD (specific versions)
$BSOD_DRIVERS = @{
    "dtt" = @("11405", "11407", "117", "118", "119")  # All versions after 11404
    "ipf" = @("11405", "11407", "117", "118", "119")
}

# Log function
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $ts = Get-Date -Format "HH:mm:ss"
    $logMsg = "[$ts] $Message"
    Write-Host $logMsg -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $logMsg
}

# Create folders
if (!(Test-Path $DownloadPath)) { New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null }
if (!(Test-Path $TempPath)) { New-Item -ItemType Directory -Path $TempPath -Force | Out-Null }

# Header
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "           PHN16-72 BSOD FIX SCRIPT v7.6" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Based on Acer Community solutions (artkirius, jihakkim)" -ForegroundColor Gray
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "  WHERE TO DOWNLOAD DRIVERS:" -ForegroundColor Yellow
Write-Host "  $Acer_URL" -ForegroundColor White
Write-Host ""
Write-Host "  WHERE TO SAVE DRIVERS (ZIP files, not extracted!):" -ForegroundColor Yellow
Write-Host "  $DownloadPath" -ForegroundColor White
Write-Host ""
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Problematic drivers to handle:" -ForegroundColor White
Write-Host "  - Intel DPTF/DTT    : install Acer DPTF 11401, avoid 11405+/APO" -ForegroundColor White
Write-Host "  - Intel GNA         : various BSOD" -ForegroundColor White
Write-Host "  - Intel PPM         : keep enabled on updated BIOS" -ForegroundColor Gray
Write-Host "  - Intel Chipset     : corrupt drivers" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Log "Script started - Log: $LogFile"
Write-Host ""

# ============================================================================
# PHASE 1: FULL DIAGNOSTICS
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [1/7] DRIVER DIAGNOSTICS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$drivers = Get-WmiObject Win32_PnPSignedDriver 2>$null |
    Select-Object DeviceName, DriverVersion, InfName, Manufacturer, HardWareID

if (!$drivers) {
    Write-Log "ERROR: unable to read WMI drivers!" "Red"
    exit 1
}

# Driver status
$Issues = @()

# 1. DTT/DPTF - MULTI-METHOD DETECTION
# NOTE: The Acer DPTF package often does NOT appear in Device Manager!
# We must search: ESIF service, installation folder, programs, registry

$dptfFound = $false
$dptfVersion = ""
$dptfSource = ""

# Method 1: ESIF Service (most reliable)
$esifSvc = Get-Service "esifsvc*" 2>$null
if ($esifSvc) {
    $dptfFound = $true
    $dptfSource = "service $($esifSvc.Name)"
}

# Method 2: Intel DTT installation folder
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
            $dptfSource = "folder: $path"
        }
        break
    }
}

# Method 3: Installed programs (Add/Remove Programs)
$installedDptf = Get-Package "*Dynamic Tuning*","*DPTF*","*Thermal Framework*" 2>$null | Select-Object -First 1
if ($installedDptf) {
    $dptfFound = $true
    $dptfVersion = $installedDptf.Version
    $dptfSource = "program: $($installedDptf.Name)"
}

# Method 4: System registry
$regPaths = @(
    "HKLM:\SOFTWARE\Intel\DPTF",
    "HKLM:\SOFTWARE\Intel\DTT"
)
foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        $dptfFound = $true
        $regVer = (Get-ItemProperty $regPath -Name "Version" -EA 0).Version
        if ($regVer -and !$dptfVersion) { $dptfVersion = $regVer }
        if (!$dptfSource) { $dptfSource = "registry: $regPath" }
    }
}

# Method 5: Device Manager (fallback)
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
    if (!$dptfSource) { $dptfSource = "device manager" }
}

# Evaluate result
if ($dptfFound) {
    if ($dptfVersion) {
        $isBad = $BSOD_DRIVERS["dtt"] | Where-Object { $dptfVersion -match $_ }
        if ($isBad) {
            Write-Log "  [X] DTT/DPTF: $dptfVersion [CAUSES BSOD!] ($dptfSource)" "Red"
            $Issues += "DTT_BAD"
        } elseif ($dptfVersion -match "11404|11401|11400|11399") {
            Write-Log "  [OK] DTT/DPTF: $dptfVersion [stable] ($dptfSource)" "Green"
        } else {
            Write-Log "  [?] DTT/DPTF: $dptfVersion ($dptfSource)" "Yellow"
        }
    } else {
        Write-Log "  [OK] DTT/DPTF: Installed ($dptfSource)" "Green"
    }
} else {
    Write-Log "  [-] DTT/DPTF: Not installed" "Yellow"
    $Issues += "DTT_MISSING"
}

# 2. IPF
$ipf = $drivers | Where-Object {
    $_.DeviceName -like "*Innovation Platform*" -or
    $_.InfName -like "*ipf*"
} | Select-Object -First 1

if ($ipf) {
    $ver = $ipf.DriverVersion
    $isBad = $BSOD_DRIVERS["ipf"] | Where-Object { $ver -match $_ }
    if ($isBad) {
        Write-Log "  [X] IPF: $ver [problematic version]" "Red"
        $Issues += "IPF_BAD"
    } elseif ($ver -match $IPF_STABLE) {
        Write-Log "  [OK] IPF: $ver [stable]" "Green"
    } else {
        Write-Log "  [?] IPF: $ver [unknown version]" "Yellow"
    }
} else {
    Write-Log "  [-] IPF: Not installed" "Yellow"
}

# 3. GNA
$gna = $drivers | Where-Object {
    $_.DeviceName -like "*GNA*" -or
    $_.DeviceName -like "*Gaussian*" -or
    $_.InfName -like "*gna*"
}
if ($gna) {
    Write-Log "  [X] GNA: PRESENT [causes BSOD - must be removed]" "Red"
    $Issues += "GNA"
} else {
    Write-Log "  [OK] GNA: Not present" "Green"
}

# 4. HID Event Filter (needed for touchpad/Fn keys)
$hid = $drivers | Where-Object {
    $_.DeviceName -like "*HID Event Filter*" -or
    $_.HardWareID -like "*INTC1070*"
}
if ($hid) {
    Write-Log "  [OK] HID Event Filter: $($hid.DriverVersion) [for touchpad/Fn keys]" "Green"
} else {
    Write-Log "  [-] HID Event Filter: Not present (may be needed for touchpad)" "Yellow"
}

# 5. Intel PPM (intelppm)
$intelppmKey = "HKLM:\SYSTEM\CurrentControlSet\Services\intelppm"
$intelppmStart = (Get-ItemProperty $intelppmKey -Name Start -EA 0).Start
$intelppmStatus = "UNKNOWN"

if ($intelppmStart -eq 4) {
    Write-Log "  [!] Intel PPM: DISABLED (Start=4) - legacy workaround, usually not needed now" "Yellow"
    $intelppmStatus = "DISABLED"
} elseif ($intelppmStart -eq 3 -or $intelppmStart -eq 1) {
    Write-Log "  [OK] Intel PPM: ACTIVE (Start=$intelppmStart) [expected on updated BIOS]" "Green"
    $intelppmStatus = "ENABLED"
} else {
    Write-Log "  [?] Intel PPM: Start=$intelppmStart [unknown state]" "Yellow"
    $intelppmStatus = "UNKNOWN"
}

# 6. Killer SOFTWARE (not the WiFi driver!)
# NOTE: Intel Killer AX1675i is the standard WiFi chip of the PHN16-72
# The DRIVER is needed, the BLOATWARE is the Killer Control Center software
# Search ONLY for the software, NOT the drivers
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
        Write-Log "  [!] Killer SOFTWARE: $swNames [optional bloatware]" "Yellow"
    } else {
        Write-Log "  [!] Killer SOFTWARE: Services running [optional bloatware]" "Yellow"
    }
    $Issues += "KILLER_SW"
} else {
    Write-Log "  [OK] Killer SOFTWARE: Not present (WiFi driver OK)" "Green"
}

Write-Host ""
if ($Issues.Count -eq 0) {
    Write-Log "  RESULT: System OK - no issues found" "Green"
} else {
    Write-Log "  RESULT: Found $($Issues.Count) issues: $($Issues -join ', ')" "Red"
}
Write-Host ""

# ============================================================================
# PHASE 2: INTELPPM FIX (jihakkim)
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [2/7] INTEL PPM" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Disabling Intel PPM is NOT necessary on updated Acer BIOS." -ForegroundColor Green
Write-Host "  This script leaves Intel PPM enabled unless you use the legacy" -ForegroundColor Green
Write-Host "  -DisableIntelppm switch for old BIOS troubleshooting only." -ForegroundColor Gray
Write-Host "  PredatorGuard is a separate optional tool for locking MSR writes." -ForegroundColor Gray
Write-Host ""

if (!$DisableIntelppm) {
    Write-Log "  [OK] Intel PPM: no changes needed" "Green"
} elseif ($intelppmStatus -eq "DISABLED") {
    Write-Log "  Already applied - no action needed" "Green"
} elseif ($DryRun) {
    Write-Log "  [DryRun] Would set: HKLM\...\intelppm\Start = 4" "Yellow"
} else {
    # Backup original value
    $backupFile = "$env:USERPROFILE\Desktop\intelppm_backup.reg"
    reg export "HKLM\SYSTEM\CurrentControlSet\Services\intelppm" $backupFile /y 2>$null
    Write-Log "  Backup created: $backupFile" "Gray"

    # Apply fix
    try {
        Set-ItemProperty -Path $intelppmKey -Name "Start" -Value 4 -Type DWord -Force
        $verify = (Get-ItemProperty $intelppmKey -Name Start).Start
        if ($verify -eq 4) {
            Write-Log "  [OK] Intel PPM disabled (Start=4)" "Green"
            Write-Log "  REBOOT REQUIRED to apply" "Yellow"
        } else {
            Write-Log "  [X] Verification failed - Start=$verify" "Red"
        }
    } catch {
        Write-Log "  [X] Error: $_" "Red"
    }
}
Write-Host ""

# ============================================================================
# PHASE 3: REMOVAL OF PROBLEMATIC DRIVERS
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [3/7] REMOVAL OF PROBLEMATIC DRIVERS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$removedCount = 0

# GNA - Disable and remove
if ($Issues -contains "GNA") {
    Write-Log "  Removing Intel GNA..." "Yellow"

    if (!$DryRun) {
        # Disable device
        $gnaDevices = Get-PnpDevice -FriendlyName "*GNA*","*Gaussian*" 2>$null
        foreach ($dev in $gnaDevices) {
            try {
                Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false 2>$null
                Write-Log "    Disabled: $($dev.FriendlyName)" "Green"
            } catch { }
        }

        # Remove driver
        $oems = pnputil /enum-drivers 2>$null
        $currentOem = ""
        foreach ($line in $oems) {
            if ($line -match "(oem\d+\.inf)") { $currentOem = $matches[1] }
            if ($line -match "gna" -and $currentOem) {
                pnputil /delete-driver $currentOem /uninstall /force 2>$null
                Write-Log "    Removed: $currentOem" "Green"
                $removedCount++
                $currentOem = ""
            }
        }
    }
}

# Killer SOFTWARE (NOT the WiFi drivers!)
if ($Issues -contains "KILLER_SW") {
    Write-Log "  Removing Killer SOFTWARE (WiFi driver stays)..." "Yellow"

    if (!$DryRun) {
        # Stop Killer services
        $killerSvcs = Get-Service "*Killer*" 2>$null
        foreach ($svc in $killerSvcs) {
            Stop-Service $svc.Name -Force 2>$null
            Set-Service $svc.Name -StartupType Disabled 2>$null
            Write-Log "    Service disabled: $($svc.Name)" "Green"
        }

        # Remove Killer software (Control Center, Intelligence Center, etc)
        $killerApps = Get-Package "*Killer*" 2>$null | Where-Object { $_.Name -notlike "*Driver*" -and $_.Name -notlike "*WiFi*" }
        foreach ($app in $killerApps) {
            try {
                $app | Uninstall-Package -Force 2>$null
                Write-Log "    Removed: $($app.Name)" "Green"
                $removedCount++
            } catch { }
        }

        # DO NOT remove Killer WiFi drivers - they are needed!
        Write-Log "    NOTE: Intel Killer WiFi driver kept (required)" "Cyan"
    }
}

# Problematic DTT - remove if wrong version
if ($Issues -contains "DTT_BAD") {
    Write-Log "  Removing problematic DTT..." "Yellow"

    if (!$DryRun) {
        # Stop ESIF service
        Stop-Service "esifsvc*" -Force 2>$null

        # Remove DTT driver
        $oems = pnputil /enum-drivers 2>$null
        $currentOem = ""
        foreach ($line in $oems) {
            if ($line -match "(oem\d+\.inf)") { $currentOem = $matches[1] }
            if (($line -match "dtt|dptf|Dynamic Tuning") -and $currentOem) {
                pnputil /delete-driver $currentOem /uninstall /force 2>$null
                Write-Log "    Removed: $currentOem" "Green"
                $removedCount++
                $currentOem = ""
            }
        }
    }
}

Write-Log "  Removed $removedCount drivers" "Cyan"
Write-Host ""

# ============================================================================
# PHASE 4: BLOCK WINDOWS UPDATE FOR ALL DRIVERS
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [4/7] BLOCK WINDOWS UPDATE FOR INSTALLED DRIVERS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Prevents Windows from overwriting the drivers we install" -ForegroundColor Gray
Write-Host ""

if (!$DryRun) {
    # 1. Disable drivers via Windows Update
    $wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (!(Test-Path $wuKey)) { New-Item -Path $wuKey -Force | Out-Null }
    Set-ItemProperty -Path $wuKey -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord
    Write-Log "  [OK] ExcludeWUDriversInQualityUpdate = 1" "Green"

    # 2. Disable online driver search
    $dsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
    Set-ItemProperty -Path $dsKey -Name "SearchOrderConfig" -Value 0 -Type DWord
    Write-Log "  [OK] SearchOrderConfig = 0" "Green"

    # 3. Block specific Hardware IDs
    $restrictKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions"
    $denyKey = "$restrictKey\DenyDeviceIDs"

    if (!(Test-Path $restrictKey)) { New-Item -Path $restrictKey -Force | Out-Null }
    if (!(Test-Path $denyKey)) { New-Item -Path $denyKey -Force | Out-Null }

    Set-ItemProperty -Path $restrictKey -Name "DenyDeviceIDs" -Value 1 -Type DWord
    Set-ItemProperty -Path $restrictKey -Name "DenyDeviceIDsRetroactive" -Value 1 -Type DWord

    $i = 1
    foreach ($hwid in $BLOCKED_HWIDS) {
        Set-ItemProperty -Path $denyKey -Name "$i" -Value $hwid -Type String
        $i++
    }

    Write-Log "  Blocked $($BLOCKED_HWIDS.Count) Hardware IDs:" "Cyan"
    Write-Log "    - GNA, HID Filter (problematic)" "Gray"
    Write-Log "    - DTT/DPTF" "Gray"
    Write-Log "    - Chipset / Serial IO" "Gray"
    Write-Log "    - ME (Management Engine)" "Gray"
    Write-Log "    - VGA Intel UHD" "Gray"
    Write-Log "    - Audio Realtek" "Gray"
    Write-Log "    - LAN Ethernet" "Gray"
    Write-Log "    - WLAN WiFi" "Gray"
    Write-Log "    - Bluetooth" "Gray"
    Write-Log "  Windows Update will not be able to overwrite these drivers" "Green"
}
Write-Host ""

# ============================================================================
# PHASE 5: DOWNLOAD GUIDE
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [5/7] DOWNLOAD STABLE DRIVERS" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if ($SkipDownload) {
    Write-Log "  Skipped (-SkipDownload)" "Yellow"
} else {
    # Generate HTML guide
    $html = @"
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>PHN16-72 Driver Guide v7.6</title>
<style>
body{font-family:Segoe UI,sans-serif;max-width:900px;margin:40px auto;padding:20px;background:#1a1a2e;color:#eee}
h1{color:#00d4ff;border-bottom:2px solid #00d4ff;padding-bottom:10px}
h2{color:#fff;margin-top:30px}
.critical{background:#ff4444;color:#fff;padding:20px;border-radius:8px;margin:20px 0}
.warning{background:#ff8800;color:#000;padding:20px;border-radius:8px;margin:20px 0}
.success{background:#00aa44;color:#fff;padding:20px;border-radius:8px;margin:20px 0}
.box{background:#2a2a4e;padding:20px;border-radius:8px;margin:20px 0;border-left:4px solid #00d4ff}
ul{line-height:2}
code{background:#333;padding:3px 8px;border-radius:4px;color:#00ff88}
a{color:#00d4ff}
.step{background:#00d4ff;color:#000;padding:5px 12px;border-radius:50%;margin-right:10px;font-weight:bold}
table{width:100%;border-collapse:collapse;margin:20px 0}
th,td{padding:12px;text-align:left;border-bottom:1px solid #444}
th{background:#333}
.bad{color:#ff4444}
.good{color:#00ff88}
</style></head><body>
<h1>PHN16-72 Driver Guide v7.6</h1>

<div class="critical">
<h2>DRIVERS THAT CAUSE BSOD</h2>
<table>
<tr><th>Driver</th><th>File</th><th>BSOD Error</th><th>Action</th></tr>
<tr><td class="bad">Intel DPTF/DTT 11405+</td><td>dtt_sw.inf</td><td>Thermal crashes</td><td>Replace with Acer DPTF 11401</td></tr>
<tr><td class="bad">Intel DPTF (APO)</td><td>-</td><td>Requires DTT 11405+</td><td>DO NOT install!</td></tr>
<tr><td class="bad">Intel GNA</td><td>gna.inf</td><td>Various BSOD</td><td>Block</td></tr>
<tr><td class="good">Intel PPM</td><td>intelppm.sys</td><td>Legacy CLOCK_WATCHDOG workaround</td><td>Keep enabled on updated BIOS</td></tr>
</table>
</div>

<div class="success">
<h2>STABLE VERSIONS (pre-BSOD)</h2>
<ul>
<li><b>DPTF (WITHOUT APO):</b> v1.0.11401 or earlier - from the Acer site</li>
<li><b>DTT:</b> 9.0.11404.39881 or earlier</li>
<li><b>IPF:</b> 1.0.11404.41023 or earlier</li>
</ul>
<p style="color:#ff8800"><b>WARNING:</b> DO NOT install "DPTF (APO)" - it requires DTT 11405+ which causes BSOD!</p>
</div>

<div class="box">
<h2><span class="step">1</span> Drivers from Acer (RECOMMENDED)</h2>
<p><a href="$Acer_URL" target="_blank">Open Acer PHN16-72 support page</a></p>
<p><b>DOWNLOAD THESE (in order of priority):</b></p>
<ol>
<li><b>Intel Chipset</b> - Serial IO, I2C, base for touchpad</li>
<li><b>ME</b> - Intel Management Engine</li>
<li><b>DPTF (WITHOUT APO)</b> - look for version 1.0.11401, NOT the one with "(APO)"!</li>
<li><b>VGA Intel UMA</b> - Integrated graphics (IMPORTANT: choose UMA, not non-UMA!)</li>
<li><b>Realtek Audio</b></li>
<li><b>LAN E3100G</b> - <span style="color:#ff8800">WITHOUT Killer Control Centre!</span></li>
<li><b>Wireless LAN</b> - <span style="color:#ff8800">WITHOUT 1675i!</span></li>
<li><b>Bluetooth</b> - If not working</li>
<li><b>HID Event Filter</b> - For touchpad and Fn keys</li>
</ol>
<p style="margin-top:10px;color:#ff4444"><b>WARNING:</b> For LAN and WLAN choose the versions WITHOUT additional software!</p>
</div>

<div class="warning">
<h2>NEVER DOWNLOAD</h2>
<ul>
<li><b>GNA</b> - Intel Gaussian Neural Accelerator (causes BSOD)</li>
<li><b>DTT/DPTF versions 11405+</b> - Cause BSOD</li>
</ul>
<p style="margin-top:15px"><b>WiFi NOTE:</b> The Intel Killer AX1675i driver is REQUIRED (it's the laptop's WiFi chip).
The bloatware to avoid is the Killer Control Center SOFTWARE, not the driver.</p>
</div>

<div class="box">
<h2><span class="step">2</span> Installation Order (IMPORTANT!)</h2>
<p>The script installs automatically in the correct order and guides you for Intel VGA and NVIDIA:</p>
<ol>
<li><b>Intel Chipset</b> - FIRST! Base for all other drivers</li>
<li><b>ME</b> - Intel Management Engine</li>
<li><b>DPTF</b> - Thermal Framework (version WITHOUT APO!)</li>
<li><b style="color:#00d4ff">Intel VGA UMA</b> - The script will guide you for manual installation via Device Manager</li>
<li><b style="color:#76b900">NVIDIA</b> - Install manually (GeForce Experience or nvidia.com)</li>
<li><b>Realtek Audio</b></li>
<li><b>LAN</b> - Ethernet</li>
<li><b>Wireless LAN</b> - WiFi</li>
<li><b>Bluetooth</b></li>
</ol>
<p style="color:#ff8800"><b>REBOOT after each critical driver (Chipset, ME, DPTF, GPU)</b></p>
<p style="color:#00ff88"><b>Windows Update is blocked for all these drivers!</b></p>
</div>

<div class="warning">
<h3>INTEL VGA - MANUAL INSTALLATION</h3>
<p>The automatic Intel VGA installer has a bug (Parade MUX) on these laptops.</p>
<p>The script will guide you to install manually via Device Manager:</p>
<ol>
<li>Extract the Intel VGA driver ZIP file</li>
<li>Open Device Manager (Win+X -> Device Manager)</li>
<li>Expand "Display adapters"</li>
<li>Right-click on "Intel UHD Graphics" -> "Update driver"</li>
<li>"Browse my computer for drivers"</li>
<li>Select the extracted folder -> Next</li>
</ol>
<p style="color:#ff4444"><b>If the screen goes black:</b> Reboot in Safe Mode and retry</p>
</div>

<div class="box">
<h2><span class="step">3</span> Final Verification</h2>
<p>After rebooting, run:</p>
<pre><code>.\HeliosPHN16-72_Check.ps1</code></pre>
<p>Check that:</p>
<ul>
<li>DTT is version 11404 or 11401</li>
<li>GNA is absent/blocked</li>
<li>Intel PPM is active (expected on updated BIOS)</li>
</ul>
</div>

<div class="box">
<h2>Sources (Acer Community)</h2>
<ul>
<li><a href="https://community.acer.com/en/discussion/723737">artkirius - SOLVED CLOCK_WATCHDOG</a></li>
<li><a href="https://community.acer.com/en/discussion/728746">jihakkim - Fix intelppm</a></li>
<li><a href="https://community.acer.com/en/discussion/728578">Puraw - Clean install guide</a></li>
</ul>
</div>

<p style="margin-top:40px;color:#888;text-align:center">
Generated: $(Get-Date -Format "dd/MM/yyyy HH:mm") | PHN16-72 Setup v7.6
</p>
</body></html>
"@
    $html | Out-File "$DownloadPath\GUIDA_DRIVER.html" -Encoding UTF8

    # Open browser
    Start-Process $Acer_URL
    Start-Process "$DownloadPath\GUIDA_DRIVER.html"

    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host "  DOWNLOAD THESE DRIVERS FROM THE ACER SITE:" -ForegroundColor Yellow
    Write-Host "  (The script will install them in the correct order)" -ForegroundColor Gray
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  1. [OK] Intel Chipset (Serial IO, I2C)" -ForegroundColor Green
    Write-Host "  2. [OK] ME - Intel Management Engine" -ForegroundColor Green
    Write-Host "  3. [OK] DPTF (WITHOUT APO!) - version 11401" -ForegroundColor Green
    Write-Host "  4. [>>] Intel VGA UMA - THE SCRIPT WILL GUIDE YOU" -ForegroundColor Cyan
    Write-Host "  5. [>>] NVIDIA - THE SCRIPT WILL ASK YOU TO INSTALL IT" -ForegroundColor Cyan
    Write-Host "  6. [OK] Realtek Audio" -ForegroundColor Green
    Write-Host "  7. [OK] LAN E3100G (WITHOUT Killer Control Centre!)" -ForegroundColor Green
    Write-Host "  8. [OK] Wireless LAN (WITHOUT 1675i!)" -ForegroundColor Green
    Write-Host "  9. [OK] Bluetooth (if needed)" -ForegroundColor Green
    Write-Host " 10. [OK] HID Event Filter (for touchpad/Fn keys)" -ForegroundColor Green
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  [X] DO NOT download: GNA" -ForegroundColor Red
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  SAVE THE ZIP FILES (without extracting!) TO:" -ForegroundColor White
    Write-Host "  $DownloadPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host ""

    # Create folder if it doesn't exist
    if (!(Test-Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
        Write-Host "  Folder created: $DownloadPath" -ForegroundColor Green
    }

    Read-Host "  Press ENTER when you have downloaded all drivers"
}
Write-Host ""

# ============================================================================
# PHASE 6: DRIVER INSTALLATION (CORRECT ORDER + CLEANUP)
# ============================================================================
# Recommended order from Acer community (Puraw):
# 1. Chipset  2. ME  3. DPTF  4. GPU (Intel + NVIDIA)  5. Audio  6. WiFi  7. Bluetooth

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [6/7] DRIVER INSTALLATION" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installation order: Chipset > ME > DPTF > GPU > Audio > WiFi > BT" -ForegroundColor Gray
Write-Host ""

# Installation priority map (lower number = first)
# NOTE: Intel VGA and NVIDIA are MANUAL, not in this list
$InstallOrder = @{
    "chipset"   = 1
    "chip"      = 1
    "serialio"  = 1
    "serial"    = 1
    "io.driver" = 1      # Acer file name: "IO Drivers_Intel" (. = any char)
    "me"        = 2
    "management"= 2
    "mgmtengine"= 2      # Acer file name: "MgmtEngine_Intel"
    "mgmt.*engine" = 2
    "dptf"      = 3
    "dtt"       = 3
    "thermal"   = 3
    # Intel VGA = MANUAL (Parade MUX bug)
    # NVIDIA = MANUAL
    "audio"     = 4
    "realtek"   = 4
    "sound"     = 4
    "lan"       = 5
    "ethernet"  = 5
    "e3100"     = 5      # Killer E3100 LAN
    "wlan"      = 6
    "wifi"      = 6
    "wireless"  = 6
    "killer"    = 6
    "bluetooth" = 7
    "bt_"       = 7      # bt_ to avoid accidental matches
    "hid"       = 8      # HID Event Filter for touchpad/Fn keys
    "intc1070"  = 8
}

# Drivers to remove before installation (cleanup)
$DriversToClean = @{
    "dptf|dtt|thermal|esif" = "DTT/DPTF"
    "gna|gaussian"          = "GNA"
}

if ($SkipInstall) {
    Write-Log "  Skipped (-SkipInstall)" "Yellow"
} else {
    $zips = Get-ChildItem "$DownloadPath\*.zip" 2>$null

    if (!$zips -or $zips.Count -eq 0) {
        Write-Log "  No ZIP files found in $DownloadPath" "Yellow"
        Write-Log "  Download drivers from the Acer site and save them to:" "Yellow"
        Write-Log "  $DownloadPath" "White"
    } else {
        Write-Log "  Found $($zips.Count) packages" "Cyan"

        # Filter and block drivers that should not be installed automatically
        $validZips = @()
        $vgaIntelZip = $null

        foreach ($z in $zips) {
            $name = $z.Name.ToLower()
            if ($name -match "gna|gaussian") {
                Write-Log "  [X] BLOCKED: $($z.Name) [GNA - causes BSOD]" "Red"
                continue
            }
            if ($name -match "nvidia|geforce|rtx|gtx") {
                Write-Log "  [i] SKIP: $($z.Name) [NVIDIA - install manually]" "Cyan"
                continue
            }
            # Intel VGA has issues with silent installer (Parade MUX bug)
            # Acer recommends manual installation via Device Manager
            if ($name -match "vga.*intel|intel.*vga") {
                Write-Log "  [i] SKIP: $($z.Name) [Intel VGA - install manually]" "Cyan"
                $vgaIntelZip = $z
                continue
            }
            # HID Event Filter - needed for touchpad, but can cause freeze
            # We install it but with a warning
            if ($name -match "hid.*event|hid.*filter") {
                Write-Log "  [!] WARNING: $($z.Name) [HID Event Filter - needed for touchpad]" "Yellow"
                # Don't block, let it install
            }
            $validZips += $z
        }

        # Sort by priority
        $sortedZips = $validZips | Sort-Object {
            $name = $_.Name.ToLower()
            $priority = 99
            foreach ($key in $InstallOrder.Keys) {
                if ($name -match $key) {
                    $priority = [Math]::Min($priority, $InstallOrder[$key])
                }
            }
            $priority
        }

        Write-Host ""
        Write-Log "  Installation order:" "Cyan"
        $i = 1
        foreach ($z in $sortedZips) {
            Write-Log "    $i. $($z.Name)" "White"
            $i++
        }
        Write-Host ""

        # PHASE 6a: FULL CLEANUP OF EXISTING DRIVERS
        Write-Log "  --- Cleaning up existing drivers ---" "Yellow"
        Write-Log "  (Required to force Windows to use the new drivers)" "Gray"

        if (!$DryRun) {
            # Patterns to identify drivers to clean based on downloaded packages
            $cleanPatterns = @()

            foreach ($z in $sortedZips) {
                $name = $z.Name.ToLower()

                # Add cleanup patterns based on package type
                if ($name -match "chipset|serial|io.driver") {
                    $cleanPatterns += "ialpss|serialio|i2c|gpio|spi|uart"
                }
                if ($name -match "me|management|mgmtengine|mgmt") {
                    $cleanPatterns += "heci|mei_"
                }
                if ($name -match "dptf|dtt|thermal") {
                    $cleanPatterns += "dptf|dtt|esif|thermal"
                }
                if ($name -match "vga|graphics|uhd|intel.*graph") {
                    $cleanPatterns += "igfx|iigd|IntcDAud|cui_|icls"
                }
                if ($name -match "audio|realtek|sound") {
                    $cleanPatterns += "realtek|hdaudio|IntcAudioBus"
                }
                if ($name -match "ethernet|e3100") {
                    $cleanPatterns += "e1d|e1r|e1c|igc|killer.*eth"
                }
                if ($name -match "wlan|wifi|wireless") {
                    $cleanPatterns += "netwtw|killer.*wi|iwl"
                }
                if ($name -match "bluetooth") {
                    $cleanPatterns += "ibtusb|IntelBluetooth"
                }
            }

            # Always clean GNA (problematic)
            $cleanPatterns += "gna|gaussian"

            # Remove duplicates
            $cleanPatterns = $cleanPatterns | Select-Object -Unique
            $cleanRegex = ($cleanPatterns -join "|")

            Write-Log "  Searching for drivers to remove..." "Gray"

            # Enumerate all drivers
            $existingDrivers = pnputil /enum-drivers 2>$null
            $currentOem = ""
            $currentOriginal = ""
            $cleanedCount = 0
            $driversToRemove = @()

            foreach ($line in $existingDrivers) {
                if ($line -match "Nome pubblicato:\s+(oem\d+\.inf)") {
                    $currentOem = $matches[1]
                }
                if ($line -match "Nome originale:\s+(.+\.inf)") {
                    $currentOriginal = $matches[1].Trim()
                }
                if ($line -match "Published Name:\s+(oem\d+\.inf)") {
                    $currentOem = $matches[1]
                }
                if ($line -match "Original Name:\s+(.+\.inf)") {
                    $currentOriginal = $matches[1].Trim()
                }

                # If we have both, check if it matches the patterns
                if ($currentOem -and $currentOriginal) {
                    if ($currentOriginal -match $cleanRegex) {
                        $driversToRemove += @{
                            Oem = $currentOem
                            Original = $currentOriginal
                        }
                    }
                    $currentOem = ""
                    $currentOriginal = ""
                }
            }

            if ($driversToRemove.Count -gt 0) {
                Write-Log "  Found $($driversToRemove.Count) drivers to remove:" "Yellow"

                foreach ($drv in $driversToRemove) {
                    Write-Log "    Removing: $($drv.Oem) ($($drv.Original))" "Gray"
                    $result = pnputil /delete-driver $drv.Oem /uninstall 2>&1 | Out-String
                    if ($result -match "eliminato|deleted|Driver package deleted") {
                        $cleanedCount++
                    } elseif ($result -match "in uso|in use") {
                        Write-Log "      [!] In use - will be replaced after reboot" "Yellow"
                    }
                }

                Write-Log "  Removed $cleanedCount drivers" "Green"

                if ($cleanedCount -lt $driversToRemove.Count) {
                    Write-Log "  [!] Some drivers are in use - reboot after installation" "Yellow"
                }
            } else {
                Write-Log "  No existing drivers to clean up" "Gray"
            }
        }

        Write-Host ""
        Write-Log "  --- Installing new drivers ---" "Yellow"

        # Flag for GPU prompt
        $gpuPromptShown = $false
        $dptfInstalled = $false

        # PHASE 6b: ORDERED INSTALLATION
        foreach ($z in $sortedZips) {
            $name = $z.Name.ToLower()

            # After DPTF, ask to install Intel VGA + NVIDIA manually
            if ($dptfInstalled -and !$gpuPromptShown) {
                $isDptf = $name -match "dptf|dtt|thermal"
                if (!$isDptf) {
                    $gpuPromptShown = $true

                    # === INTEL VGA PROMPT ===
                    if ($vgaIntelZip) {
                        Write-Host ""
                        Write-Host "  ============================================================" -ForegroundColor Cyan
                        Write-Host "  >>> INSTALL THE INTEL VGA DRIVER NOW <<<" -ForegroundColor Cyan
                        Write-Host "  ============================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  The Intel VGA driver requires manual installation" -ForegroundColor White
                        Write-Host "  (the automatic installer has a Parade MUX bug)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "  PROCEDURE:" -ForegroundColor Yellow
                        Write-Host "  1. Open: $($vgaIntelZip.FullName)" -ForegroundColor White
                        Write-Host "  2. Extract the contents to a folder" -ForegroundColor White
                        Write-Host "  3. Open Device Manager (Win+X -> Device Manager)" -ForegroundColor White
                        Write-Host "  4. Expand 'Display adapters'" -ForegroundColor White
                        Write-Host "  5. Right-click on 'Intel UHD Graphics' -> 'Update driver'" -ForegroundColor White
                        Write-Host "  6. 'Browse my computer for drivers'" -ForegroundColor White
                        Write-Host "  7. Select the extracted folder -> Next" -ForegroundColor White
                        Write-Host ""
                        Write-Host "  NOTE: If the screen goes black, reboot in Safe Mode" -ForegroundColor Red
                        Write-Host "  ============================================================" -ForegroundColor Cyan
                        Write-Host ""

                        if (!$DryRun) {
                            $response = Read-Host "  Press ENTER after installing Intel VGA (or 'S' to skip)"
                            if ($response -ne 'S' -and $response -ne 's') {
                                Write-Log "  Intel VGA installed by user" "Green"
                            } else {
                                Write-Log "  Intel VGA skipped - install after reboot" "Yellow"
                            }
                        }
                    }

                    # === NVIDIA PROMPT ===
                    Write-Host ""
                    Write-Host "  ============================================================" -ForegroundColor Green
                    Write-Host "  >>> INSTALL NVIDIA DRIVERS NOW <<<" -ForegroundColor Green
                    Write-Host "  ============================================================" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  OPTION 1: GeForce Experience (recommended)" -ForegroundColor Cyan
                    Write-Host "    - Download from: https://www.nvidia.com/geforce-experience/" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "  OPTION 2: Manual drivers" -ForegroundColor Cyan
                    Write-Host "    - Download from: https://www.nvidia.com/drivers/" -ForegroundColor Gray
                    Write-Host "    - Select RTX 4060/4070/4080 Laptop GPU" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "  ============================================================" -ForegroundColor Green
                    Write-Host ""

                    if (!$DryRun) {
                        $response = Read-Host "  Press ENTER after installing NVIDIA (or 'S' to skip)"
                        if ($response -ne 'S' -and $response -ne 's') {
                            Write-Log "  NVIDIA installed by user" "Green"
                        } else {
                            Write-Log "  NVIDIA skipped - install after reboot" "Yellow"
                        }
                    }
                    Write-Host ""
                }
            }

            Write-Log "  Processing: $($z.Name)" "White"
            $dest = "$TempPath\$($z.BaseName)"

            if (!$DryRun) {
                # Extract
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force 2>$null }
                New-Item -ItemType Directory -Path $dest -Force | Out-Null

                try {
                    Expand-Archive -Path $z.FullName -DestinationPath $dest -Force
                } catch {
                    Write-Log "    [X] Extraction error" "Red"
                    continue
                }

                # Look for Install.cmd (standard Acer packages)
                $installCmd = Get-ChildItem "$dest" -Filter "Install.cmd" -Recurse 2>$null | Select-Object -First 1

                # Look for setup.exe
                $setup = Get-ChildItem "$dest" -Filter "*.exe" -Recurse 2>$null |
                         Where-Object { $_.Name -match "^(setup|install|Setup|Install)" } |
                         Select-Object -First 1

                # Look for AsusSetup or similar (sometimes used by Acer)
                if (!$setup) {
                    $setup = Get-ChildItem "$dest" -Filter "*Setup*.exe" -Recurse 2>$null |
                             Select-Object -First 1
                }

                $installed = $false

                # Method 1: Install.cmd (preferred for Acer packages)
                if ($installCmd -and !$installed) {
                    Write-Log "    Running: Install.cmd" "Cyan"
                    $workDir = $installCmd.DirectoryName
                    $proc = Start-Process "cmd.exe" -ArgumentList "/c `"$($installCmd.FullName)`"" -WorkingDirectory $workDir -Wait -PassThru -WindowStyle Hidden 2>$null
                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                        Write-Log "    [OK] Installed" "Green"
                        $installed = $true
                    } else {
                        Write-Log "    [!] Exit code: $($proc.ExitCode) - trying another method" "Yellow"
                    }
                }

                # Method 2: setup.exe with correct parameters by type
                if ($setup -and !$installed) {
                    Write-Log "    Running: $($setup.Name)" "Cyan"

                    # Intel Graphics Installer uses --silent
                    if ($setup.Name -match "Installer\.exe" -and ($name -match "vga|graphics|intel.*graph")) {
                        $proc = Start-Process $setup.FullName -ArgumentList "--silent" -Wait -PassThru 2>$null
                    }
                    # Intel SerialIO uses -s -overwrite
                    elseif ($setup.Name -match "SetupSerialIO") {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s","-overwrite" -Wait -PassThru 2>$null
                    }
                    # Intel ME uses -s -overwrite
                    elseif ($setup.Name -match "SetupME") {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s","-overwrite" -Wait -PassThru 2>$null
                    }
                    # Intel Chipset uses -s -overwrite
                    elseif ($setup.Name -match "SetupChipset") {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s","-overwrite" -Wait -PassThru 2>$null
                    }
                    # Realtek Audio uses -s
                    elseif ($setup.Name -match "setup\.exe" -and ($name -match "audio|realtek|sound")) {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s" -Wait -PassThru 2>$null
                    }
                    # Default: /quiet /norestart
                    else {
                        $proc = Start-Process $setup.FullName -ArgumentList "/quiet","/norestart" -Wait -PassThru 2>$null
                    }

                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                        Write-Log "    [OK] Installed" "Green"
                        $installed = $true
                    } elseif ($proc.ExitCode -eq 1603) {
                        Write-Log "    [!] Exit code: 1603 (driver in use) - forcing INF install" "Yellow"
                        # Don't mark as installed, will fall through to method 3
                    } else {
                        Write-Log "    [!] Exit code: $($proc.ExitCode)" "Yellow"
                    }
                }

                # Method 3: Install INF manually (with force)
                if (!$installed) {
                    $infs = Get-ChildItem "$dest" -Filter "*.inf" -Recurse 2>$null
                    $infCount = 0
                    foreach ($inf in $infs) {
                        # Skip GNA
                        if ($inf.Name -match "gna") { continue }

                        # Use /force to overwrite existing drivers
                        $result = pnputil /add-driver $inf.FullName /install /force 2>&1 | Out-String
                        if ($result -match "success|pubblicato|aggiunto|added|già presente|already exists") {
                            $infCount++
                        }
                    }
                    if ($infCount -gt 0) {
                        Write-Log "    [OK] Installed $infCount INFs" "Green"
                        $installed = $true
                    }
                }

                if (!$installed) {
                    Write-Log "    [!] No installer found - install manually" "Yellow"
                }

                # Mark if we installed DPTF driver (to show GPU prompt after)
                if ($installed -and ($name -match "dptf|dtt|thermal")) {
                    $dptfInstalled = $true
                }
            }
        }

        # If there was no DPTF but there's an Intel VGA to install, show the GPU prompt anyway
        if (!$gpuPromptShown -and $vgaIntelZip) {
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host "  >>> INSTALL THE INTEL VGA DRIVER NOW <<<" -ForegroundColor Cyan
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  The Intel VGA driver requires manual installation" -ForegroundColor White
            Write-Host "  (the automatic installer has a Parade MUX bug)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  PROCEDURE:" -ForegroundColor Yellow
            Write-Host "  1. Open: $($vgaIntelZip.FullName)" -ForegroundColor White
            Write-Host "  2. Extract the contents to a folder" -ForegroundColor White
            Write-Host "  3. Open Device Manager (Win+X -> Device Manager)" -ForegroundColor White
            Write-Host "  4. Expand 'Display adapters'" -ForegroundColor White
            Write-Host "  5. Right-click on 'Intel UHD Graphics' -> 'Update driver'" -ForegroundColor White
            Write-Host "  6. 'Browse my computer for drivers'" -ForegroundColor White
            Write-Host "  7. Select the extracted folder -> Next" -ForegroundColor White
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host ""

            if (!$DryRun) {
                $response = Read-Host "  Press ENTER after installing Intel VGA (or 'S' to skip)"
                if ($response -ne 'S' -and $response -ne 's') {
                    Write-Log "  Intel VGA installed by user" "Green"
                } else {
                    Write-Log "  Intel VGA skipped" "Yellow"
                }
            }

            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Green
            Write-Host "  >>> INSTALL NVIDIA DRIVERS NOW <<<" -ForegroundColor Green
            Write-Host "  ============================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "  OPTION 1: GeForce Experience (recommended)" -ForegroundColor Cyan
            Write-Host "    - Download from: https://www.nvidia.com/geforce-experience/" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  OPTION 2: Manual drivers" -ForegroundColor Cyan
            Write-Host "    - Download from: https://www.nvidia.com/drivers/" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Green
            Write-Host ""

            if (!$DryRun) {
                $response = Read-Host "  Press ENTER after installing NVIDIA (or 'S' to skip)"
                if ($response -ne 'S' -and $response -ne 's') {
                    Write-Log "  NVIDIA installed by user" "Green"
                } else {
                    Write-Log "  NVIDIA skipped" "Yellow"
                }
            }
        }

        Write-Host ""
        Write-Log "  Installation completed" "Green"

        # Force Windows to re-examine devices and use the new drivers
        Write-Log "  Updating hardware devices..." "Yellow"

        # Method 1: pnputil rescan
        $rescan = pnputil /scan-devices 2>&1 | Out-String
        if ($rescan -match "completata|completed") {
            Write-Log "  [OK] Device scan completed" "Green"
        }

        # Method 2: Restart critical devices to force loading new drivers
        Write-Log "  Some drivers require a REBOOT to be activated" "Yellow"
    }
}
Write-Host ""

# ============================================================================
# PHASE 7: FINALIZATION
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [7/7] FINALIZATION" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Generate rollback script
$rollbackScript = @'
#Requires -RunAsAdministrator
# PHN16-72 Rollback v7.6
# Restores original settings

Write-Host "PHN16-72 Rollback" -ForegroundColor Yellow
Write-Host ""

# Restore intelppm
$intelppmKey = "HKLM:\SYSTEM\CurrentControlSet\Services\intelppm"
Set-ItemProperty -Path $intelppmKey -Name "Start" -Value 3 -Type DWord -EA 0
Write-Host "Intel PPM: Start = 3 (restored)" -ForegroundColor Yellow

# Remove Windows Update blocks
Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" -EA 0
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" -Value 1 -EA 0
Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" -Recurse -EA 0
Write-Host "Windows Update blocks: removed" -ForegroundColor Yellow

Write-Host ""
Write-Host "WARNING: After rebooting, Windows Update may" -ForegroundColor Red
Write-Host "reinstall the problematic drivers!" -ForegroundColor Red
Write-Host ""
Write-Host "Reboot the PC to apply the changes" -ForegroundColor Cyan
'@

$rollbackPath = "$env:USERPROFILE\Desktop\PHN16-72_ROLLBACK.ps1"
$rollbackScript | Out-File $rollbackPath -Encoding ASCII
Write-Log "  Rollback script: $rollbackPath" "Green"

# Summary
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "                    SETUP COMPLETED" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  APPLIED FIXES:" -ForegroundColor White

if ($DisableIntelppm -and $intelppmStatus -ne "DISABLED" -and !$DryRun) {
    Write-Host "  [OK] Intel PPM disabled (CLOCK_WATCHDOG fix)" -ForegroundColor Green
}
if ($Issues -contains "GNA") {
    Write-Host "  [OK] GNA removed/blocked" -ForegroundColor Green
}
if ($Issues -contains "KILLER_SW") {
    Write-Host "  [OK] Killer SOFTWARE removed (WiFi driver kept)" -ForegroundColor Green
}
Write-Host "  [OK] Windows Update blocked for problematic drivers" -ForegroundColor Green
Write-Host "  [OK] Existing drivers removed and new ones installed" -ForegroundColor Green

Write-Host "------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. *** REBOOT THE PC *** (MANDATORY!)" -ForegroundColor Red
Write-Host "     New drivers will only be active after reboot" -ForegroundColor Gray
Write-Host "  2. Run: .\HeliosPHN16-72_Check.ps1" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  GENERATED FILES:" -ForegroundColor White
Write-Host "  - $LogFile" -ForegroundColor Gray
Write-Host "  - $rollbackPath" -ForegroundColor Gray
Write-Host "  - $DownloadPath\GUIDA_DRIVER.html" -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

Write-Log "Script completed"

#Requires -RunAsAdministrator
# ============================================================================
<<<<<<< HEAD
# PHN16-72 Setup v7.6
=======
# PHN16-72 Setup v7.5
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
# ============================================================================
# BASATO SU SOLUZIONI DOCUMENTATE DALLA COMMUNITY ACER:
# - https://community.acer.com/en/discussion/723737 (artkirius - SOLVED)
# - https://community.acer.com/en/discussion/728746 (jihakkim - intelppm fix)
# - https://community.acer.com/en/discussion/728578 (Puraw - clean install)
# - https://community.acer.com/en/discussion/726672 (StevenGen - setup)
#
# DRIVER PROBLEMATICI IDENTIFICATI:
# 1. Intel DPTF/DTT (dtt_sw.inf) - crash termici, conflitto PredatorSense
# 2. Intel GNA (gna.inf) - BSOD vari
# 3. Intel HID Event Filter (INTC1070) - freeze sistema
# 4. Intel Chipset (RaptorLakeSystem.inf) - driver corrotti
# 5. Intel PPM (intelppm.sys) - CLOCK_WATCHDOG_TIMEOUT
#
# FIX APPLICATI:
# - Disabilita intelppm (jihakkim: 2+ settimane senza BSOD)
# - Rimuove/blocca tutti i driver problematici
# - Blocca reinstallazione via Windows Update
# - Installa versioni stabili DTT/IPF
# - Rimuove Killer SOFTWARE (non il driver WiFi - e' necessario!)
#
# NOTA: Intel Killer AX1675i e' il chip WiFi standard del PHN16-72.
#       Intel ha acquisito Killer, quindi il driver "Killer" = driver Intel.
#       Il BLOATWARE e' il software Killer Control Center, non il driver.
#
# IMPORTANTE: Sul sito Acer ci sono DUE versioni di DPTF:
#   - DPTF (APO) = richiede DTT 11405+ = CAUSA BSOD! NON INSTALLARE!
#   - DPTF (senza APO) = DTT 11401 o precedente = STABILE, installare questa!
# ============================================================================

param(
    [switch]$SkipDownload,
    [switch]$SkipInstall,
    [switch]$DryRun,
    [switch]$SkipIntelppmFix  # Se vuoi saltare il fix intelppm
)

# Auto-rilancio come Amministratore se necessario
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  Rilancio come Amministratore..." -ForegroundColor Yellow
    
    # Ricostruisce gli argomenti
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($SkipDownload)    { $argList += "-SkipDownload" }
    if ($SkipInstall)     { $argList += "-SkipInstall" }
    if ($DryRun)          { $argList += "-DryRun" }
    if ($SkipIntelppmFix) { $argList += "-SkipIntelppmFix" }
    
    try {
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host ""
        Write-Host "  ============================================================" -ForegroundColor Red
        Write-Host "  ERRORE: Impossibile ottenere privilegi Amministratore!" -ForegroundColor Red
        Write-Host "  ============================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Come fare manualmente:" -ForegroundColor Yellow
        Write-Host "  1. Cerca 'PowerShell' nel menu Start" -ForegroundColor White
        Write-Host "  2. Click destro -> 'Esegui come amministratore'" -ForegroundColor White
        Write-Host "  3. Naviga alla cartella dello script e riesegui" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

$ErrorActionPreference = "SilentlyContinue"

# Percorsi
$DownloadPath = "$env:USERPROFILE\Downloads\AcerDrivers_PHN16-72"
$TempPath = "$env:TEMP\AcerDriverSetup"
$LogFile = "$env:USERPROFILE\Desktop\PHN16-72_Setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Versioni stabili (PRE-BSOD)
$DTT_STABLE = "9.0.11404"
$IPF_STABLE = "1.0.11404"

# URL
$Acer_URL = "https://www.acer.com/it-it/support/product-support/Predator_PHN16-72"

# Hardware IDs da bloccare (impedisce a Windows Update di sovrascrivere i driver)
# NOTA: Blocchiamo TUTTI i driver che installiamo manualmente per evitare aggiornamenti automatici

$BLOCKED_HWIDS = @(
    # === DRIVER PROBLEMATICI (SEMPRE BLOCCATI) ===
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
    "HDAUDIO\FUNC_01&VEN_10EC*",  # Pattern Realtek HD Audio
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
<<<<<<< HEAD
    "PCI\VEN_8086&DEV_54F0",
    
    # === BLUETOOTH ===
    "USB\VID_8087&PID_0033",  # Intel Bluetooth AX211/AX1675
    "USB\VID_8087&PID_0032",
    "USB\VID_8087&PID_0029",
    "USB\VID_8087&PID_0026",
    "USB\VID_8087&PID_0025"
=======
    "PCI\VEN_8086&DEV_54F0"

    # === BLUETOOTH === (NON bloccato - serve per funzionamento BT)
    # "USB\VID_8087&PID_0033",  # Intel Bluetooth AX211/AX1675
    # "USB\VID_8087&PID_0032",
    # "USB\VID_8087&PID_0029",
    # "USB\VID_8087&PID_0026",
    # "USB\VID_8087&PID_0025"
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
)

# Driver INF da bloccare/rimuovere
$BLOCKED_INFS = @(
    "gna.inf",
    "intcaudiobus.inf"  # A volte causa problemi
)

# Driver che causano BSOD (versioni specifiche)
$BSOD_DRIVERS = @{
    "dtt" = @("11405", "11407", "117", "118", "119")  # Tutte le versioni dopo 11404
    "ipf" = @("11405", "11407", "117", "118", "119")
}

# Funzione log
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $ts = Get-Date -Format "HH:mm:ss"
    $logMsg = "[$ts] $Message"
    Write-Host $logMsg -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $logMsg
}

# Creazione cartelle
if (!(Test-Path $DownloadPath)) { New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null }
if (!(Test-Path $TempPath)) { New-Item -ItemType Directory -Path $TempPath -Force | Out-Null }

# Header
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
<<<<<<< HEAD
Write-Host "           PHN16-72 BSOD FIX SCRIPT v7.6" -ForegroundColor Cyan
=======
Write-Host "           PHN16-72 BSOD FIX SCRIPT v7.5" -ForegroundColor Cyan
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Basato su soluzioni Community Acer (artkirius, jihakkim)" -ForegroundColor Gray
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "  DOVE SCARICARE I DRIVER:" -ForegroundColor Yellow
Write-Host "  $Acer_URL" -ForegroundColor White
Write-Host ""
Write-Host "  DOVE SALVARE I DRIVER (file ZIP, non estratti!):" -ForegroundColor Yellow
Write-Host "  $DownloadPath" -ForegroundColor White
Write-Host ""
Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Driver problematici da gestire:" -ForegroundColor White
Write-Host "  - Intel DPTF/DTT    : versioni 11405+ causano crash" -ForegroundColor White
Write-Host "  - Intel GNA         : BSOD vari" -ForegroundColor White
<<<<<<< HEAD
=======
Write-Host "  - Intel HID Filter  : freeze sistema" -ForegroundColor White
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
Write-Host "  - Intel PPM         : CLOCK_WATCHDOG_TIMEOUT" -ForegroundColor White
Write-Host "  - Intel Chipset     : driver corrotti" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Log "Script avviato - Log: $LogFile"
Write-Host ""

# ============================================================================
# FASE 1: DIAGNOSTICA COMPLETA
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [1/7] DIAGNOSTICA DRIVER" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$drivers = Get-WmiObject Win32_PnPSignedDriver 2>$null | 
    Select-Object DeviceName, DriverVersion, InfName, Manufacturer, HardWareID

if (!$drivers) {
    Write-Log "ERRORE: impossibile leggere driver WMI!" "Red"
    exit 1
}

# Stato driver
$Issues = @()

# 1. DTT/DPTF - RILEVAMENTO MULTIPLO
# NOTA: Il pacchetto DPTF Acer spesso NON appare in Device Manager!
# Dobbiamo cercare: servizio ESIF, cartella installazione, programmi, registro

$dptfFound = $false
$dptfVersion = ""
$dptfSource = ""

# Metodo 1: Servizio ESIF (più affidabile)
$esifSvc = Get-Service "esifsvc*" 2>$null
if ($esifSvc) {
    $dptfFound = $true
    $dptfSource = "servizio $($esifSvc.Name)"
}

# Metodo 2: Cartella installazione Intel DTT
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
            $dptfSource = "cartella: $path"
        }
        break
    }
}

# Metodo 3: Programmi installati (Add/Remove Programs)
$installedDptf = Get-Package "*Dynamic Tuning*","*DPTF*","*Thermal Framework*" 2>$null | Select-Object -First 1
if ($installedDptf) {
    $dptfFound = $true
    $dptfVersion = $installedDptf.Version
    $dptfSource = "programma: $($installedDptf.Name)"
}

# Metodo 4: Registro di sistema
$regPaths = @(
    "HKLM:\SOFTWARE\Intel\DPTF",
    "HKLM:\SOFTWARE\Intel\DTT"
)
foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        $dptfFound = $true
        $regVer = (Get-ItemProperty $regPath -Name "Version" -EA 0).Version
        if ($regVer -and !$dptfVersion) { $dptfVersion = $regVer }
        if (!$dptfSource) { $dptfSource = "registro: $regPath" }
    }
}

# Metodo 5: Device Manager (fallback)
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

# Valuta risultato
if ($dptfFound) {
    if ($dptfVersion) {
        $isBad = $BSOD_DRIVERS["dtt"] | Where-Object { $dptfVersion -match $_ }
        if ($isBad) {
            Write-Log "  [X] DTT/DPTF: $dptfVersion [CAUSA BSOD!] ($dptfSource)" "Red"
            $Issues += "DTT_BAD"
        } elseif ($dptfVersion -match "11404|11401|11400|11399") {
            Write-Log "  [OK] DTT/DPTF: $dptfVersion [stabile] ($dptfSource)" "Green"
        } else {
            Write-Log "  [?] DTT/DPTF: $dptfVersion ($dptfSource)" "Yellow"
        }
    } else {
        Write-Log "  [OK] DTT/DPTF: Installato ($dptfSource)" "Green"
    }
} else {
    Write-Log "  [-] DTT/DPTF: Non installato" "Yellow"
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
        Write-Log "  [X] IPF: $ver [versione problematica]" "Red"
        $Issues += "IPF_BAD"
    } elseif ($ver -match $IPF_STABLE) {
        Write-Log "  [OK] IPF: $ver [stabile]" "Green"
    } else {
        Write-Log "  [?] IPF: $ver [versione sconosciuta]" "Yellow"
    }
} else {
    Write-Log "  [-] IPF: Non installato" "Yellow"
}

# 3. GNA
$gna = $drivers | Where-Object { 
    $_.DeviceName -like "*GNA*" -or 
    $_.DeviceName -like "*Gaussian*" -or
    $_.InfName -like "*gna*"
}
if ($gna) {
    Write-Log "  [X] GNA: PRESENTE [causa BSOD - da rimuovere]" "Red"
    $Issues += "GNA"
} else {
    Write-Log "  [OK] GNA: Non presente" "Green"
}

<<<<<<< HEAD
# 4. HID Event Filter (necessario per touchpad/tasti Fn)
$hid = $drivers | Where-Object { 
    $_.DeviceName -like "*HID Event Filter*" -or
    $_.HardWareID -like "*INTC1070*"
}
if ($hid) {
    Write-Log "  [OK] HID Event Filter: $($hid.DriverVersion) [per touchpad/tasti Fn]" "Green"
} else {
    Write-Log "  [-] HID Event Filter: Non presente (potrebbe servire per touchpad)" "Yellow"
=======
# 4. HID Event Filter
$hid = $drivers | Where-Object { 
    $_.DeviceName -like "*HID Event Filter*" -or
    $_.InfName -like "*heci*" -or
    $_.HardWareID -like "*INTC1070*"
}
if ($hid) {
    Write-Log "  [!] HID Event Filter: $($hid.DriverVersion) [potenziale problema]" "Yellow"
    $Issues += "HID"
} else {
    Write-Log "  [-] HID Event Filter: Non presente" "Gray"
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
}

# 5. Intel PPM (intelppm)
$intelppmKey = "HKLM:\SYSTEM\CurrentControlSet\Services\intelppm"
$intelppmStart = (Get-ItemProperty $intelppmKey -Name Start -EA 0).Start
$intelppmStatus = "UNKNOWN"

if ($intelppmStart -eq 4) {
    Write-Log "  [OK] Intel PPM: DISABILITATO (Start=4) [fix jihakkim attivo]" "Green"
    $intelppmStatus = "DISABLED"
} elseif ($intelppmStart -eq 3) {
    Write-Log "  [X] Intel PPM: ATTIVO (Start=3) [causa CLOCK_WATCHDOG_TIMEOUT!]" "Red"
    $intelppmStatus = "ENABLED"
    $Issues += "INTELPPM"
} else {
    Write-Log "  [?] Intel PPM: Start=$intelppmStart [stato sconosciuto]" "Yellow"
    $intelppmStatus = "UNKNOWN"
}

# 6. Killer SOFTWARE (non il driver WiFi!)
# NOTA: Intel Killer AX1675i è il chip WiFi standard del PHN16-72
# Il DRIVER è necessario, il BLOATWARE è il software Killer Control Center
# Cerca SOLO il software, NON i driver
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
        Write-Log "  [!] Killer SOFTWARE: $swNames [bloatware opzionale]" "Yellow"
    } else {
        Write-Log "  [!] Killer SOFTWARE: Servizi in esecuzione [bloatware opzionale]" "Yellow"
    }
    $Issues += "KILLER_SW"
} else {
    Write-Log "  [OK] Killer SOFTWARE: Non presente (driver WiFi OK)" "Green"
}

Write-Host ""
if ($Issues.Count -eq 0) {
    Write-Log "  RISULTATO: Sistema OK - nessun problema rilevato" "Green"
} else {
    Write-Log "  RISULTATO: Trovati $($Issues.Count) problemi: $($Issues -join ', ')" "Red"
}
Write-Host ""

# ============================================================================
# FASE 2: FIX INTELPPM (jihakkim)
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [2/7] FIX INTEL PPM (CLOCK_WATCHDOG_TIMEOUT)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Questo fix disabilita il driver Intel Processor Power Management" -ForegroundColor Gray
Write-Host "  che va in conflitto con PredatorSense/firmware causando BSOD." -ForegroundColor Gray
Write-Host "  Fonte: jihakkim (Acer Community) - testato 2+ settimane" -ForegroundColor Gray
Write-Host ""

if ($SkipIntelppmFix) {
    Write-Log "  Saltato (-SkipIntelppmFix)" "Yellow"
} elseif ($intelppmStatus -eq "DISABLED") {
    Write-Log "  Gia applicato - nessuna azione necessaria" "Green"
} elseif ($DryRun) {
    Write-Log "  [DryRun] Imposterebbe: HKLM\...\intelppm\Start = 4" "Yellow"
} else {
    # Backup valore originale
    $backupFile = "$env:USERPROFILE\Desktop\intelppm_backup.reg"
    reg export "HKLM\SYSTEM\CurrentControlSet\Services\intelppm" $backupFile /y 2>$null
    Write-Log "  Backup creato: $backupFile" "Gray"
    
    # Applica fix
    try {
        Set-ItemProperty -Path $intelppmKey -Name "Start" -Value 4 -Type DWord -Force
        $verify = (Get-ItemProperty $intelppmKey -Name Start).Start
        if ($verify -eq 4) {
            Write-Log "  [OK] Intel PPM disabilitato (Start=4)" "Green"
            Write-Log "  RICHIESTO RIAVVIO per applicare" "Yellow"
        } else {
            Write-Log "  [X] Verifica fallita - Start=$verify" "Red"
        }
    } catch {
        Write-Log "  [X] Errore: $_" "Red"
    }
}
Write-Host ""

# ============================================================================
# FASE 3: RIMOZIONE DRIVER PROBLEMATICI
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [3/7] RIMOZIONE DRIVER PROBLEMATICI" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$removedCount = 0

# GNA - Disabilita e rimuovi
if ($Issues -contains "GNA") {
    Write-Log "  Rimuovo Intel GNA..." "Yellow"
    
    if (!$DryRun) {
        # Disabilita dispositivo
        $gnaDevices = Get-PnpDevice -FriendlyName "*GNA*","*Gaussian*" 2>$null
        foreach ($dev in $gnaDevices) {
            try {
                Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false 2>$null
                Write-Log "    Disabilitato: $($dev.FriendlyName)" "Green"
            } catch { }
        }
        
        # Rimuovi driver
        $oems = pnputil /enum-drivers 2>$null
        $currentOem = ""
        foreach ($line in $oems) {
            if ($line -match "(oem\d+\.inf)") { $currentOem = $matches[1] }
            if ($line -match "gna" -and $currentOem) {
                pnputil /delete-driver $currentOem /uninstall /force 2>$null
                Write-Log "    Rimosso: $currentOem" "Green"
                $removedCount++
                $currentOem = ""
            }
        }
    }
}

<<<<<<< HEAD
=======
# HID Event Filter - Rimuovi se problematico
if ($Issues -contains "HID") {
    Write-Log "  Gestisco HID Event Filter..." "Yellow"
    
    if (!$DryRun) {
        $hidDevices = Get-PnpDevice | Where-Object { 
            $_.FriendlyName -like "*HID Event*" -or 
            $_.InstanceId -like "*INTC1070*" 
        }
        foreach ($dev in $hidDevices) {
            try {
                Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false 2>$null
                Write-Log "    Disabilitato: $($dev.FriendlyName)" "Green"
            } catch { }
        }
    }
}

>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
# Killer SOFTWARE (NON i driver WiFi!)
if ($Issues -contains "KILLER_SW") {
    Write-Log "  Rimuovo Killer SOFTWARE (il driver WiFi resta)..." "Yellow"
    
    if (!$DryRun) {
        # Ferma servizi Killer
        $killerSvcs = Get-Service "*Killer*" 2>$null
        foreach ($svc in $killerSvcs) {
            Stop-Service $svc.Name -Force 2>$null
            Set-Service $svc.Name -StartupType Disabled 2>$null
            Write-Log "    Servizio disabilitato: $($svc.Name)" "Green"
        }
        
        # Rimuovi software Killer (Control Center, Intelligence Center, ecc)
        $killerApps = Get-Package "*Killer*" 2>$null | Where-Object { $_.Name -notlike "*Driver*" -and $_.Name -notlike "*WiFi*" }
        foreach ($app in $killerApps) {
            try {
                $app | Uninstall-Package -Force 2>$null
                Write-Log "    Rimosso: $($app.Name)" "Green"
                $removedCount++
            } catch { }
        }
        
        # NON rimuovere i driver WiFi Killer - sono necessari!
        Write-Log "    NOTA: Driver WiFi Intel Killer mantenuto (necessario)" "Cyan"
    }
}

# DTT problematico - rimuovi se versione sbagliata
if ($Issues -contains "DTT_BAD") {
    Write-Log "  Rimuovo DTT problematico..." "Yellow"
    
    if (!$DryRun) {
        # Ferma servizio ESIF
        Stop-Service "esifsvc*" -Force 2>$null
        
        # Rimuovi driver DTT
        $oems = pnputil /enum-drivers 2>$null
        $currentOem = ""
        foreach ($line in $oems) {
            if ($line -match "(oem\d+\.inf)") { $currentOem = $matches[1] }
            if (($line -match "dtt|dptf|Dynamic Tuning") -and $currentOem) {
                pnputil /delete-driver $currentOem /uninstall /force 2>$null
                Write-Log "    Rimosso: $currentOem" "Green"
                $removedCount++
                $currentOem = ""
            }
        }
    }
}

Write-Log "  Rimossi $removedCount driver" "Cyan"
Write-Host ""

# ============================================================================
# FASE 4: BLOCCO WINDOWS UPDATE PER TUTTI I DRIVER
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [4/7] BLOCCO WINDOWS UPDATE PER DRIVER INSTALLATI" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Impedisce a Windows di sovrascrivere i driver che installiamo" -ForegroundColor Gray
Write-Host ""

if (!$DryRun) {
    # 1. Disabilita driver via Windows Update
    $wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (!(Test-Path $wuKey)) { New-Item -Path $wuKey -Force | Out-Null }
    Set-ItemProperty -Path $wuKey -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord
    Write-Log "  [OK] ExcludeWUDriversInQualityUpdate = 1" "Green"
    
    # 2. Disabilita ricerca driver online
    $dsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
    Set-ItemProperty -Path $dsKey -Name "SearchOrderConfig" -Value 0 -Type DWord
    Write-Log "  [OK] SearchOrderConfig = 0" "Green"
    
    # 3. Blocca Hardware IDs specifici
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
    
    Write-Log "  Bloccati $($BLOCKED_HWIDS.Count) Hardware IDs:" "Cyan"
    Write-Log "    - GNA, HID Filter (problematici)" "Gray"
    Write-Log "    - DTT/DPTF" "Gray"
    Write-Log "    - Chipset / Serial IO" "Gray"
    Write-Log "    - ME (Management Engine)" "Gray"
    Write-Log "    - VGA Intel UHD" "Gray"
    Write-Log "    - Audio Realtek" "Gray"
    Write-Log "    - LAN Ethernet" "Gray"
    Write-Log "    - WLAN WiFi" "Gray"
    Write-Log "    - Bluetooth" "Gray"
    Write-Log "  Windows Update non potra' sovrascrivere questi driver" "Green"
}
Write-Host ""

# ============================================================================
# FASE 5: GUIDA DOWNLOAD
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [5/7] DOWNLOAD DRIVER STABILI" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

if ($SkipDownload) {
    Write-Log "  Saltato (-SkipDownload)" "Yellow"
} else {
    # Genera guida HTML
    $html = @"
<!DOCTYPE html>
<<<<<<< HEAD
<html><head><meta charset="UTF-8"><title>PHN16-72 Driver Guide v7.6</title>
=======
<html><head><meta charset="UTF-8"><title>PHN16-72 Driver Guide v7.5</title>
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
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
<<<<<<< HEAD
<h1>PHN16-72 Driver Guide v7.6</h1>
=======
<h1>PHN16-72 Driver Guide v7.5</h1>
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)

<div class="critical">
<h2>DRIVER CHE CAUSANO BSOD</h2>
<table>
<tr><th>Driver</th><th>File</th><th>Errore BSOD</th><th>Azione</th></tr>
<tr><td class="bad">Intel DPTF/DTT 11405+</td><td>dtt_sw.inf</td><td>Crash termici</td><td>Rimuovere</td></tr>
<tr><td class="bad">Intel DPTF (APO)</td><td>-</td><td>Richiede DTT 11405+</td><td>NON installare!</td></tr>
<tr><td class="bad">Intel GNA</td><td>gna.inf</td><td>Vari BSOD</td><td>Bloccare</td></tr>
<tr><td class="bad">Intel PPM</td><td>intelppm.sys</td><td>CLOCK_WATCHDOG_TIMEOUT</td><td>Disabilitare</td></tr>
<<<<<<< HEAD
=======
<tr><td class="bad">Intel HID Filter</td><td>INTC1070</td><td>Freeze sistema</td><td>Disabilitare</td></tr>
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
</table>
</div>

<div class="success">
<h2>VERSIONI STABILI (pre-BSOD)</h2>
<ul>
<li><b>DPTF (SENZA APO):</b> v1.0.11401 o precedenti - dal sito Acer</li>
<li><b>DTT:</b> 9.0.11404.39881 o precedenti</li>
<li><b>IPF:</b> 1.0.11404.41023 o precedenti</li>
</ul>
<p style="color:#ff8800"><b>ATTENZIONE:</b> NON installare "DPTF (APO)" - richiede DTT 11405+ che causa BSOD!</p>
</div>

<div class="box">
<h2><span class="step">1</span> Driver da Acer (CONSIGLIATI)</h2>
<p><a href="$Acer_URL" target="_blank">Apri pagina supporto Acer PHN16-72</a></p>
<p><b>SCARICA QUESTI (in ordine di priorita'):</b></p>
<ol>
<li><b>Chipset Intel</b> - Serial IO, I2C, base per touchpad</li>
<li><b>ME</b> - Intel Management Engine</li>
<li><b>DPTF (SENZA APO)</b> - cerca versione 1.0.11401, NON quella con "(APO)"!</li>
<li><b>VGA Intel UMA</b> - Grafica integrata (IMPORTANTE: scegli UMA, non non-UMA!)</li>
<li><b>Audio Realtek</b></li>
<li><b>LAN E3100G</b> - <span style="color:#ff8800">SENZA Killer Control Centre!</span></li>
<li><b>Wireless LAN</b> - <span style="color:#ff8800">SENZA 1675i!</span></li>
<li><b>Bluetooth</b> - Se non funziona</li>
<<<<<<< HEAD
<li><b>HID Event Filter</b> - Per touchpad e tasti Fn</li>
=======
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
</ol>
<p style="margin-top:10px;color:#ff4444"><b>ATTENZIONE:</b> Per LAN e WLAN scegli le versioni SENZA software aggiuntivo!</p>
</div>

<div class="warning">
<h2>NON SCARICARE MAI</h2>
<ul>
<<<<<<< HEAD
<li><b>GNA</b> - Intel Gaussian Neural Accelerator (causa BSOD)</li>
=======
<li><b>GNA</b> - Intel Gaussian Neural Accelerator (BLOCCATO)</li>
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
<li><b>DTT/DPTF versioni 11405+</b> - Causano BSOD</li>
</ul>
<p style="margin-top:15px"><b>NOTA WiFi:</b> Il driver Intel Killer AX1675i e' NECESSARIO (e' il chip WiFi del laptop). 
Il bloatware da evitare e' il SOFTWARE Killer Control Center, non il driver.</p>
</div>

<div class="box">
<h2><span class="step">2</span> Ordine di Installazione (IMPORTANTE!)</h2>
<p>Lo script installa automaticamente nell'ordine corretto e ti guida per VGA Intel e NVIDIA:</p>
<ol>
<li><b>Chipset Intel</b> - PRIMO! Base per tutti gli altri driver</li>
<li><b>ME</b> - Intel Management Engine</li>
<li><b>DPTF</b> - Thermal Framework (versione SENZA APO!)</li>
<li><b style="color:#00d4ff">VGA Intel UMA</b> - Lo script ti guidera' per installazione manuale via Device Manager</li>
<li><b style="color:#76b900">NVIDIA</b> - Installare manualmente (GeForce Experience o nvidia.com)</li>
<li><b>Audio Realtek</b></li>
<li><b>LAN</b> - Ethernet</li>
<li><b>Wireless LAN</b> - WiFi</li>
<li><b>Bluetooth</b></li>
</ol>
<p style="color:#ff8800"><b>RIAVVIA dopo ogni driver critico (Chipset, ME, DPTF, GPU)</b></p>
<p style="color:#00ff88"><b>Windows Update e' bloccato per tutti questi driver!</b></p>
</div>

<div class="warning">
<h3>VGA INTEL - INSTALLAZIONE MANUALE</h3>
<p>L'installer automatico Intel VGA ha un bug (Parade MUX) su questi laptop.</p>
<p>Lo script ti guidera' per installare manualmente via Device Manager:</p>
<ol>
<li>Estrai il file ZIP del driver VGA Intel</li>
<li>Apri Device Manager (Win+X -> Device Manager)</li>
<li>Espandi "Display adapters"</li>
<li>Click destro su "Intel UHD Graphics" -> "Update driver"</li>
<li>"Browse my computer for drivers"</li>
<li>Seleziona la cartella estratta -> Next</li>
</ol>
<p style="color:#ff4444"><b>Se lo schermo diventa nero:</b> Riavvia in Safe Mode e ripeti</p>
</div>

<div class="box">
<h2><span class="step">3</span> Verifica finale</h2>
<p>Dopo il riavvio, esegui:</p>
<pre><code>.\HeliosPHN16-72_Check.ps1</code></pre>
<p>Controlla che:</p>
<ul>
<li>DTT sia versione 11404 o 11401</li>
<li>GNA sia assente/bloccato</li>
<li>intelppm sia disabilitato (Start=4)</li>
</ul>
</div>

<div class="box">
<h2>Fonti (Community Acer)</h2>
<ul>
<li><a href="https://community.acer.com/en/discussion/723737">artkirius - SOLVED CLOCK_WATCHDOG</a></li>
<li><a href="https://community.acer.com/en/discussion/728746">jihakkim - Fix intelppm</a></li>
<li><a href="https://community.acer.com/en/discussion/728578">Puraw - Clean install guide</a></li>
</ul>
</div>

<p style="margin-top:40px;color:#888;text-align:center">
<<<<<<< HEAD
Generato: $(Get-Date -Format "dd/MM/yyyy HH:mm") | PHN16-72 Setup v7.6
=======
Generato: $(Get-Date -Format "dd/MM/yyyy HH:mm") | PHN16-72 Setup v7.5
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
</p>
</body></html>
"@
    $html | Out-File "$DownloadPath\GUIDA_DRIVER.html" -Encoding UTF8
    
    # Apri browser
    Start-Process $Acer_URL
    Start-Process "$DownloadPath\GUIDA_DRIVER.html"
    
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host "  SCARICA QUESTI DRIVER DAL SITO ACER:" -ForegroundColor Yellow
    Write-Host "  (Lo script li installera' nell'ordine corretto)" -ForegroundColor Gray
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  1. [OK] Chipset Intel (Serial IO, I2C)" -ForegroundColor Green
    Write-Host "  2. [OK] ME - Intel Management Engine" -ForegroundColor Green
    Write-Host "  3. [OK] DPTF (SENZA APO!) - versione 11401" -ForegroundColor Green
    Write-Host "  4. [>>] VGA Intel UMA - LO SCRIPT TI GUIDERA'" -ForegroundColor Cyan
    Write-Host "  5. [>>] NVIDIA - LO SCRIPT TI CHIEDERA' DI INSTALLARLO" -ForegroundColor Cyan
    Write-Host "  6. [OK] Audio Realtek" -ForegroundColor Green
    Write-Host "  7. [OK] LAN E3100G (SENZA Killer Control Centre!)" -ForegroundColor Green
    Write-Host "  8. [OK] Wireless LAN (SENZA 1675i!)" -ForegroundColor Green
    Write-Host "  9. [OK] Bluetooth (se necessario)" -ForegroundColor Green
<<<<<<< HEAD
    Write-Host " 10. [OK] HID Event Filter (per touchpad/tasti Fn)" -ForegroundColor Green
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  [X] NON scaricare: GNA" -ForegroundColor Red
=======
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  [X] NON scaricare: GNA, HID Event Filter" -ForegroundColor Red
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
    Write-Host "  ------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  SALVA I FILE ZIP (senza estrarre!) IN:" -ForegroundColor White
    Write-Host "  $DownloadPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Crea cartella se non esiste
    if (!(Test-Path $DownloadPath)) { 
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null 
        Write-Host "  Cartella creata: $DownloadPath" -ForegroundColor Green
    }
    
    Read-Host "  Premi INVIO quando hai scaricato tutti i driver"
}
Write-Host ""

# ============================================================================
# FASE 6: INSTALLAZIONE DRIVER (ORDINE CORRETTO + PULIZIA)
# ============================================================================
# Ordine consigliato dalla community Acer (Puraw):
# 1. Chipset  2. ME  3. DPTF  4. GPU (Intel + NVIDIA)  5. Audio  6. WiFi  7. Bluetooth

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [6/7] INSTALLAZIONE DRIVER" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Ordine installazione: Chipset > ME > DPTF > GPU > Audio > WiFi > BT" -ForegroundColor Gray
Write-Host ""

# Mappa priorità installazione (numero più basso = prima)
# NOTA: VGA Intel e NVIDIA sono MANUALI, non in questa lista
$InstallOrder = @{
    "chipset"   = 1
    "chip"      = 1
    "serialio"  = 1
    "serial"    = 1
    "io.driver" = 1      # Nome file Acer: "IO Drivers_Intel" (. = qualsiasi char)
    "me"        = 2
    "management"= 2
    "mgmtengine"= 2      # Nome file Acer: "MgmtEngine_Intel"
    "mgmt.*engine" = 2
    "dptf"      = 3
    "dtt"       = 3
    "thermal"   = 3
    # VGA Intel = MANUALE (Parade MUX bug)
    # NVIDIA = MANUALE
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
    "bt_"       = 7      # bt_ per evitare match accidentali
<<<<<<< HEAD
    "hid"       = 8      # HID Event Filter per touchpad/tasti Fn
    "intc1070"  = 8
=======
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
}

# Driver da rimuovere prima dell'installazione (pulizia)
$DriversToClean = @{
    "dptf|dtt|thermal|esif" = "DTT/DPTF"
    "gna|gaussian"          = "GNA"
}

if ($SkipInstall) {
    Write-Log "  Saltato (-SkipInstall)" "Yellow"
} else {
    $zips = Get-ChildItem "$DownloadPath\*.zip" 2>$null
    
    if (!$zips -or $zips.Count -eq 0) {
        Write-Log "  Nessun ZIP trovato in $DownloadPath" "Yellow"
        Write-Log "  Scarica i driver dal sito Acer e salvali in:" "Yellow"
        Write-Log "  $DownloadPath" "White"
    } else {
        Write-Log "  Trovati $($zips.Count) pacchetti" "Cyan"
        
        # Filtra e blocca driver che non devono essere installati automaticamente
        $validZips = @()
        $vgaIntelZip = $null
        
        foreach ($z in $zips) {
            $name = $z.Name.ToLower()
            if ($name -match "gna|gaussian") {
                Write-Log "  [X] BLOCCATO: $($z.Name) [GNA - causa BSOD]" "Red"
                continue
            }
<<<<<<< HEAD
=======
            if ($name -match "hid.*event|hid.*filter|intc1070") {
                Write-Log "  [X] BLOCCATO: $($z.Name) [HID Event Filter - causa freeze]" "Red"
                continue
            }
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
            if ($name -match "nvidia|geforce|rtx|gtx") {
                Write-Log "  [i] SKIP: $($z.Name) [NVIDIA - installare manualmente]" "Cyan"
                continue
            }
            # VGA Intel ha problemi con installer silenzioso (Parade MUX bug)
            # Acer consiglia installazione manuale via Device Manager
            if ($name -match "vga.*intel|intel.*vga") {
                Write-Log "  [i] SKIP: $($z.Name) [VGA Intel - installare manualmente]" "Cyan"
                $vgaIntelZip = $z
                continue
            }
<<<<<<< HEAD
            # HID Event Filter - necessario per touchpad, ma può causare freeze
            # Lo installiamo ma con warning
            if ($name -match "hid.*event|hid.*filter") {
                Write-Log "  [!] WARNING: $($z.Name) [HID Event Filter - necessario per touchpad]" "Yellow"
                # Non bloccare, lascialo installare
            }
=======
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
            $validZips += $z
        }
        
        # Ordina per priorità
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
        Write-Log "  Ordine installazione:" "Cyan"
        $i = 1
        foreach ($z in $sortedZips) {
            Write-Log "    $i. $($z.Name)" "White"
            $i++
        }
        Write-Host ""
        
        # FASE 6a: PULIZIA COMPLETA DRIVER ESISTENTI
        Write-Log "  --- Pulizia driver esistenti ---" "Yellow"
        Write-Log "  (Necessario per forzare Windows a usare i nuovi driver)" "Gray"
        
        if (!$DryRun) {
            # Pattern per identificare i driver da pulire in base ai pacchetti scaricati
            $cleanPatterns = @()
            
            foreach ($z in $sortedZips) {
                $name = $z.Name.ToLower()
                
                # Aggiungi pattern di pulizia in base al tipo di pacchetto
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
            
            # Sempre pulire GNA (problematico)
            $cleanPatterns += "gna|gaussian"
            
            # Rimuovi duplicati
            $cleanPatterns = $cleanPatterns | Select-Object -Unique
            $cleanRegex = ($cleanPatterns -join "|")
            
            Write-Log "  Cerco driver da rimuovere..." "Gray"
            
            # Enumera tutti i driver
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
                
                # Se abbiamo entrambi, verifica se corrisponde ai pattern
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
                Write-Log "  Trovati $($driversToRemove.Count) driver da rimuovere:" "Yellow"
                
                foreach ($drv in $driversToRemove) {
                    Write-Log "    Rimuovo: $($drv.Oem) ($($drv.Original))" "Gray"
                    $result = pnputil /delete-driver $drv.Oem /uninstall 2>&1 | Out-String
                    if ($result -match "eliminato|deleted|Driver package deleted") {
                        $cleanedCount++
                    } elseif ($result -match "in uso|in use") {
                        Write-Log "      [!] In uso - verra' sostituito al riavvio" "Yellow"
                    }
                }
                
                Write-Log "  Rimossi $cleanedCount driver" "Green"
                
                if ($cleanedCount -lt $driversToRemove.Count) {
                    Write-Log "  [!] Alcuni driver sono in uso - riavviare dopo l'installazione" "Yellow"
                }
            } else {
                Write-Log "  Nessun driver esistente da pulire" "Gray"
            }
        }
        
        Write-Host ""
        Write-Log "  --- Installazione nuovi driver ---" "Yellow"
        
        # Flag per prompt GPU
        $gpuPromptShown = $false
        $dptfInstalled = $false
        
        # FASE 6b: INSTALLAZIONE ORDINATA
        foreach ($z in $sortedZips) {
            $name = $z.Name.ToLower()
            
            # Dopo DPTF, chiedi di installare VGA Intel + NVIDIA manualmente
            if ($dptfInstalled -and !$gpuPromptShown) {
                $isDptf = $name -match "dptf|dtt|thermal"
                if (!$isDptf) {
                    $gpuPromptShown = $true
                    
                    # === PROMPT VGA INTEL ===
                    if ($vgaIntelZip) {
                        Write-Host ""
                        Write-Host "  ============================================================" -ForegroundColor Cyan
                        Write-Host "  >>> INSTALLA ORA IL DRIVER VGA INTEL <<<" -ForegroundColor Cyan
                        Write-Host "  ============================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Il driver VGA Intel richiede installazione manuale" -ForegroundColor White
                        Write-Host "  (l'installer automatico ha un bug con Parade MUX)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "  PROCEDURA:" -ForegroundColor Yellow
                        Write-Host "  1. Apri: $($vgaIntelZip.FullName)" -ForegroundColor White
                        Write-Host "  2. Estrai il contenuto in una cartella" -ForegroundColor White
                        Write-Host "  3. Apri Device Manager (Win+X -> Device Manager)" -ForegroundColor White
                        Write-Host "  4. Espandi 'Display adapters'" -ForegroundColor White
                        Write-Host "  5. Click destro su 'Intel UHD Graphics' -> 'Update driver'" -ForegroundColor White
                        Write-Host "  6. 'Browse my computer for drivers'" -ForegroundColor White
                        Write-Host "  7. Seleziona la cartella estratta -> Next" -ForegroundColor White
                        Write-Host ""
                        Write-Host "  NOTA: Se lo schermo diventa nero, riavvia in Safe Mode" -ForegroundColor Red
                        Write-Host "  ============================================================" -ForegroundColor Cyan
                        Write-Host ""
                        
                        if (!$DryRun) {
                            $response = Read-Host "  Premi INVIO dopo aver installato VGA Intel (o 'S' per saltare)"
                            if ($response -ne 'S' -and $response -ne 's') {
                                Write-Log "  VGA Intel installato dall'utente" "Green"
                            } else {
                                Write-Log "  VGA Intel saltato - installare dopo il riavvio" "Yellow"
                            }
                        }
                    }
                    
                    # === PROMPT NVIDIA ===
                    Write-Host ""
                    Write-Host "  ============================================================" -ForegroundColor Green
                    Write-Host "  >>> INSTALLA ORA I DRIVER NVIDIA <<<" -ForegroundColor Green
                    Write-Host "  ============================================================" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  OPZIONE 1: GeForce Experience (consigliato)" -ForegroundColor Cyan
                    Write-Host "    - Scarica da: https://www.nvidia.com/geforce-experience/" -ForegroundColor Gray
                    Write-Host "    - Installa e lascia che aggiorni i driver" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "  OPZIONE 2: Driver manuali" -ForegroundColor Cyan
                    Write-Host "    - Scarica da: https://www.nvidia.com/drivers/" -ForegroundColor Gray
                    Write-Host "    - Seleziona RTX 4060/4070/4080 Laptop GPU" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "  ============================================================" -ForegroundColor Green
                    Write-Host ""
                    
                    if (!$DryRun) {
                        $response = Read-Host "  Premi INVIO dopo aver installato NVIDIA (o 'S' per saltare)"
                        if ($response -ne 'S' -and $response -ne 's') {
                            Write-Log "  NVIDIA installato dall'utente" "Green"
                        } else {
                            Write-Log "  NVIDIA saltato - installare dopo il riavvio" "Yellow"
                        }
                    }
                    Write-Host ""
                }
            }
            
            Write-Log "  Elaboro: $($z.Name)" "White"
            $dest = "$TempPath\$($z.BaseName)"
            
            if (!$DryRun) {
                # Estrai
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force 2>$null }
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
                
                try {
                    Expand-Archive -Path $z.FullName -DestinationPath $dest -Force
                } catch {
                    Write-Log "    [X] Errore estrazione" "Red"
                    continue
                }
                
                # Cerca Install.cmd (pacchetti Acer standard)
                $installCmd = Get-ChildItem "$dest" -Filter "Install.cmd" -Recurse 2>$null | Select-Object -First 1
                
                # Cerca setup.exe
                $setup = Get-ChildItem "$dest" -Filter "*.exe" -Recurse 2>$null | 
                         Where-Object { $_.Name -match "^(setup|install|Setup|Install)" } | 
                         Select-Object -First 1
                
                # Cerca AsusSetup o simili (a volte usato da Acer)
                if (!$setup) {
                    $setup = Get-ChildItem "$dest" -Filter "*Setup*.exe" -Recurse 2>$null | 
                             Select-Object -First 1
                }
                
                $installed = $false
                
                # Metodo 1: Install.cmd (preferito per pacchetti Acer)
                if ($installCmd -and !$installed) {
                    Write-Log "    Eseguo: Install.cmd" "Cyan"
                    $workDir = $installCmd.DirectoryName
                    $proc = Start-Process "cmd.exe" -ArgumentList "/c `"$($installCmd.FullName)`"" -WorkingDirectory $workDir -Wait -PassThru -WindowStyle Hidden 2>$null
                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                        Write-Log "    [OK] Installato" "Green"
                        $installed = $true
                    } else {
                        Write-Log "    [!] Exit code: $($proc.ExitCode) - provo altro metodo" "Yellow"
                    }
                }
                
                # Metodo 2: setup.exe con parametri corretti per tipo
                if ($setup -and !$installed) {
                    Write-Log "    Eseguo: $($setup.Name)" "Cyan"
                    
                    # Intel Graphics Installer usa --silent
                    if ($setup.Name -match "Installer\.exe" -and ($name -match "vga|graphics|intel.*graph")) {
                        $proc = Start-Process $setup.FullName -ArgumentList "--silent" -Wait -PassThru 2>$null
                    }
                    # Intel SerialIO usa -s -overwrite
                    elseif ($setup.Name -match "SetupSerialIO") {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s","-overwrite" -Wait -PassThru 2>$null
                    }
                    # Intel ME usa -s -overwrite  
                    elseif ($setup.Name -match "SetupME") {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s","-overwrite" -Wait -PassThru 2>$null
                    }
                    # Intel Chipset usa -s -overwrite
                    elseif ($setup.Name -match "SetupChipset") {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s","-overwrite" -Wait -PassThru 2>$null
                    }
                    # Realtek Audio usa -s
                    elseif ($setup.Name -match "setup\.exe" -and ($name -match "audio|realtek|sound")) {
                        $proc = Start-Process $setup.FullName -ArgumentList "-s" -Wait -PassThru 2>$null
                    }
                    # Default: /quiet /norestart
                    else {
                        $proc = Start-Process $setup.FullName -ArgumentList "/quiet","/norestart" -Wait -PassThru 2>$null
                    }
                    
                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                        Write-Log "    [OK] Installato" "Green"
                        $installed = $true
                    } elseif ($proc.ExitCode -eq 1603) {
                        Write-Log "    [!] Exit code: 1603 (driver in uso) - installo INF forzato" "Yellow"
                        # Non marcare come installato, passerà al metodo 3
                    } else {
                        Write-Log "    [!] Exit code: $($proc.ExitCode)" "Yellow"
                    }
                }
                
                # Metodo 3: Installa INF manualmente (con force)
                if (!$installed) {
                    $infs = Get-ChildItem "$dest" -Filter "*.inf" -Recurse 2>$null
                    $infCount = 0
                    foreach ($inf in $infs) {
                        # Skip GNA
                        if ($inf.Name -match "gna") { continue }
                        
                        # Usa /force per sovrascrivere driver esistenti
                        $result = pnputil /add-driver $inf.FullName /install /force 2>&1 | Out-String
                        if ($result -match "success|pubblicato|aggiunto|added|già presente|already exists") {
                            $infCount++
                        }
                    }
                    if ($infCount -gt 0) {
                        Write-Log "    [OK] Installati $infCount INF" "Green"
                        $installed = $true
                    }
                }
                
                if (!$installed) {
                    Write-Log "    [!] Nessun installer trovato - installa manualmente" "Yellow"
                }
                
                # Segna se abbiamo installato driver DPTF (per mostrare prompt GPU dopo)
                if ($installed -and ($name -match "dptf|dtt|thermal")) {
                    $dptfInstalled = $true
                }
            }
        }
        
        # Se non c'era DPTF ma c'è VGA Intel da installare, mostra comunque il prompt GPU
        if (!$gpuPromptShown -and $vgaIntelZip) {
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host "  >>> INSTALLA ORA IL DRIVER VGA INTEL <<<" -ForegroundColor Cyan
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Il driver VGA Intel richiede installazione manuale" -ForegroundColor White
            Write-Host "  (l'installer automatico ha un bug con Parade MUX)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  PROCEDURA:" -ForegroundColor Yellow
            Write-Host "  1. Apri: $($vgaIntelZip.FullName)" -ForegroundColor White
            Write-Host "  2. Estrai il contenuto in una cartella" -ForegroundColor White
            Write-Host "  3. Apri Device Manager (Win+X -> Device Manager)" -ForegroundColor White
            Write-Host "  4. Espandi 'Display adapters'" -ForegroundColor White
            Write-Host "  5. Click destro su 'Intel UHD Graphics' -> 'Update driver'" -ForegroundColor White
            Write-Host "  6. 'Browse my computer for drivers'" -ForegroundColor White
            Write-Host "  7. Seleziona la cartella estratta -> Next" -ForegroundColor White
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host ""
            
            if (!$DryRun) {
                $response = Read-Host "  Premi INVIO dopo aver installato VGA Intel (o 'S' per saltare)"
                if ($response -ne 'S' -and $response -ne 's') {
                    Write-Log "  VGA Intel installato dall'utente" "Green"
                } else {
                    Write-Log "  VGA Intel saltato" "Yellow"
                }
            }
            
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Green
            Write-Host "  >>> INSTALLA ORA I DRIVER NVIDIA <<<" -ForegroundColor Green
            Write-Host "  ============================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "  OPZIONE 1: GeForce Experience (consigliato)" -ForegroundColor Cyan
            Write-Host "    - Scarica da: https://www.nvidia.com/geforce-experience/" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  OPZIONE 2: Driver manuali" -ForegroundColor Cyan
            Write-Host "    - Scarica da: https://www.nvidia.com/drivers/" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Green
            Write-Host ""
            
            if (!$DryRun) {
                $response = Read-Host "  Premi INVIO dopo aver installato NVIDIA (o 'S' per saltare)"
                if ($response -ne 'S' -and $response -ne 's') {
                    Write-Log "  NVIDIA installato dall'utente" "Green"
                } else {
                    Write-Log "  NVIDIA saltato" "Yellow"
                }
            }
        }
        
        Write-Host ""
        Write-Log "  Installazione completata" "Green"
        
        # Forza Windows a riesaminare i dispositivi e usare i nuovi driver
        Write-Log "  Aggiorno dispositivi hardware..." "Yellow"
        
        # Metodo 1: pnputil rescan
        $rescan = pnputil /scan-devices 2>&1 | Out-String
        if ($rescan -match "completata|completed") {
            Write-Log "  [OK] Scansione dispositivi completata" "Green"
        }
        
        # Metodo 2: Riavvia dispositivi critici per forzare caricamento nuovi driver
        Write-Log "  Alcuni driver richiedono RIAVVIO per essere attivati" "Yellow"
    }
}
Write-Host ""

# ============================================================================
# FASE 7: FINALIZZAZIONE
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [7/7] FINALIZZAZIONE" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Genera script rollback
$rollbackScript = @'
#Requires -RunAsAdministrator
<<<<<<< HEAD
# PHN16-72 Rollback v7.6
=======
# PHN16-72 Rollback v7.5
>>>>>>> dabfaea (Initial release: BSOD fix toolkit for Acer Predator PHN16-72)
# Ripristina le impostazioni originali

Write-Host "PHN16-72 Rollback" -ForegroundColor Yellow
Write-Host ""

# Ripristina intelppm
$intelppmKey = "HKLM:\SYSTEM\CurrentControlSet\Services\intelppm"
Set-ItemProperty -Path $intelppmKey -Name "Start" -Value 3 -Type DWord -EA 0
Write-Host "Intel PPM: Start = 3 (ripristinato)" -ForegroundColor Yellow

# Rimuovi blocchi Windows Update
Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" -EA 0
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" -Value 1 -EA 0
Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" -Recurse -EA 0
Write-Host "Blocchi Windows Update: rimossi" -ForegroundColor Yellow

Write-Host ""
Write-Host "ATTENZIONE: Dopo il riavvio, Windows Update potrebbe" -ForegroundColor Red
Write-Host "reinstallare i driver problematici!" -ForegroundColor Red
Write-Host ""
Write-Host "Riavvia il PC per applicare le modifiche" -ForegroundColor Cyan
'@

$rollbackPath = "$env:USERPROFILE\Desktop\PHN16-72_ROLLBACK.ps1"
$rollbackScript | Out-File $rollbackPath -Encoding ASCII
Write-Log "  Script rollback: $rollbackPath" "Green"

# Riepilogo
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "                    SETUP COMPLETATO" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  FIX APPLICATI:" -ForegroundColor White

if ($intelppmStatus -ne "DISABLED" -and !$SkipIntelppmFix -and !$DryRun) {
    Write-Host "  [OK] Intel PPM disabilitato (fix CLOCK_WATCHDOG)" -ForegroundColor Green
}
if ($Issues -contains "GNA") {
    Write-Host "  [OK] GNA rimosso/bloccato" -ForegroundColor Green
}
if ($Issues -contains "KILLER_SW") {
    Write-Host "  [OK] Killer SOFTWARE rimosso (driver WiFi mantenuto)" -ForegroundColor Green
}
Write-Host "  [OK] Windows Update bloccato per driver problematici" -ForegroundColor Green
Write-Host "  [OK] Driver esistenti rimossi e nuovi installati" -ForegroundColor Green

Write-Host "------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  PROSSIMI PASSI:" -ForegroundColor Yellow
Write-Host "  1. *** RIAVVIA IL PC *** (OBBLIGATORIO!)" -ForegroundColor Red
Write-Host "     I nuovi driver saranno attivi solo dopo il riavvio" -ForegroundColor Gray
Write-Host "  2. Esegui: .\HeliosPHN16-72_Check.ps1" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------------" -ForegroundColor Green
Write-Host "  FILE GENERATI:" -ForegroundColor White
Write-Host "  - $LogFile" -ForegroundColor Gray
Write-Host "  - $rollbackPath" -ForegroundColor Gray
Write-Host "  - $DownloadPath\GUIDA_DRIVER.html" -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

Write-Log "Script completato"

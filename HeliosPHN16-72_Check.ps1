#Requires -RunAsAdministrator
# ============================================================================
# PHN16-72 Check v7.3
# ============================================================================
# Verifica tutti i fix BSOD dalla Community Acer
# ============================================================================

param(
    [switch]$Debug  # Mostra info dettagliate su cosa viene rilevato
)

# Auto-rilancio come Amministratore se necessario
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  Rilancio come Amministratore..." -ForegroundColor Yellow
    
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Debug) { $argList += "-Debug" }
    
    try {
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
        exit 0
    } catch {
        Write-Host "  ERRORE: Esegui questo script come Amministratore!" -ForegroundColor Red
        exit 1
    }
}

$ErrorActionPreference = "SilentlyContinue"

# Versioni stabili
$DTT_STABLE = "9.0.11404"
$DTT_ACER_STABLE = "1.0.11401"
$IPF_STABLE = "1.0.11404"

# Contatori
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
Write-Host "           PHN16-72 BSOD FIX CHECK v7.3" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Verifica fix da Community Acer (artkirius, jihakkim, Puraw)" -ForegroundColor Gray
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Leggi driver
$drivers = Get-WmiObject Win32_PnPSignedDriver 2>$null | 
    Select-Object DeviceName, DriverVersion, InfName, Manufacturer

if (!$drivers) {
    Write-Host "  ERRORE: Impossibile leggere driver!" -ForegroundColor Red
    exit 1
}

# Debug: mostra cosa viene rilevato
if ($Debug) {
    Write-Host ""
    Write-Host "=== DEBUG INFO ===" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "DPTF - Servizio ESIF:" -ForegroundColor Magenta
    $debugEsif = Get-Service "esifsvc*" 2>$null
    if ($debugEsif) {
        $debugEsif | ForEach-Object { Write-Host "  [TROVATO] $($_.Name): $($_.Status)" -ForegroundColor Green }
    } else {
        Write-Host "  (nessun servizio esifsvc*)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "DPTF - Cartelle installazione:" -ForegroundColor Magenta
    $dttPaths = @(
        "$env:ProgramFiles\Intel\Intel(R) Dynamic Tuning Technology",
        "$env:ProgramFiles\Intel\DPTF",
        "$env:ProgramFiles (x86)\Intel\Intel(R) Dynamic Tuning Technology"
    )
    foreach ($path in $dttPaths) {
        if (Test-Path $path) {
            Write-Host "  [TROVATO] $path" -ForegroundColor Green
            Get-ChildItem $path -Filter "*.exe" 2>$null | ForEach-Object { 
                Write-Host "    - $($_.Name) v$($_.VersionInfo.FileVersion)" -ForegroundColor Gray 
            }
        } else {
            Write-Host "  [NO] $path" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "DPTF - Programmi installati:" -ForegroundColor Magenta
    $debugDptfPkg = Get-Package "*Dynamic*","*DPTF*","*Thermal*" 2>$null | Where-Object { $_.Name -like "*Intel*" -or $_.Name -like "*Tuning*" }
    if ($debugDptfPkg) {
        $debugDptfPkg | ForEach-Object { Write-Host "  [TROVATO] $($_.Name) v$($_.Version)" -ForegroundColor Green }
    } else {
        Write-Host "  (nessun programma DPTF/DTT trovato)" -ForegroundColor Gray
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
        $debugDtt | ForEach-Object { Write-Host "  [TROVATO] $($_.DeviceName) | $($_.DriverVersion) | $($_.InfName)" -ForegroundColor Green }
    } else {
        Write-Host "  (nessun driver DPTF in Device Manager - normale per Acer!)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Killer - Pacchetti:" -ForegroundColor Magenta
    $debugKiller = Get-Package "*Killer*" 2>$null
    if ($debugKiller) {
        $debugKiller | ForEach-Object { 
            $isDriver = $_.Name -like "*Driver*" -or $_.Name -like "*WiFi*" -or $_.Name -like "*Wireless*"
            $tag = if ($isDriver) { "[DRIVER - OK]" } else { "[SOFTWARE]" }
            $color = if ($isDriver) { "Green" } else { "Yellow" }
            Write-Host "  $tag $($_.Name)" -ForegroundColor $color
        }
    } else {
        Write-Host "  (nessun pacchetto Killer)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Killer - Servizi:" -ForegroundColor Magenta
    $debugKillerSvc = Get-Service "*Killer*" 2>$null
    if ($debugKillerSvc) {
        $debugKillerSvc | ForEach-Object { Write-Host "  - $($_.Name): $($_.Status)" -ForegroundColor Gray }
    } else {
        Write-Host "  (nessun servizio Killer)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=== FINE DEBUG ===" -ForegroundColor Magenta
    Write-Host ""
}

# ============================================================================
# SEZIONE 1: DRIVER CRITICI
# ============================================================================

Write-Host "-- DRIVER CRITICI --" -ForegroundColor Cyan
Write-Host ""

# 1. Intel PPM (FIX JIHAKKIM - PIU IMPORTANTE!)
$intelppmKey = "HKLM:\SYSTEM\CurrentControlSet\Services\intelppm"
$intelppmStart = (Get-ItemProperty $intelppmKey -Name Start -EA 0).Start

if ($intelppmStart -eq 4) {
    Write-Check "Intel PPM (intelppm)" "OK" "DISABILITATO (Start=4) - fix jihakkim attivo"
} elseif ($intelppmStart -eq 3) {
    Write-Check "Intel PPM (intelppm)" "ERR" "ATTIVO (Start=3) - CAUSA CLOCK_WATCHDOG_TIMEOUT!"
} else {
    Write-Check "Intel PPM (intelppm)" "WARN" "Start=$intelppmStart - stato sconosciuto"
}

# 2. DTT/DPTF - RILEVAMENTO MULTIPLO
# NOTA: Il pacchetto DPTF Acer spesso NON appare in Device Manager!

$dptfFound = $false
$dptfVersion = ""
$dptfSource = ""

# Metodo 1: Servizio ESIF
$esifSvc = Get-Service "esifsvc*" 2>$null
if ($esifSvc) {
    $dptfFound = $true
    $dptfSource = "servizio $($esifSvc.Name)"
}

# Metodo 2: Cartella installazione
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
            $dptfSource = "cartella"
        }
        break
    }
}

# Metodo 3: Programmi installati
$installedDptf = Get-Package "*Dynamic Tuning*","*DPTF*","*Thermal Framework*" 2>$null | Select-Object -First 1
if ($installedDptf) {
    $dptfFound = $true
    if (!$dptfVersion) { $dptfVersion = $installedDptf.Version }
    $dptfSource = "programma"
}

# Metodo 4: Device Manager (fallback)
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

# Valuta risultato
if ($dptfFound) {
    if ($dptfVersion) {
        if ($dptfVersion -match "11404|11401|11400|11399") {
            Write-Check "Intel DPTF/DTT" "OK" "$dptfVersion (stabile)"
        } elseif ($dptfVersion -match "11405|11406|11407|117|118|119") {
            Write-Check "Intel DPTF/DTT" "ERR" "$dptfVersion (CAUSA BSOD!)"
        } else {
            Write-Check "Intel DPTF/DTT" "WARN" "$dptfVersion"
        }
    } else {
        Write-Check "Intel DPTF/DTT" "OK" "Installato ($dptfSource)"
    }
} else {
    Write-Check "Intel DPTF/DTT" "WARN" "Non installato"
}

# 3. IPF
$ipf = $drivers | Where-Object { 
    $_.DeviceName -like "*Innovation Platform*" -or 
    $_.InfName -like "*ipf*"
} | Select-Object -First 1

if ($ipf) {
    $ver = $ipf.DriverVersion
    if ($ver -match "11404|11401|11400") {
        Write-Check "Intel IPF" "OK" "$ver (stabile)"
    } elseif ($ver -match "11405|11406|117|118|119") {
        Write-Check "Intel IPF" "ERR" "$ver (versione problematica)"
    } else {
        Write-Check "Intel IPF" "WARN" "$ver"
    }
} else {
    Write-Check "Intel IPF" "WARN" "Non installato"
}

# 4. GNA (deve essere ASSENTE)
$gna = $drivers | Where-Object { 
    $_.DeviceName -like "*GNA*" -or 
    $_.DeviceName -like "*Gaussian*" -or
    $_.InfName -like "*gna*"
}
$gnaDevice = Get-PnpDevice -FriendlyName "*GNA*","*Gaussian*" 2>$null

if ($gna -or $gnaDevice) {
    $gnaStatus = if ($gnaDevice.Status -eq "Error" -or $gnaDevice.Status -eq "Degraded") { "disabilitato" } else { "ATTIVO" }
    if ($gnaStatus -eq "disabilitato") {
        Write-Check "Intel GNA" "OK" "Presente ma disabilitato"
    } else {
        Write-Check "Intel GNA" "ERR" "PRESENTE E ATTIVO - causa BSOD! Disabilitare!"
    }
} else {
    Write-Check "Intel GNA" "OK" "Non presente (corretto)"
}

# 5. HID Event Filter
$hid = $drivers | Where-Object { 
    $_.DeviceName -like "*HID Event Filter*" -or
    $_.InfName -match "INTC1070|heci"
}
$hidDevice = Get-PnpDevice | Where-Object { $_.InstanceId -like "*INTC1070*" } 2>$null

if ($hid -or $hidDevice) {
    $hidStatus = if ($hidDevice.Status -eq "Error" -or $hidDevice.Status -eq "Degraded") { "disabilitato" } else { "attivo" }
    if ($hidStatus -eq "disabilitato") {
        Write-Check "Intel HID Event Filter" "OK" "Disabilitato"
    } else {
        Write-Check "Intel HID Event Filter" "WARN" "Attivo - potrebbe causare freeze"
    }
} else {
    Write-Check "Intel HID Event Filter" "OK" "Non presente"
}

Write-Host ""

# ============================================================================
# SEZIONE 2: BLOATWARE
# ============================================================================

Write-Host "-- BLOATWARE --" -ForegroundColor Cyan
Write-Host ""

# Killer SOFTWARE (non il driver WiFi!)
# NOTA: Intel Killer AX1675i è il chip WiFi - il driver è necessario
# Cerca SOLO il software bloatware, NON i driver
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
        Write-Check "Killer SOFTWARE" "WARN" "$swNames - bloatware opzionale"
    } else {
        Write-Check "Killer SOFTWARE" "WARN" "Servizi in esecuzione - bloatware opzionale"
    }
} else {
    Write-Check "Killer SOFTWARE" "OK" "Non presente"
}

# Verifica che il driver WiFi sia presente
$wifiKiller = $drivers | Where-Object { $_.DeviceName -like "*Killer*Wi-Fi*" -or $_.DeviceName -like "*Killer*Wireless*" }
if ($wifiKiller) {
    Write-Check "Driver WiFi Killer" "OK" "Presente (necessario per AX1675i)"
}

Write-Host ""

# ============================================================================
# SEZIONE 3: BLOCCHI WINDOWS UPDATE
# ============================================================================

Write-Host "-- BLOCCHI WINDOWS UPDATE --" -ForegroundColor Cyan
Write-Host ""

# ExcludeWUDriversInQualityUpdate
$wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$excludeWU = (Get-ItemProperty $wuKey -Name "ExcludeWUDriversInQualityUpdate" -EA 0).ExcludeWUDriversInQualityUpdate

if ($excludeWU -eq 1) {
    Write-Check "ExcludeWUDriversInQualityUpdate" "OK" "Attivo (driver bloccati da WU)"
} else {
    Write-Check "ExcludeWUDriversInQualityUpdate" "WARN" "Non attivo - WU puo reinstallare driver"
}

# SearchOrderConfig
$dsKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
$searchOrder = (Get-ItemProperty $dsKey -Name "SearchOrderConfig" -EA 0).SearchOrderConfig

if ($searchOrder -eq 0) {
    Write-Check "SearchOrderConfig" "OK" "= 0 (ricerca driver online disabilitata)"
} else {
    Write-Check "SearchOrderConfig" "WARN" "= $searchOrder (ricerca driver online attiva)"
}

# Hardware ID bloccati
$denyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs"
$blockedCount = 0
if (Test-Path $denyKey) {
    $blockedCount = (Get-Item $denyKey).Property.Count
}

if ($blockedCount -ge 50) {
    Write-Check "Hardware ID bloccati" "OK" "$blockedCount dispositivi (tutti i driver protetti)"
} elseif ($blockedCount -gt 0) {
    Write-Check "Hardware ID bloccati" "WARN" "$blockedCount dispositivi (potrebbero servire piu' blocchi)"
} else {
    Write-Check "Hardware ID bloccati" "WARN" "Nessun blocco - WU puo' sovrascrivere i driver"
}

Write-Host ""

# ============================================================================
# SEZIONE 4: DRIVER ESSENZIALI
# ============================================================================

Write-Host "-- DRIVER ESSENZIALI --" -ForegroundColor Cyan
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
    Write-Check "Intel Graphics" "WARN" "Non trovato - installare VGA Intel UMA"
}

# NVIDIA
$nvidia = $drivers | Where-Object { 
    $_.DeviceName -like "*NVIDIA*" -or 
    $_.DeviceName -like "*GeForce*"
} | Select-Object -First 1

if ($nvidia) {
    Write-Check "NVIDIA GPU" "OK" "$($nvidia.DriverVersion)"
} else {
    Write-Check "NVIDIA GPU" "ERR" "Non trovato!"
}

# WiFi
$wifi = $drivers | Where-Object { 
    $_.DeviceName -like "*Wi-Fi*" -or 
    $_.DeviceName -like "*Wireless*" -or
    $_.DeviceName -like "*WLAN*"
} | Select-Object -First 1

if ($wifi) {
    # Intel Killer AX1675i è il chip standard - va bene!
    Write-Check "WiFi" "OK" "$($wifi.DeviceName)"
} else {
    Write-Check "WiFi" "ERR" "Non trovato!"
}

# Serial IO / Touchpad
$serialio = $drivers | Where-Object { 
    $_.InfName -like "*iaLPSS*" -or 
    $_.DeviceName -like "*Serial IO*" -or
    $_.DeviceName -like "*I2C*"
}

if ($serialio -and $serialio.Count -gt 0) {
    Write-Check "Serial IO (touchpad)" "OK" "$($serialio.Count) driver"
} else {
    Write-Check "Serial IO (touchpad)" "WARN" "Non trovato - potrebbe mancare supporto touchpad"
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
    Write-Check "Intel ME" "WARN" "Non trovato"
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
    Write-Check "LAN Ethernet" "WARN" "Non trovato"
}

# Audio
$audio = $drivers | Where-Object { 
    $_.DeviceName -like "*Realtek*" -or 
    $_.DeviceName -like "*High Definition Audio*"
} | Select-Object -First 1

if ($audio) {
    Write-Check "Audio" "OK" "$($audio.DeviceName)"
} else {
    Write-Check "Audio" "WARN" "Non trovato"
}

Write-Host ""

# ============================================================================
# RIEPILOGO
# ============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "                         RIEPILOGO" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  OK:       $OK" -ForegroundColor Green
Write-Host "  Warning:  $WARN" -ForegroundColor Yellow
Write-Host "  Errori:   $ERR" -ForegroundColor Red
Write-Host ""

if ($ERR -eq 0 -and $WARN -le 2) {
    Write-Host "  STATO: Sistema configurato correttamente!" -ForegroundColor Green
    Write-Host "         I BSOD dovrebbero essere risolti." -ForegroundColor Green
} elseif ($ERR -eq 0) {
    Write-Host "  STATO: Sistema OK con alcuni warning" -ForegroundColor Yellow
    Write-Host "         Verifica i warning sopra se hai ancora problemi." -ForegroundColor Yellow
} else {
    Write-Host "  STATO: PROBLEMI RILEVATI!" -ForegroundColor Red
    Write-Host "         Esegui HeliosPHN16-72_Setup.ps1 per applicare i fix." -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan

# Mostra azioni consigliate se ci sono errori
if ($ERR -gt 0) {
    Write-Host ""
    Write-Host "  AZIONI CONSIGLIATE:" -ForegroundColor Yellow
    
    # Check specifici
    if ($intelppmStart -ne 4) {
        Write-Host "  - Esegui Setup.ps1 per disabilitare Intel PPM" -ForegroundColor White
    }
    
    $gnaActive = Get-PnpDevice -FriendlyName "*GNA*","*Gaussian*" 2>$null | Where-Object { $_.Status -eq "OK" }
    if ($gnaActive) {
        Write-Host "  - Esegui Setup.ps1 per disabilitare GNA" -ForegroundColor White
    }
    
    if ($dtt -and $dtt.DriverVersion -match "11405|11406|117|118|119") {
        Write-Host "  - Rimuovi DTT e installa DPTF(APO) v1.0.11401 da Acer" -ForegroundColor White
    }
    
    Write-Host ""
}

Write-Host ""

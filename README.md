# Acer Predator Helios Neo 16 (PHN16-72) BSOD Fix

![Windows 11](https://img.shields.io/badge/Windows-11-blue?logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![License](https://img.shields.io/badge/License-MIT-green)

🔧 **Script automatizzato per risolvere i BSOD su Acer Predator Helios Neo 16 (PHN16-72) con CPU Intel 14th Gen**

## 🚨 Il Problema

I laptop Acer Predator Helios Neo 16 (PHN16-72) con processori Intel di 14ª generazione soffrono di frequenti BSOD (Blue Screen of Death) causati da driver Intel difettosi:

| Errore BSOD | Causa |
|-------------|-------|
| `CLOCK_WATCHDOG_TIMEOUT` | Intel PPM (intelppm.sys) |
| `SYSTEM_SERVICE_EXCEPTION` | Intel DTT/DPTF (dtt_sw.inf) |
| `KERNEL_MODE_HEAP_CORRUPTION` | Intel GNA (gna.inf) |
| System Freeze | Intel HID Event Filter (INTC1070) |

## ✅ La Soluzione

Questo script implementa le soluzioni documentate dalla **Community Acer**:

- 🔗 [artkirius - SOLVED](https://community.acer.com/en/discussion/723737) - Identificazione driver problematici
- 🔗 [jihakkim - intelppm fix](https://community.acer.com/en/discussion/728746) - Fix CLOCK_WATCHDOG_TIMEOUT (2+ settimane senza BSOD)
- 🔗 [Puraw - clean install](https://community.acer.com/en/discussion/728578) - Ordine installazione driver
- 🔗 [StevenGen - setup guide](https://community.acer.com/en/discussion/726672) - Configurazione BIOS

## 🚀 Quick Start

### 1. Scarica i driver da Acer

👉 **Vai su:** [https://www.acer.com/it-it/support/product-support/Predator_PHN16-72](https://www.acer.com/it-it/support/product-support/Predator_PHN16-72)

📁 **Salva TUTTI i file ZIP in:**
```
C:\Users\TUONOME\Downloads\AcerDrivers_PHN16-72\
```

> ⚠️ **IMPORTANTE:** Crea la cartella `AcerDrivers_PHN16-72` dentro Downloads e metti lì tutti i driver ZIP senza estrarli!

| Driver | Note |
|--------|------|
| ✅ Chipset Intel | Serial IO, I2C |
| ✅ ME | Intel Management Engine |
| ✅ DPTF | ⚠️ **SENZA APO!** Versione 11401 |
| ✅ VGA Intel UMA | Grafica integrata |
| ✅ Audio Realtek | |
| ✅ LAN | **SENZA Killer Control Centre!** E3100G |
| ✅ Wireless LAN | **SENZA 1675i!** |
| ✅ Bluetooth | Se necessario |
| ❌ GNA | **NON scaricare!** |
| ❌ HID Event Filter | **NON scaricare!** |

> ⚠️ **IMPORTANTE:** Non scaricare DPTF (APO)! La versione APO richiede DTT 11405+ che causa BSOD.

### 2. Esegui lo script

```powershell
# Apri PowerShell come Amministratore
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\HeliosPHN16-72_Setup.ps1
```

### 3. Segui le istruzioni

Lo script:
1. Disabilita Intel PPM (fix CLOCK_WATCHDOG_TIMEOUT)
2. Rimuove driver problematici (GNA, HID, DTT obsoleto)
3. Blocca Windows Update per questi driver
4. Pulisce driver esistenti
5. Installa nuovi driver nell'ordine corretto
6. Ti chiede di installare NVIDIA al momento giusto
7. Genera script di rollback

### 4. Riavvia e verifica

```powershell
.\HeliosPHN16-72_Check.ps1
```

## 📋 Cosa fa lo script

### Fix applicati

| Fix | Descrizione |
|-----|-------------|
| **intelppm** | Registry `Start=4` (disabilita Intel PPM) |
| **GNA** | Rimozione completa + blocco Hardware ID |
| **HID Filter** | Disabilitazione dispositivo |
| **DTT/DPTF** | Rimozione versioni >11404 |
| **Windows Update** | Blocco aggiornamenti driver per ~100 Hardware ID |

### Ordine installazione driver

```
1. Chipset Intel    (base per touchpad, I2C)
2. ME               (Management Engine)
3. DPTF             (Thermal - versione 11401!)
4. VGA Intel UMA    (grafica integrata)
5. >>> NVIDIA <<<   (manuale - lo script si ferma qui)
6. Audio Realtek
7. LAN Ethernet
8. WiFi
9. Bluetooth
```

### File generati

| File | Posizione |
|------|-----------|
| Log | `Desktop\PHN16-72_Setup_*.log` |
| Rollback | `Desktop\PHN16-72_ROLLBACK.ps1` |
| Guida HTML | `Downloads\AcerDrivers_PHN16-72\GUIDA_DRIVER.html` |

## 🛠️ Opzioni avanzate

```powershell
# Mostra cosa farebbe senza eseguire
.\HeliosPHN16-72_Setup.ps1 -DryRun

# Salta fix intelppm
.\HeliosPHN16-72_Setup.ps1 -SkipIntelppmFix

# Salta download guide
.\HeliosPHN16-72_Setup.ps1 -SkipDownload

# Salta installazione driver
.\HeliosPHN16-72_Setup.ps1 -SkipInstall

# Check con info debug
.\HeliosPHN16-72_Check.ps1 -Debug
```

## ⚠️ Driver da evitare

| Driver | Motivo | Azione |
|--------|--------|--------|
| Intel GNA | BSOD vari | Bloccare sempre |
| Intel DPTF (APO) | Richiede DTT 11405+ | Non installare |
| Intel DTT 11405+ | Crash termici | Usare 11401 |
| Intel HID Event Filter | Freeze sistema | Disabilitare |

## 🔄 Rollback

Se qualcosa va storto:

```powershell
.\PHN16-72_ROLLBACK.ps1
```

Questo ripristina:
- Intel PPM (Start=3)
- Rimuove blocchi Windows Update

## 📊 Versioni driver stabili

| Driver | Versione stabile |
|--------|------------------|
| DTT | 9.0.11404.39881 o precedenti |
| DPTF Acer | 1.0.11401.39039 |
| IPF | 1.0.11404.41023 o precedenti |

## 🤝 Contributi

Questo progetto è basato sulle soluzioni condivise dalla Community Acer. Se hai trovato altri fix, apri una Issue o Pull Request!

## 📜 Licenza

MIT License - Vedi [LICENSE](LICENSE)

## ⚡ Credits

- **artkirius** - Identificazione driver problematici
- **jihakkim** - Fix intelppm (CLOCK_WATCHDOG_TIMEOUT)
- **Puraw** - Guida clean install
- **StevenGen** - Setup guide
- **Community Acer** - Test e feedback

---

<p align="center">
  <b>Se questo script ti ha aiutato, lascia una ⭐ sul repo!</b>
</p>

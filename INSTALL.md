# 🚀 Installazione Rapida

## Step 1: Scarica i driver

👉 **Vai su:** [https://www.acer.com/it-it/support/product-support/Predator_PHN16-72](https://www.acer.com/it-it/support/product-support/Predator_PHN16-72)

📁 **Crea questa cartella:**
```
C:\Users\TUONOME\Downloads\AcerDrivers_PHN16-72\
```

📥 **Scarica questi driver e salvali nella cartella (NON estrarre i ZIP!):**

- [ ] Chipset Intel
- [ ] ME (Management Engine)
- [ ] DPTF (**NON APO!** versione 11401)
- [ ] VGA Intel UMA (**installazione manuale** - lo script ti guida)
- [ ] Audio Realtek
- [ ] LAN E3100G (**SENZA Killer Control Centre!**)
- [ ] Wireless LAN (**SENZA 1675i!**)
- [ ] Bluetooth

**NON scaricare:** GNA, HID Event Filter, DPTF (APO), versioni con Killer Control Centre o 1675i

## Step 2: Scarica lo script

### Metodo A: Download ZIP da GitHub

1. Clicca **Code** → **Download ZIP**
2. Estrai in una cartella (es. `C:\Tools\PHN16-72-Fix\`)

### Metodo B: Git Clone

```powershell
git clone https://github.com/TUOUSERNAME/PHN16-72-BSOD-Fix.git
cd PHN16-72-BSOD-Fix
```

## Step 3: Esegui lo script

1. Apri **PowerShell come Amministratore**
2. Esegui:

```powershell
cd "C:\Tools\PHN16-72-Fix"   # o dove hai estratto lo script
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\HeliosPHN16-72_Setup.ps1
```

3. Segui le istruzioni a schermo
4. Quando richiesto, installa **VGA Intel** manualmente (via Device Manager)
5. Quando richiesto, installa **NVIDIA** manualmente
6. **RIAVVIA** il PC
7. Verifica con `.\HeliosPHN16-72_Check.ps1`

---

## ⚠️ Requisiti

- Windows 10/11
- PowerShell 5.1+
- Eseguire come **Amministratore**
- Driver scaricati da Acer nella cartella corretta

## 📁 Struttura cartelle

```
C:\Users\TUONOME\
└── Downloads\
    └── AcerDrivers_PHN16-72\      ← CREA QUESTA CARTELLA
        ├── Chipset_Intel_xxx.zip   ← Driver ZIP (non estratti)
        ├── ME_Intel_xxx.zip
        ├── DPTF_xxx.zip            ← Versione SENZA APO!
        ├── VGA_Intel_UMA_xxx.zip   ← Installazione MANUALE (lo script ti guida)
        ├── Audio_Realtek_xxx.zip
        ├── LAN_xxx.zip
        ├── WLAN_xxx.zip
        └── Bluetooth_xxx.zip
```

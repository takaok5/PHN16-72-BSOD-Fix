# ❓ FAQ - Domande Frequenti

## Generale

### Funziona anche per PHN16-71?
Probabilmente sì, ma non è stato testato. Il PHN16-71 ha hardware simile (Intel 13th Gen). Prova con cautela.

### Funziona per altri laptop Acer/Predator?
Potenzialmente per laptop con Intel 13th/14th Gen e stessi driver problematici. Verifica i tuoi BSOD prima.

### Perdo la garanzia?
No. Lo script modifica solo driver e impostazioni software, non hardware o BIOS.

---

## Driver

### Qual è la differenza tra DPTF e DPTF (APO)?
- **DPTF (senza APO):** Versione 11401 - STABILE ✅
- **DPTF (APO):** Richiede DTT 11405+ che causa BSOD ❌

APO = Application Optimization, una feature Intel che richiede versioni più recenti del driver.

### Perché non installare GNA?
Intel GNA (Gaussian Neural Accelerator) è usato per AI/ML ma su questi laptop causa BSOD frequenti. Non è necessario per il gaming.

### Il driver Killer WiFi è necessario?
Sì! Intel ha acquisito Killer. Il chip WiFi AX1675i è un chip Intel marchiato Killer. Il driver è necessario.

Il **bloatware** da evitare è il software "Killer Control Center", non il driver.

### Posso usare driver più recenti di quelli consigliati?
Sconsigliato. Le versioni consigliate (11401/11404) sono state testate dalla community come stabili. Versioni successive possono reintrodurre i BSOD.

---

## Problemi comuni

### Lo script dice "Nessun ZIP trovato"
Assicurati di aver salvato i driver nella cartella corretta:
```
C:\Users\%USERNAME%\Downloads\AcerDrivers_PHN16-72\
```

### "Impossibile caricare il file ... perché l'esecuzione di script è disabilitata"
Esegui prima:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Il touchpad non funziona dopo l'installazione
Il driver Chipset (Serial IO) deve essere installato **prima** degli altri. Riavvia dopo l'installazione.

### BSOD continua dopo lo script
1. Esegui `.\HeliosPHN16-72_Check.ps1 -Debug` e verifica tutti i fix
2. Controlla se Windows Update ha reinstallato driver (devono essere bloccati ~100 HW ID)
3. Verifica di aver installato DPTF versione 11401, **non** 11405+

### Windows Update reinstalla i driver
Lo script blocca Windows Update per i driver, ma verifica che:
- `ExcludeWUDriversInQualityUpdate = 1`
- `SearchOrderConfig = 0`
- Hardware ID bloccati ≥ 50

---

## BIOS

### Devo modificare il BIOS?
Non obbligatorio, ma consigliato:
- Aggiorna all'ultima versione BIOS
- In BIOS: usa **SOLO GPU NVIDIA** per output video (se possibile)

### Il BIOS si è resettato dopo un aggiornamento
È normale. Riconfigura le impostazioni e riesegui lo script.

---

## Rollback

### Come annullo le modifiche?
```powershell
.\PHN16-72_ROLLBACK.ps1
```

### Il rollback ripristina i vecchi driver?
No, ripristina solo:
- Intel PPM (riattiva)
- Blocchi Windows Update (rimuove)

I driver devono essere reinstallati manualmente se necessario.

---

## Altro

### Posso contribuire?
Sì! Apri Issue o Pull Request su GitHub.

### Ho trovato un altro fix
Fantastico! Condividilo aprendo una Issue con:
- Modello esatto laptop
- BSOD che avevi
- Fix applicato
- Risultato

### Lo script è sicuro?
Sì. Puoi esaminare il codice - è tutto PowerShell leggibile. Non modifica il BIOS, non installa software di terze parti, non invia dati.

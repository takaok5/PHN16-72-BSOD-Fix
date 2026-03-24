# FAQ

## General

### Does this work for PHN16-71?
Possibly. The PHN16-71 has similar hardware (Intel 13th Gen). The driver cleanup script should work, but PredatorGuard profiles are tuned for the i9-14900HX.

### Does this work for other Acer/Predator laptops?
The driver fixes (GNA, HID, DPTF) may apply to other Intel 13th/14th Gen Acer laptops. Check your BSOD logs first.

### Does this void my warranty?
No. Everything here modifies software/drivers only, not hardware or BIOS.

---

## BIOS & intelppm

### Do I need to disable intelppm?
**No, not anymore.** The latest Acer BIOS update for PHN16-72 fixes the intelppm conflict. With the updated BIOS, Intel PPM works correctly.

If you previously disabled intelppm with the setup script, you can re-enable it:
```powershell
# Re-enable intelppm
reg add "HKLM\SYSTEM\CurrentControlSet\Services\intelppm" /v Start /t REG_DWORD /d 3 /f
# Then reboot
```

### Should I still use PredatorGuard?
Yes. Even with the fixed BIOS, PredatorSense still writes to MSR 0x610 (power limit registers). Locking these registers prevents instability and ensures consistent power management.

### Should I update my BIOS?
Yes. Update to the latest BIOS from [Acer Support](https://www.acer.com/it-it/support/product-support/Predator_PHN16-72) before doing anything else.

---

## Drivers

### What's the difference between DPTF and DPTF (APO)?
- **DPTF (without APO):** Version 11401 — stable
- **DPTF (APO):** Requires DTT 11405+ which causes BSOD

APO = Application Optimization, an Intel feature that requires newer (unstable) driver versions.

### Why remove GNA?
Intel GNA (Gaussian Neural Accelerator) is used for AI/ML but causes frequent BSOD on these laptops. Not needed for gaming.

### Is the Killer WiFi driver needed?
Yes. Intel acquired Killer. The AX1675i WiFi chip is an Intel chip branded as Killer. The driver is needed.

The **bloatware** to avoid is "Killer Control Center" software, not the driver itself.

---

## Troubleshooting

### Script says "No ZIP found"
Make sure drivers are saved in:
```
%USERPROFILE%\Downloads\AcerDrivers_PHN16-72\
```

### "Script execution is disabled"
Run first:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Touchpad not working after install
The Chipset driver (Serial IO) must be installed **first**. Reboot after installation.

### BSOD continues after running the script
1. **Update BIOS first** — this is the most important step
2. Run `.\HeliosPHN16-72_Check.ps1 -Debug` to verify all fixes
3. Check if Windows Update reinstalled drivers
4. Make sure you installed DPTF version 11401, **not** 11405+
5. Run PredatorGuard to lock MSR registers

---

## Rollback

### How do I undo the changes?
```powershell
.\PHN16-72_ROLLBACK.ps1
```

This restores:
- Intel PPM (re-enables)
- Windows Update blocks (removes)

Drivers must be reinstalled manually if needed.

---

## Contributing

Found another fix? Open an Issue with:
- Exact laptop model
- BSOD error you had
- Fix applied
- Result

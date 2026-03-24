# Installation

## Step 0: Update BIOS

**Do this first.** Download and install the latest BIOS from [Acer Support](https://www.acer.com/it-it/support/product-support/Predator_PHN16-72). The latest BIOS fixes the intelppm conflict that caused most BSOD crashes.

## Step 1: Download drivers from Acer

Go to: [Acer Support - Predator PHN16-72](https://www.acer.com/it-it/support/product-support/Predator_PHN16-72)

Create this folder and save all driver ZIPs there (don't extract):
```
%USERPROFILE%\Downloads\AcerDrivers_PHN16-72\
```

| Download | Notes |
|----------|-------|
| Chipset Intel | Serial IO, I2C |
| ME | Intel Management Engine |
| DPTF | **NOT APO!** Version 11401 |
| VGA Intel UMA | **Manual install** (script guides you) |
| Audio Realtek | |
| LAN | **WITHOUT Killer Control Centre!** E3100G |
| Wireless LAN | **WITHOUT 1675i!** |
| Bluetooth | If needed |

**DO NOT download:** GNA, HID Event Filter, DPTF (APO)

## Step 2: Run the driver setup script

```powershell
git clone https://github.com/takaok5/PHN16-72-BSOD-Fix.git
cd PHN16-72-BSOD-Fix
```

Or download ZIP from GitHub: **Code** > **Download ZIP**

```powershell
# Open PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# With new BIOS, skip the intelppm fix (no longer needed)
.\HeliosPHN16-72_Setup.ps1 -SkipIntelppmFix
```

Follow the on-screen instructions. The script will:
1. Remove problematic drivers (GNA, HID, obsolete DTT)
2. Block Windows Update from reinstalling them
3. Install stable driver versions in the correct order
4. Guide you to manually install Intel VGA and NVIDIA

## Step 3: Reboot and verify

```powershell
.\HeliosPHN16-72_Check.ps1
```

## Step 4 (Optional): Install PredatorGuard

PredatorGuard locks MSR registers so PredatorSense can't overwrite CPU power limits. Recommended even with the new BIOS.

1. Build: `cd PredatorGuard && dotnet publish -c Release`
2. Place `WinRing0x64.dll` + `WinRing0x64.sys` next to the executable
3. Run: `PredatorGuard.exe --lock-only`
4. Set up Task Scheduler to run at boot (see [PredatorGuard README](PredatorGuard/README.md))

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Administrator privileges
- Latest Acer BIOS (recommended)

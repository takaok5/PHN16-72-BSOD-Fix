# Acer Predator Helios Neo 16 (PHN16-72) — Stability Toolkit

![Windows 11](https://img.shields.io/badge/Windows-11-blue?logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![.NET 10](https://img.shields.io/badge/.NET-10-purple?logo=dotnet)
![License](https://img.shields.io/badge/License-MIT-green)

A collection of tools to fix BSOD crashes and improve stability on the Acer Predator Helios Neo 16 (PHN16-72) with Intel 14th Gen CPUs (i9-14900HX).

## Current Status (2025+)

**Good news:** Acer has released a BIOS update that fixes the `intelppm.sys` conflict. With the latest BIOS, Intel PPM works correctly and no longer needs to be disabled.

**What still matters:**
- **PredatorGuard** — Locks MSR registers to prevent PredatorSense from overwriting CPU power limits (still needed even with new BIOS)
- **PredatorMonitor** — System tray app for temperature/fan monitoring via Acer WMI
- **Driver setup script** — Removes known-bad drivers (GNA, HID Event Filter, DPTF APO) and blocks Windows Update from reinstalling them

## Repository Structure

| Component | What it does |
|-----------|-------------|
| [`PredatorGuard/`](PredatorGuard/) | MSR lock tool — writes safe power limits and locks them so PredatorSense can't cause conflicts |
| [`PredatorMonitor/`](PredatorMonitor/) | System tray app — CPU/GPU temps, fan RPM, fan control, PredatorSense profile detection |
| `HeliosPHN16-72_Setup.ps1` | Driver cleanup script — removes bad drivers, blocks WU reinstall, installs stable versions |
| `HeliosPHN16-72_Check.ps1` | Verification script — checks all fixes are applied |

---

## PredatorGuard — MSR Lock Tool

PredatorSense writes CPU power limit registers (MSR 0x610) at runtime. Even with the new BIOS, these writes can cause instability when they conflict with the OS power manager. PredatorGuard:

1. **Writes safe PL1/PL2 power limits** to MSR 0x610 (from proven ThrottleStop config)
2. **Sets the hardware LOCK bit** (bit 63) — CPU ignores all further writes until reboot
3. **Caps turbo boost at 5.4 GHz** via MSR 0x1AD (stock 5.8 GHz causes unnecessary power spikes)
4. **Configures Speed Shift** (HWP) with proper EPP per profile

```bash
PredatorGuard.exe                  # Apply Performance profile + lock
PredatorGuard.exe --profile game   # Apply Game profile
PredatorGuard.exe --lock-only      # Lock current values without changing
PredatorGuard.exe --status         # Show current MSR values
```

### Profiles (i9-14900HX)

| Profile | PL1 | PL2 | Max Freq | EPP | Turbo Cap |
|---------|-----|-----|----------|-----|-----------|
| **Performance** | 115W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Game** | 55W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Balanced** | 35W | 55W | 3.0 GHz | 128 (balanced) | Stock |
| **Battery** | 35W | 55W | 2.0 GHz | 200 (efficient) | Stock |

### Run at boot

```powershell
schtasks /create /tn "PredatorGuard" /tr "`"C:\path\to\PredatorGuard.exe`" --lock-only" /sc onstart /rl highest /ru SYSTEM /f
```

### WinRing0 Requirement

PredatorGuard requires [WinRing0](https://github.com/GermanAizek/WinRing0) for ring-0 MSR access. Place `WinRing0x64.dll` and `WinRing0x64.sys` next to the executable.

> **Note:** WinRing0x64.sys is on Microsoft's [Vulnerable Driver Blocklist](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/microsoft-recommended-driver-block-rules). If Memory Integrity (HVCI) is enabled, the driver won't load. You may need to disable it in Windows Security > Device Security > Core Isolation.

WinRing0 binaries are not included. Get them from [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/) or build from [source](https://github.com/GermanAizek/WinRing0).

See [PredatorGuard/README.md](PredatorGuard/README.md) for full details.

---

## PredatorMonitor — System Tray App

Lightweight monitoring via Acer WMI:
- CPU/GPU temperatures
- Fan RPM (both fans)
- PredatorSense profile detection (Quiet / Default / Performance / Turbo)
- Fan control (Auto, Turbo, manual %)
- Quick-launch ThrottleStop / OpenRGB

---

## Driver Setup Script (Legacy)

> **Note:** With the latest Acer BIOS, the intelppm fix (disabling Intel PPM) is **no longer needed**. The script still includes it as an option (`-SkipIntelppmFix` to skip), but the main value is now the cleanup of other bad drivers.

### What it does

| Fix | Description |
|-----|-------------|
| **GNA** | Removes Intel GNA driver + blocks reinstall |
| **HID Filter** | Disables Intel HID Event Filter (INTC1070) |
| **DTT/DPTF** | Removes DTT versions > 11404 |
| **Windows Update** | Blocks driver reinstall for ~100 Hardware IDs |
| **intelppm** | *(Optional)* Disables Intel PPM — no longer needed with new BIOS |

### Usage

```powershell
# Run with admin privileges
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\HeliosPHN16-72_Setup.ps1

# Skip the intelppm fix (recommended with new BIOS)
.\HeliosPHN16-72_Setup.ps1 -SkipIntelppmFix

# Dry run
.\HeliosPHN16-72_Setup.ps1 -DryRun

# Verify fixes
.\HeliosPHN16-72_Check.ps1
```

### Drivers to avoid

| Driver | Reason |
|--------|--------|
| Intel GNA | Various BSOD |
| Intel DPTF (APO) | Requires DTT 11405+ which crashes |
| Intel HID Event Filter | System freeze |

### Driver installation order

```
1. Chipset Intel    (base for touchpad, I2C)
2. ME               (Management Engine)
3. DPTF             (version 11401, NOT APO)
4. VGA Intel UMA    (manual install via Device Manager)
5. NVIDIA           (manual install)
6. Audio Realtek
7. LAN Ethernet
8. WiFi
9. Bluetooth
```

---

## BIOS

**Update your BIOS first.** The latest Acer BIOS for PHN16-72 fixes the intelppm conflict. After updating:

- Intel PPM can stay enabled (no need to disable)
- PredatorGuard is still recommended to lock MSR registers
- Driver cleanup (GNA, HID, DPTF APO) is still recommended

---

## License

MIT License — See [LICENSE](LICENSE)

## Credits

- **artkirius**, **jihakkim**, **Puraw**, **StevenGen** — Acer Community fixes and testing
- **[WinRing0](https://github.com/GermanAizek/WinRing0)** — Kernel driver for MSR access (original: [OpenLibSys](http://openlibsys.org/) by hiyohiyo, BSD License)
- **[ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/)** by Kevin Glynn — Reference MSR values and inspiration

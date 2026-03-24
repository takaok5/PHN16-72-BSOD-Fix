# Acer Predator Helios Neo 16 (PHN16-72) BSOD Fix

![Windows 11](https://img.shields.io/badge/Windows-11-blue?logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)
![.NET 10](https://img.shields.io/badge/.NET-10-purple?logo=dotnet)
![License](https://img.shields.io/badge/License-MIT-green)

**Automated toolkit to fix BSOD crashes on Acer Predator Helios Neo 16 (PHN16-72) with Intel 14th Gen CPUs.**

## Scope

This repository targets a **specific, well-documented hardware issue** affecting the Acer Predator Helios Neo 16 (PHN16-72) with Intel 14th Gen processors (i9-14900HX and similar). The BSOD crashes are caused by driver conflicts between PredatorSense, Intel PPM (`intelppm.sys`), and various Intel system drivers.

**What's included:**

| Component | Purpose |
|-----------|---------|
| `HeliosPHN16-72_Setup.ps1` | Automated driver fix: disables Intel PPM, removes bad drivers, blocks Windows Update |
| `HeliosPHN16-72_Check.ps1` | Verification script: checks all fixes are applied correctly |
| `PredatorGuard/` | MSR lock tool: prevents PredatorSense from writing conflicting CPU registers |
| `PredatorMonitor/` | System tray app: monitors CPU/GPU temps, fan control via Acer WMI |

**What's NOT included:** general PC tweaking, undervolting, overclocking tools. Each component solves one specific problem.

## The Problem

| BSOD Error | Cause |
|-------------|-------|
| `CLOCK_WATCHDOG_TIMEOUT` | Intel PPM (`intelppm.sys`) conflicts with PredatorSense MSR writes |
| `SYSTEM_SERVICE_EXCEPTION` | Intel DTT/DPTF (`dtt_sw.inf`) version mismatch |
| `KERNEL_MODE_HEAP_CORRUPTION` | Intel GNA (`gna.inf`) driver bug |
| System Freeze | Intel HID Event Filter (INTC1070) |
| `WHEA_UNCORRECTABLE_ERROR` | PredatorSense writing MSR 0x610 while `intelppm.sys` reads it |

## Solutions

Based on fixes documented by the **Acer Community**:

- [artkirius - SOLVED](https://community.acer.com/en/discussion/723737) - Identified problematic drivers
- [jihakkim - intelppm fix](https://community.acer.com/en/discussion/728746) - CLOCK_WATCHDOG_TIMEOUT fix (2+ weeks BSOD-free)
- [Puraw - clean install](https://community.acer.com/en/discussion/728578) - Driver installation order
- [StevenGen - setup guide](https://community.acer.com/en/discussion/726672) - BIOS configuration

---

## Quick Start: Driver Fix Script

### 1. Download drivers from Acer

Go to: [Acer Support - Predator PHN16-72](https://www.acer.com/it-it/support/product-support/Predator_PHN16-72)

Save all ZIP files (without extracting) to:
```
%USERPROFILE%\Downloads\AcerDrivers_PHN16-72\
```

| Driver | Notes |
|--------|------|
| Chipset Intel | Serial IO, I2C |
| ME | Intel Management Engine |
| DPTF | **NOT APO!** Version 11401 |
| VGA Intel UMA | **Manual install** (script guides you) |
| Audio Realtek | |
| LAN | **WITHOUT Killer Control Centre!** E3100G |
| Wireless LAN | **WITHOUT 1675i!** |
| Bluetooth | If needed |
| ~~GNA~~ | **DO NOT download** |
| ~~HID Event Filter~~ | **DO NOT download** |

> **IMPORTANT:** Do not download DPTF (APO). The APO version requires DTT 11405+ which causes BSOD.

### 2. Run the script

```powershell
# Open PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\HeliosPHN16-72_Setup.ps1
```

### 3. Follow instructions

The script:
1. Disables Intel PPM (fixes CLOCK_WATCHDOG_TIMEOUT)
2. Removes problematic drivers (GNA, HID, obsolete DTT)
3. Blocks Windows Update for these drivers
4. Cleans existing drivers
5. Installs new drivers in the correct order
6. Guides you to manually install **Intel VGA** (Parade MUX bug)
7. Guides you to manually install **NVIDIA**
8. Generates a rollback script

### 4. Reboot and verify

```powershell
.\HeliosPHN16-72_Check.ps1
```

---

## PredatorGuard: MSR Lock Tool

**Prevents the root cause of `WHEA_UNCORRECTABLE_ERROR` / `CLOCK_WATCHDOG_TIMEOUT`.**

PredatorSense writes CPU power limit registers (MSR 0x610) at runtime. These writes conflict with `intelppm.sys`, causing BSOD. PredatorGuard locks these registers using the hardware lock bit (bit 63), making them read-only until reboot.

Additionally, it **caps turbo boost at 5.4 GHz** (stock is 5.8 GHz) via MSR 0x1AD. This reduces the power spikes that trigger PredatorSense intervention.

```bash
# Apply Performance profile + lock all MSR registers
PredatorGuard.exe

# Apply Game profile
PredatorGuard.exe --profile game

# Lock current values without changing them
PredatorGuard.exe --lock-only

# Show current MSR register values
PredatorGuard.exe --status
```

### Profiles (i9-14900HX)

| Profile | PL1 | PL2 | Max Freq | EPP | Turbo Cap |
|---------|-----|-----|----------|-----|-----------|
| **Performance** | 115W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Game** | 55W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Balanced** | 35W | 55W | 3.0 GHz | 128 (balanced) | Stock |
| **Battery** | 35W | 55W | 2.0 GHz | 200 (efficient) | Stock |

### Run at boot (Task Scheduler)

```powershell
schtasks /create /tn "PredatorGuard" /tr "`"C:\path\to\PredatorGuard.exe`" --lock-only" /sc onstart /rl highest /ru SYSTEM /f
```

### WinRing0 Driver Requirement

PredatorGuard requires [WinRing0](https://github.com/GermanAizek/WinRing0) for ring-0 MSR access. Place `WinRing0x64.dll` and `WinRing0x64.sys` in the same directory as `PredatorGuard.exe`.

> **Windows 11 Warning:** WinRing0x64.sys is on Microsoft's [Vulnerable Driver Blocklist](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/microsoft-recommended-driver-block-rules) (CVE-2020-14979). If Memory Integrity (HVCI) is enabled, the driver will not load. You may need to disable Memory Integrity in Windows Security > Device Security > Core Isolation. **Understand the security implications before doing this.**

WinRing0 binaries are NOT included in this repository due to the vulnerable driver classification. You can:
- Build from source: [GermanAizek/WinRing0](https://github.com/GermanAizek/WinRing0)
- Extract from [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) or [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/) installation directories

See [PredatorGuard/README.md](PredatorGuard/README.md) for full documentation.

---

## PredatorMonitor: System Tray App

Lightweight tray app that monitors your Predator laptop via Acer WMI:
- CPU/GPU temperatures
- Fan RPM (both fans)
- PredatorSense profile detection
- Fan control (Auto, Turbo, manual %)
- Quick-launch ThrottleStop / OpenRGB

See [PredatorMonitor/](PredatorMonitor/) for details.

---

## Repository Structure

```
PHN16-72-BSOD-Fix/
├── HeliosPHN16-72_Setup.ps1    # Main fix script (PowerShell)
├── HeliosPHN16-72_Check.ps1    # Verification script
├── PredatorGuard/              # MSR lock tool (.NET 10, C#)
│   ├── MsrService.cs           # WinRing0 P/Invoke wrapper
│   ├── PowerConfig.cs          # Power profiles (PL1/PL2/EPP)
│   ├── Program.cs              # CLI entry point
│   └── ...
├── PredatorMonitor/            # System tray app (.NET 10, WinForms)
│   ├── AcerWmi.cs              # Acer WMI integration
│   ├── TrayContext.cs           # Tray icon + menu
│   └── ...
├── INSTALL.md                  # Step-by-step installation guide
├── FAQ.md                      # Frequently asked questions
└── LICENSE                     # MIT License
```

## Advanced Options

```powershell
# Dry run (show what would happen)
.\HeliosPHN16-72_Setup.ps1 -DryRun

# Skip intelppm fix
.\HeliosPHN16-72_Setup.ps1 -SkipIntelppmFix

# Skip driver installation
.\HeliosPHN16-72_Setup.ps1 -SkipInstall

# Debug check
.\HeliosPHN16-72_Check.ps1 -Debug
```

## Drivers to Avoid

| Driver | Reason | Action |
|--------|--------|--------|
| Intel GNA | Various BSOD | Always block |
| Intel DPTF (APO) | Requires DTT 11405+ | Do not install |
| Intel DTT 11405+ | Thermal crashes | Use 11401 |
| Intel HID Event Filter | System freeze | Disable |

## Stable Driver Versions

| Driver | Stable Version |
|--------|----------------|
| DTT | 9.0.11404.39881 or earlier |
| DPTF Acer | 1.0.11401.39039 |
| IPF | 1.0.11404.41023 or earlier |

## Rollback

If something goes wrong:
```powershell
.\PHN16-72_ROLLBACK.ps1
```

## License

MIT License - See [LICENSE](LICENSE)

## Credits

- **artkirius** - Identified problematic drivers
- **jihakkim** - intelppm fix (CLOCK_WATCHDOG_TIMEOUT)
- **Puraw** - Clean install guide
- **StevenGen** - Setup guide
- **Acer Community** - Testing and feedback
- **[WinRing0](https://github.com/GermanAizek/WinRing0)** - Kernel driver for MSR access (original: [OpenLibSys](http://openlibsys.org/) by hiyohiyo, BSD License)
- **[ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/)** by Kevin Glynn (unclewebb) - Reference MSR values and inspiration for PredatorGuard

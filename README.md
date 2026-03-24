# Acer Predator PHN16-72 — BSOD Fix & Stability Toolkit

![Windows 11](https://img.shields.io/badge/Windows-11-blue?logo=windows11)
![License](https://img.shields.io/badge/License-MIT-green)

Fixes BSOD crashes on Acer Predator Helios Neo 16 (PHN16-72) with Intel 14th Gen CPUs.

## What's in this repo

| Component | What it does |
|-----------|-------------|
| `HeliosPHN16-72_Setup.ps1` | Removes bad drivers (GNA, DPTF APO), blocks Windows Update reinstalls, installs stable versions |
| `HeliosPHN16-72_Check.ps1` | Verifies all fixes are applied |
| [`PredatorGuard/`](PredatorGuard/) | Locks CPU power registers (MSR) so PredatorSense can't cause instability |
| [`THROTTLESTOP.md`](THROTTLESTOP.md) | Manual alternative: ThrottleStop settings that achieve the same MSR lock |

## Prerequisites

**Update your BIOS first.** The latest Acer BIOS fixes the `intelppm.sys` conflict. Intel PPM no longer needs to be disabled.

## Quick Start

### 1. Run the driver cleanup script

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\HeliosPHN16-72_Setup.ps1
```

This removes known-bad drivers (GNA, DPTF APO, Killer bloatware), blocks Windows Update from reinstalling them, and installs stable driver versions in the correct order.

### 2. Lock MSR registers (choose one)

**Option A: PredatorGuard** (automated, open source)

```bash
PredatorGuard.exe --lock-only    # Lock current power limits
PredatorGuard.exe                # Apply Performance profile + lock
PredatorGuard.exe --profile game # Apply Game profile + lock
PredatorGuard.exe --status       # Show current MSR values
```

Set up Task Scheduler to run at boot:
```powershell
schtasks /create /tn "PredatorGuard" /tr "`"C:\path\to\PredatorGuard.exe`" --lock-only" /sc onstart /rl highest /ru SYSTEM /f
```

Requires [WinRing0](https://github.com/GermanAizek/WinRing0) driver. See [PredatorGuard/README.md](PredatorGuard/README.md).

> **Note:** WinRing0 is on Microsoft's Vulnerable Driver Blocklist. May require disabling Memory Integrity.

**Option B: ThrottleStop** (GUI, more features)

See [`THROTTLESTOP.md`](THROTTLESTOP.md) for the exact settings. Key points:
- TPL: PL1=115W, PL2=157W, **Lock=ON**
- Speed Shift: Min=4, **Max=54** (caps turbo at 5.4 GHz)
- EPP=0 (max performance)

![ThrottleStop Settings](docs/throttlestop-settings.png)

### 3. Verify

```powershell
.\HeliosPHN16-72_Check.ps1
```

## PredatorGuard Profiles (i9-14900HX)

| Profile | PL1 | PL2 | Max Freq | EPP | Turbo Cap |
|---------|-----|-----|----------|-----|-----------|
| **Performance** | 115W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Game** | 55W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Balanced** | 35W | 55W | 3.0 GHz | 128 | Stock |
| **Battery** | 35W | 55W | 2.0 GHz | 200 | Stock |

## Why this works

PredatorSense writes CPU power limit registers (MSR 0x610) at runtime. These writes can conflict with the OS power manager, causing BSOD. Both PredatorGuard and ThrottleStop solve this by:

1. Writing safe power limits to MSR 0x610
2. Setting bit 63 (hardware LOCK) — CPU ignores all subsequent writes until reboot
3. Capping turbo at 5.4 GHz (MSR 0x1AD) to reduce power spikes

## Drivers to avoid

| Driver | Reason |
|--------|--------|
| Intel GNA | Various BSOD |
| Intel DPTF (APO) | Requires DTT 11405+ which crashes |
| Killer Control Center | Bloatware (WiFi driver itself is fine) |

## Disclaimer

**USE AT YOUR OWN RISK.** This toolkit modifies Windows registry settings, removes/blocks system drivers, and writes to CPU Model-Specific Registers (MSR) via a kernel-level driver. While these changes have been tested and are based on documented community solutions, they involve low-level system modifications that could cause instability, data loss, or hardware issues if misapplied.

The authors assume **no responsibility** for any damage, data loss, hardware failure, voided warranty, or any other consequence resulting from the use of these tools and scripts. By using this software you acknowledge that:

- You understand the risks of modifying CPU registers and system drivers
- You have backed up your data before applying any changes
- You are solely responsible for any outcome
- The power profiles are specific to the i9-14900HX and may not be appropriate for other CPUs
- WinRing0 is classified as a vulnerable driver by Microsoft — using it requires disabling security features

**Always update your BIOS first** and create a system restore point before running any script.

## License

MIT — See [LICENSE](LICENSE)

## Credits

- **artkirius**, **jihakkim**, **Puraw**, **StevenGen** — Acer Community
- **[ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/)** by Kevin Glynn — MSR reference values
- **[WinRing0](https://github.com/GermanAizek/WinRing0)** — Kernel driver for MSR access (OpenLibSys, BSD License)

# PredatorGuard

**Simple Hardcoded Power-Limit Lock Tool for Acer Predator Laptops**

Locks CPU power limit registers to prevent PredatorSense from overwriting them, using fixed known-good presets instead of live manual tuning.

## Why

PredatorSense writes CPU power limit registers (MSR 0x610) at runtime. These uncontrolled writes can cause instability, throttling issues, and power management conflicts. PredatorGuard locks these registers using the CPU's hardware lock bit — once locked, all writes are ignored until reboot.

Additionally, it caps turbo boost at 5.4 GHz (stock 5.8 GHz on i9-14900HX) to reduce power spikes that trigger aggressive PredatorSense intervention.

This is deliberately the simple option. If you want deep manual control, use ThrottleStop instead.

## What it does

1. **Writes safe PL1/PL2 power limits** to MSR 0x610 (fixed values from a proven ThrottleStop config)
2. **Sets the hardware LOCK bit** (bit 63) — CPU ignores all writes to MSR 0x610 until reboot
3. **Caps turbo boost ratios** via MSR 0x1AD to prevent instability at extreme frequencies
4. **Configures Speed Shift** (HWP) with proper min/max ratios and EPP on all logical processors

## Requirements

- Windows 10/11 (64-bit)
- .NET 10 Runtime
- Administrator privileges
- WinRing0 driver files next to the executable:
  - `WinRing0x64.dll` (user-mode bridge)
  - `WinRing0x64.sys` (kernel driver)

## Installation

1. Build: `dotnet publish -c Release -r win-x64`
2. Get WinRing0 files from [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/) installation directory, or build from [source](https://github.com/GermanAizek/WinRing0)
3. Place `WinRing0x64.dll` and `WinRing0x64.sys` next to `PredatorGuard.exe`
4. Run as Administrator

### Windows 11 Note

WinRing0x64.sys is on Microsoft's Vulnerable Driver Blocklist. If Memory Integrity (HVCI) is enabled, the driver won't load. You may need to disable Memory Integrity in Windows Security > Device Security > Core Isolation.

## Usage

```bash
PredatorGuard.exe                  # Apply Performance profile + lock
PredatorGuard.exe --profile game   # Apply Game profile
PredatorGuard.exe --lock-only      # Lock current values without changing
PredatorGuard.exe --status         # Show current MSR values
PredatorGuard.exe --help           # Show help
```

## Profiles (i9-14900HX)

| Profile | PL1 | PL2 | Max Freq | EPP | Turbo Cap |
|---------|-----|-----|----------|-----|-----------|
| **Performance** | 115W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Game** | 55W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Balanced** | 35W | 55W | 3.0 GHz | 128 (balanced) | Stock |
| **Battery** | 35W | 55W | 2.0 GHz | 200 (efficient) | Stock |

Profile values are derived from a working ThrottleStop configuration on the i9-14900HX, then hardcoded here to keep the tool simple and repeatable.

## Run at Boot (Task Scheduler)

```powershell
schtasks /create /tn "PredatorGuard" /tr "`"C:\path\to\PredatorGuard.exe`" --lock-only" /sc onstart /rl highest /ru SYSTEM /f
```

## MSR Registers

| MSR | Name | Purpose |
|-----|------|---------|
| 0x610 | MSR_PKG_POWER_LIMIT | PL1/PL2 power limits + **LOCK bit 63** |
| 0x1AD | MSR_TURBO_RATIO_LIMIT | Per-core turbo frequency caps |
| 0x770 | IA32_PM_ENABLE | Hardware P-states (HWP) enable |
| 0x774 | IA32_HWP_REQUEST | Speed Shift min/max ratio + EPP |

## How It Works

```
Boot → PredatorGuard runs (Task Scheduler, SYSTEM account)
     → Enables HWP (MSR 0x770)
     → Configures Speed Shift on all cores (MSR 0x774)
     → Caps turbo ratios (MSR 0x1AD)
     → Writes PL1/PL2 + LOCK to MSR 0x610
     → CPU now ignores ALL writes to MSR 0x610
     → PredatorSense can't override power limits → stable operation
```

## Building

```bash
dotnet build
dotnet publish -c Release -r win-x64
```

## Disclaimer

**USE AT YOUR OWN RISK.** This tool writes to CPU Model-Specific Registers which requires kernel-level access. Incorrect MSR values can cause system instability. The profiles are specific to the i9-14900HX and may not be appropriate for other CPUs.

This tool does NOT replace ThrottleStop for advanced features like undervolting, monitoring, or fine-grained experimentation. That tradeoff is intentional: PredatorGuard is the simpler hardcoded path.

## Credits

- [WinRing0](https://github.com/GermanAizek/WinRing0) — Kernel driver for MSR access (original: [OpenLibSys](http://openlibsys.org/) by hiyohiyo, BSD License)
- [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/) by Kevin Glynn — Reference MSR values and inspiration

# PredatorGuard

**MSR Lock Tool for Acer Predator Laptops**

Prevents BSOD caused by PredatorSense writing conflicting MSR values that crash `intelppm.sys`.

## The Problem

On Acer Predator laptops (e.g., PHN16-72 with i9-14900HX), PredatorSense modifies CPU power limit registers (MSR 0x610) at runtime. These writes conflict with `intelppm.sys` (Intel Processor Power Management driver), causing `WHEA_UNCORRECTABLE_ERROR` blue screens.

## The Solution

PredatorGuard does what ThrottleStop does to prevent this crash:

1. **Writes safe power limits** (PL1/PL2) to MSR 0x610 (values from proven ThrottleStop config)
2. **Sets the hardware LOCK bit** (bit 63) — after this, the CPU ignores ALL writes to MSR 0x610 until reboot
3. **Caps turbo boost ratios** via MSR 0x1AD to prevent instability at extreme frequencies
4. **Configures Speed Shift** (HWP) with sane max/min ratios and EPP

Once locked, PredatorSense cannot modify power limits → no conflict with intelppm → no BSOD.

## Requirements

- Windows 10/11 (64-bit)
- .NET 10 Runtime
- Administrator privileges (required for MSR access)
- WinRing0 driver files in the application directory:
  - `WinRing0x64.dll` (user-mode bridge)
  - `WinRing0x64.sys` (kernel driver)

## Installation

1. Download or build PredatorGuard
2. Download WinRing0 from [GermanAizek/WinRing0](https://github.com/GermanAizek/WinRing0/releases)
3. Place `WinRing0x64.dll` and `WinRing0x64.sys` in the same directory as `PredatorGuard.exe`
4. Run as Administrator

### Windows 11 Note

On Windows 11 22H2+, WinRing0 may be blocked by the Vulnerable Driver Blocklist. If the driver fails to load:

```
bcdedit /set hvci disable
```

Or use the Microsoft Vulnerable Driver Blocklist policy to add an exception.

## Usage

```bash
# Apply Performance profile + lock (default)
PredatorGuard.exe

# Apply a specific profile
PredatorGuard.exe --profile game

# Lock current MSR values without changing them
PredatorGuard.exe --lock-only

# Show current MSR register values
PredatorGuard.exe --status

# Show help
PredatorGuard.exe --help
```

## Profiles

| Profile | PL1 | PL2 | Max Freq | EPP | Turbo Cap |
|---------|-----|-----|----------|-----|-----------|
| **Performance** | 115W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Game** | 55W | 157W | 5.4 GHz | 0 (max perf) | 5.4 GHz |
| **Balanced** | 35W | 55W | 3.0 GHz | 128 (balanced) | Stock |
| **Battery** | 35W | 55W | 2.0 GHz | 200 (efficient) | Stock |

Profile values are derived from a working ThrottleStop configuration on the i9-14900HX.

## Run at Boot (Task Scheduler)

To protect against BSOD at every boot, before PredatorSense starts:

```powershell
schtasks /create /tn "PredatorGuard" /tr "`"C:\path\to\PredatorGuard.exe`" --lock-only" /sc onstart /rl highest /ru SYSTEM /f
```

Replace `C:\path\to\` with your actual installation directory.

## MSR Registers

| MSR | Name | Purpose |
|-----|------|---------|
| 0x610 | MSR_PKG_POWER_LIMIT | PL1/PL2 power limits + **LOCK bit 63** |
| 0x1AD | MSR_TURBO_RATIO_LIMIT | Per-core turbo frequency caps |
| 0x770 | IA32_PM_ENABLE | Hardware P-states (HWP) enable |
| 0x774 | IA32_HWP_REQUEST | Speed Shift min/max ratio + EPP |

## Building

```bash
dotnet build
dotnet publish -c Release -r win-x64 --self-contained false
```

## How It Works

```
Boot → PredatorGuard runs (Task Scheduler, SYSTEM account)
     → Writes PL1/PL2 values to MSR 0x610
     → Sets bit 63 (LOCK) on MSR 0x610
     → CPU now ignores ALL writes to MSR 0x610
     → PredatorSense starts, tries to write MSR 0x610
     → CPU ignores it (locked) → no conflict
     → intelppm.sys operates normally → no BSOD
```

## Disclaimer

**USE AT YOUR OWN RISK.** This tool writes to CPU Model-Specific Registers (MSR) which requires kernel-level access. Incorrect MSR values can cause system instability. The profiles included are specific to the i9-14900HX and may not be appropriate for other CPUs.

This tool does NOT replace ThrottleStop for advanced features like undervolting or detailed monitoring. It does one thing: locks MSR registers to prevent the PredatorSense/intelppm BSOD.

## License

MIT License - See [LICENSE](../LICENSE) for details.

## Credits

- [WinRing0](https://github.com/GermanAizek/WinRing0) - Kernel driver for MSR access (BSD License)
- [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/) - Inspiration and reference values

# ThrottleStop Settings for PHN16-72 (i9-14900HX)

These are the proven ThrottleStop 9.7 settings that prevent BSOD and stabilize the Acer Predator PHN16-72 with i9-14900HX. These settings have been tested for weeks without a single crash.

**ThrottleStop is a solid alternative, but it is also the riskier one** because it exposes far more tuning knobs. `PredatorGuard` exists for the opposite goal: a simple hardcoded tool with fixed known-good values and a smaller mistake surface.

![ThrottleStop Settings](docs/throttlestop-settings.png)

---

## Main Window (Performance Profile)

| Setting | Value | Why |
|---------|-------|-----|
| **Profile** | Performance (first dot, blue) | Base profile |
| **High Performance** | Checked | Windows power plan |
| **Clock Mod** | 100.0% | No clock throttling |
| **Set Multiplier** | 29 T | Base multiplier |
| **Speed Shift EPP** | 0 | Maximum performance (0 = full speed) |
| **SpeedStep** | Checked | Required for Speed Shift to work |
| **C1E** | Checked | Allows idle power saving |
| **Disable Turbo** | Unchecked | Turbo boost is ON |
| **BD PROCHOT** | Unchecked | No bidirectional PROCHOT throttle |

---

## Turbo Power Limits (TPL Button)

This is the critical section that prevents PredatorSense from crashing the system.

### MSR Power Limit Controls

| Setting | Value | Why |
|---------|-------|-----|
| **Long Power PL1** | 115 W | Sustained power limit |
| **PL1 Clamp** | Checked | Enforces PL1 strictly |
| **Short Power PL2** | 157 W | Burst power limit (= Intel Max Turbo Power) |
| **PL2 Clamp** | Checked | Enforces PL2 strictly |
| **Turbo Time Limit** | 160 s | How long PL2 burst is allowed |
| **Sync MMIO** | Checked | Syncs MSR and MMIO power limits |
| **Lock** | **Checked** | **THE KEY SETTING — locks MSR 0x610 bit 63** |

> **Why Lock matters:** Once locked, the CPU ignores ALL writes to MSR 0x610 until reboot. PredatorSense can't overwrite these values. This is what prevents the crash.

### Turbo Power Limits (Right Panel)

| Register | PL1 | PL2 | Time | Lock |
|----------|-----|-----|------|------|
| **MSR** | 115 | 157 | 160 | Locked |
| **MMIO** | - | - | - | Locked |

### Global Settings

| Setting | Value |
|---------|-------|
| **Power Limit 4** | 246 / 246, Locked |
| **TDP Level** | Default / 0 |
| **Power Balance** | 16 / 7 iGPU |
| **PP0 Power Limit** | Checked, Clamp checked, 0 |
| **PP0 Turbo Time Limit** | 56 |

### Speed Shift (Miscellaneous)

| Setting | Value | Why |
|---------|-------|-----|
| **Speed Shift** | Enabled (SST) | Hardware P-state control |
| **Min** | 4 | 400 MHz minimum (idle) |
| **Max** | **54** | **5.4 GHz cap (stock is 58 = 5.8 GHz)** |
| **PROCHOT Offset** | 0 | No thermal offset |

> **Why Max=54:** Capping turbo at 5.4 GHz instead of 5.8 GHz reduces power spikes that trigger aggressive PredatorSense intervention. The i9-14900HX runs stable at 5.4 GHz without the extreme power draw that causes conflicts.

---

## C States (C10 Button)

| Setting | Value | Why |
|---------|-------|-----|
| **Package C State Locked** | Request C6, C10 | Allows deep package sleep |
| **C1 Demotion** | Checked | |
| **C1 Undemotion** | Checked | |
| **C3 Demotion** | Unchecked | |
| **C3 Undemotion** | Unchecked | |
| **PKG Demotion** | Checked | |
| **PKG Undemotion** | Checked | |
| **C States - AC** | On | C-states active on AC power |

---

## How to Apply

1. Download [ThrottleStop 9.7](https://www.techpowerup.com/download/techpowerup-throttlestop/)
2. Run as Administrator
3. Set the Performance profile settings as shown above
4. Click **TPL** and configure power limits + **enable Lock**
5. Click **C10** and configure C States
6. Click **Save**
7. Set ThrottleStop to start automatically:
   - Options > Start Minimized
   - Create a Task Scheduler entry to run at logon

## ThrottleStop vs PredatorGuard

| Feature | ThrottleStop | PredatorGuard |
|---------|-------------|---------------|
| Stability approach | Powerful but highly customizable | Simple hardcoded known-good presets |
| MSR Lock | Yes | Yes |
| Power Profiles | Manual GUI | CLI with fixed presets |
| Turbo Cap | Yes (Speed Shift Max) | Yes (MSR 0x1AD) |
| Real-time Monitoring | Yes (temps, clocks, power) | No |
| Undervolt | Yes | No |
| C-State Control | Yes | No |
| Auto-start | Task Scheduler | Task Scheduler |
| Open Source | No | Yes |
| Dependencies | None | WinRing0 driver |

**Use ThrottleStop if:** you know exactly what you are changing and want GUI control, monitoring, undervolting, or deeper customization.
**Use PredatorGuard if:** you want the simpler and safer default path: a lightweight, zero-UI tool with hardcoded presets that just applies known-good values and locks power limits at boot.

using System.Collections.Frozen;

namespace PredatorGuard;

/// <summary>
/// Power profile definition for MSR 0x610 (PKG_POWER_LIMIT) and 0x774 (HWP_REQUEST).
/// Values derived from ThrottleStop configuration for i9-14900HX on Acer Predator PHN16-72.
/// </summary>
/// <param name="Name">Profile display name</param>
/// <param name="PL1Raw">MSR 0x610 bits 31:0 — PL1 power (bits 14:0, 1/8W), enable (15), clamp (16), time Y=21:17 Z=23:22</param>
/// <param name="PL2Raw">MSR 0x610 bits 63:32 — PL2 power (bits 14:0, 1/8W), enable (15), clamp (16), time Y=21:17 Z=23:22</param>
/// <param name="MaxRatio">Speed Shift max performance ratio (e.g. 54 = 5.4 GHz)</param>
/// <param name="MinRatio">Speed Shift min performance ratio (e.g. 4 = 400 MHz)</param>
/// <param name="EPP">Energy Performance Preference: 0=max perf, 128=balanced, 255=max efficiency</param>
/// <param name="TurboMaxRatio">Max turbo ratio cap for MSR 0x1AD (e.g. 54 = 5.4 GHz, 0 = don't modify)</param>
public record PowerProfile(
    string Name,
    uint PL1Raw,
    uint PL2Raw,
    byte MaxRatio,
    byte MinRatio,
    byte EPP,
    byte TurboMaxRatio = 0)
{
    // i9-14900HX profiles derived from ThrottleStop INI
    // PL1Raw/PL2Raw encode: power limit (bits 14:0, in 1/8W units), enable (bit 15),
    // clamping (bit 16), time window Y=bits 21:17, Z=bits 23:22 → 2^Y*(1+Z/4)*TimeUnit

    /// <summary>
    /// Full performance: PL1=115W, PL2=157W, EPP=0, Max 5.4GHz, Turbo capped at 5.4GHz
    /// </summary>
    public static readonly PowerProfile Performance = new(
        "Performance",
        PL1Raw: 0x00638398,
        PL2Raw: 0x004384E8,
        MaxRatio: 54,
        MinRatio: 4,
        EPP: 0,
        TurboMaxRatio: 54); // Cap turbo at 5.4 GHz (stock is 5.8)

    /// <summary>
    /// Gaming: PL1=55W, PL2=157W, EPP=0, Max 5.4GHz, Turbo capped at 5.4GHz
    /// </summary>
    public static readonly PowerProfile Game = new(
        "Game",
        PL1Raw: 0x00DF81B8,
        PL2Raw: 0x004284E8,
        MaxRatio: 54,
        MinRatio: 4,
        EPP: 0,
        TurboMaxRatio: 54); // Cap turbo at 5.4 GHz

    /// <summary>
    /// Balanced: PL1=35W, PL2=55W, EPP=128, Max 3.0GHz
    /// </summary>
    public static readonly PowerProfile Balanced = new(
        "Balanced",
        PL1Raw: 0x00DF8118,
        PL2Raw: 0x004281B8,
        MaxRatio: 30,
        MinRatio: 4,
        EPP: 128);

    /// <summary>
    /// Battery saver: PL1=35W, PL2=55W, EPP=200, Max 2.0GHz
    /// </summary>
    public static readonly PowerProfile Battery = new(
        "Battery",
        PL1Raw: 0x00DF8118,
        PL2Raw: 0x004281B8,
        MaxRatio: 20,
        MinRatio: 4,
        EPP: 200);

    private static readonly FrozenDictionary<string, PowerProfile> _profiles =
        new Dictionary<string, PowerProfile>(StringComparer.OrdinalIgnoreCase)
        {
            ["performance"] = Performance,
            ["game"] = Game,
            ["balanced"] = Balanced,
            ["battery"] = Battery
        }.ToFrozenDictionary(StringComparer.OrdinalIgnoreCase);

    public static FrozenDictionary<string, PowerProfile> All => _profiles;

    public static PowerProfile? GetByName(string name) =>
        _profiles.GetValueOrDefault(name);

    /// <summary>
    /// Decode PL1 power limit from raw value (bits 14:0, in 1/8 watt units).
    /// </summary>
    public double DecodePL1Watts() => (PL1Raw & 0x7FFF) / 8.0;

    /// <summary>
    /// Decode PL2 power limit from raw value (bits 14:0, in 1/8 watt units).
    /// </summary>
    public double DecodePL2Watts() => (PL2Raw & 0x7FFF) / 8.0;

    /// <summary>
    /// Build the full 64-bit MSR 0x610 value with lock bit set.
    /// </summary>
    public ulong BuildLockedPowerLimit()
    {
        ulong value = ((ulong)PL2Raw << 32) | PL1Raw;
        value |= 1UL << 63; // Set LOCK bit
        return value;
    }

    /// <summary>
    /// Build the 64-bit MSR 0x774 (IA32_HWP_REQUEST) value.
    /// Bits 7:0 = Minimum_Performance, Bits 15:8 = Maximum_Performance,
    /// Bits 23:16 = Desired_Performance (0 = HW autonomous), Bits 31:24 = EPP
    /// </summary>
    public ulong BuildHwpRequest()
    {
        return (ulong)MinRatio
            | ((ulong)MaxRatio << 8)
            | ((ulong)EPP << 24);
    }

    /// <summary>
    /// Cap each per-core turbo ratio in a 64-bit MSR 0x1AD value.
    /// MSR 0x1AD has 8 bytes: byte[i] = max ratio when (i+1) cores are active.
    /// Each byte that exceeds maxRatio gets capped.
    /// </summary>
    /// <param name="currentValue">Current MSR 0x1AD value</param>
    /// <param name="maxRatio">Maximum allowed ratio (must be > 0)</param>
    public static ulong CapTurboRatios(ulong currentValue, byte maxRatio)
    {
        ArgumentOutOfRangeException.ThrowIfZero(maxRatio);

        ulong result = 0;
        for (int i = 0; i < 8; i++)
        {
            byte ratio = (byte)((currentValue >> (i * 8)) & 0xFF);
            if (ratio > maxRatio && ratio != 0)
                ratio = maxRatio;
            result |= (ulong)ratio << (i * 8);
        }
        return result;
    }
}

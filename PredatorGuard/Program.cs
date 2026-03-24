using PredatorGuard;

const string VERSION = "1.0.0";
const string BANNER = $"""
    PredatorGuard v{VERSION} - MSR Lock Tool for Acer Predator
    Prevents BSOD caused by PredatorSense + intelppm.sys MSR conflicts
    """;

// Use MSR addresses from MsrService (single source of truth)
var (command, profileName, parseError) = ParseArgs(args);

if (parseError is not null)
{
    Console.Error.WriteLine(parseError);
    Console.WriteLine();
    PrintHelp();
    return 1;
}

Console.WriteLine(BANNER);
Console.WriteLine();

if (command == Command.Help)
{
    PrintHelp();
    return 0;
}

using var msr = new MsrService();
if (!msr.Initialize())
{
    Console.Error.WriteLine("\nFailed to initialize WinRing0. Run as Administrator.");
    Console.Error.WriteLine("Ensure WinRing0x64.dll and WinRing0x64.sys are in the application directory.");
    return 1;
}

Console.WriteLine("[OK] WinRing0 initialized");

return command switch
{
    Command.Status => ShowStatus(msr),
    Command.LockOnly => LockOnly(msr),
    Command.Unlock => Unlock(msr),
    Command.Apply => ApplyProfile(msr, profileName),
    _ => ApplyProfile(msr, profileName)
};

// ──────────────────────────────────────────────
// Commands
// ──────────────────────────────────────────────

static int ShowStatus(MsrService msr)
{
    Console.WriteLine("\n── MSR Status ──────────────────────────────");

    // PKG_POWER_LIMIT (0x610)
    if (msr.ReadMsr64(MsrService.MSR_PKG_POWER_LIMIT, out ulong pl))
    {
        uint eax = (uint)(pl & 0xFFFFFFFF);
        uint edx = (uint)(pl >> 32);
        double pl1w = (eax & 0x7FFF) / 8.0;
        double pl2w = (edx & 0x7FFF) / 8.0;
        bool pl1Enabled = (eax & (1 << 15)) != 0;
        bool pl2Enabled = (edx & (1 << 15)) != 0;
        bool locked = (pl & (1UL << 63)) != 0;

        Console.WriteLine($"\nMSR 0x610 (PKG_POWER_LIMIT):");
        Console.WriteLine($"  Raw: 0x{pl:X16} (EAX=0x{eax:X8} EDX=0x{edx:X8})");
        Console.WriteLine($"  PL1: {pl1w:F1}W {(pl1Enabled ? "[enabled]" : "[disabled]")}");
        Console.WriteLine($"  PL2: {pl2w:F1}W {(pl2Enabled ? "[enabled]" : "[disabled]")}");
        Console.WriteLine($"  Lock bit 63: {(locked ? "LOCKED" : "UNLOCKED")}");
    }
    else
    {
        Console.Error.WriteLine("  Failed to read MSR 0x610");
    }

    // TURBO_RATIO_LIMIT (0x1AD)
    if (msr.ReadMsr64(MsrService.MSR_TURBO_RATIO_LIMIT, out ulong turbo))
    {
        Console.WriteLine($"\nMSR 0x1AD (TURBO_RATIO_LIMIT):");
        Console.WriteLine($"  Raw: 0x{turbo:X16}");
        for (int i = 0; i < 8; i++)
        {
            byte ratio = (byte)((turbo >> (i * 8)) & 0xFF);
            if (ratio == 0) break;
            Console.WriteLine($"  {i + 1}-core max: {ratio}x ({ratio / 10.0:F1} GHz)");
        }
    }
    else
    {
        Console.Error.WriteLine("  Failed to read MSR 0x1AD");
    }

    // HWP Enable (0x770)
    if (msr.ReadMsr64(MsrService.IA32_PM_ENABLE, out ulong hwpEnable))
    {
        bool enabled = (hwpEnable & 1) != 0;
        Console.WriteLine($"\nMSR 0x770 (IA32_PM_ENABLE):");
        Console.WriteLine($"  HWP: {(enabled ? "enabled" : "disabled")}");
    }
    else
    {
        Console.Error.WriteLine("  Failed to read MSR 0x770");
    }

    // HWP Request (0x774)
    if (msr.ReadMsr64(MsrService.IA32_HWP_REQUEST, out ulong hwp))
    {
        byte min = (byte)(hwp & 0xFF);
        byte max = (byte)((hwp >> 8) & 0xFF);
        byte epp = (byte)((hwp >> 24) & 0xFF);
        Console.WriteLine($"\nMSR 0x774 (IA32_HWP_REQUEST):");
        Console.WriteLine($"  Raw: 0x{hwp:X16}");
        Console.WriteLine($"  Min ratio: {min}x ({min / 10.0:F1} GHz)");
        Console.WriteLine($"  Max ratio: {max}x ({max / 10.0:F1} GHz)");
        Console.WriteLine($"  EPP: {epp} {EppDescription(epp)}");
    }
    else
    {
        Console.Error.WriteLine("  Failed to read MSR 0x774");
    }

    Console.WriteLine("\n────────────────────────────────────────────");
    return 0;
}

static int LockOnly(MsrService msr)
{
    Console.WriteLine("\n── Lock Only Mode ──────────────────────────");

    if (!msr.ReadMsr64(MsrService.MSR_PKG_POWER_LIMIT, out ulong current))
    {
        Console.Error.WriteLine("Failed to read MSR 0x610");
        return 1;
    }

    bool alreadyLocked = (current & (1UL << 63)) != 0;
    if (alreadyLocked)
    {
        Console.WriteLine("[OK] MSR 0x610 is already locked (bit 63 set)");
        Console.WriteLine("     Power limits are protected until next reboot.");
        return 0;
    }

    // Set lock bit without changing values
    ulong locked = current | (1UL << 63);
    if (!msr.WriteMsr64(MsrService.MSR_PKG_POWER_LIMIT, locked))
    {
        Console.Error.WriteLine("Failed to write MSR 0x610 with lock bit");
        return 1;
    }

    // Verify
    if (!msr.ReadMsr64(MsrService.MSR_PKG_POWER_LIMIT, out ulong verify))
    {
        Console.Error.WriteLine("[WARN] Lock written but verification read failed.");
        return 1;
    }

    if ((verify & (1UL << 63)) != 0)
    {
        uint eax = (uint)(verify & 0xFFFFFFFF);
        double pl1w = (eax & 0x7FFF) / 8.0;
        Console.WriteLine($"[OK] MSR 0x610 LOCKED at current values (PL1={pl1w:F1}W)");
        Console.WriteLine("     PredatorSense cannot modify power limits until reboot.");
    }
    else
    {
        Console.Error.WriteLine("[FAIL] Lock bit did not stick. MSR may be controlled by BIOS.");
        return 1;
    }

    return 0;
}

static int Unlock(MsrService msr)
{
    Console.WriteLine("\n── Unlock Mode ─────────────────────────────");

    if (!msr.ReadMsr64(MsrService.MSR_PKG_POWER_LIMIT, out ulong current))
    {
        Console.Error.WriteLine("Failed to read MSR 0x610");
        return 1;
    }

    bool locked = (current & (1UL << 63)) != 0;
    if (!locked)
    {
        Console.WriteLine("[OK] MSR 0x610 is already unlocked.");
        return 0;
    }

    Console.WriteLine("NOTE: MSR 0x610 lock bit is a hardware write-once bit.");
    Console.WriteLine("      Once set, it can only be cleared by a system reboot.");
    Console.WriteLine("      To unlock: reboot and do NOT run PredatorGuard at startup.");
    return 0;
}

static int ApplyProfile(MsrService msr, string profileName)
{
    var profile = PowerProfile.GetByName(profileName);
    if (profile is null)
    {
        Console.Error.WriteLine($"Unknown profile: '{profileName}'");
        Console.Error.WriteLine($"Available: {string.Join(", ", PowerProfile.All.Keys)}");
        return 1;
    }

    Console.WriteLine($"\n── Applying Profile: {profile.Name} ─────────────────");
    Console.WriteLine($"  PL1: {profile.DecodePL1Watts():F1}W");
    Console.WriteLine($"  PL2: {profile.DecodePL2Watts():F1}W");
    Console.WriteLine($"  Speed Shift: {profile.MinRatio}-{profile.MaxRatio}x, EPP={profile.EPP}");
    if (profile.TurboMaxRatio > 0)
        Console.WriteLine($"  Turbo cap: {profile.TurboMaxRatio}x ({profile.TurboMaxRatio / 10.0:F1} GHz)");

    int errors = 0;
    int cpuCount = Environment.ProcessorCount;

    // Step 1: Enable HWP on all cores (before configuring anything else)
    Console.Write("\n[1/5] Writing MSR 0x770 (IA32_PM_ENABLE)... ");
    if (msr.ReadMsr64(MsrService.IA32_PM_ENABLE, out ulong hwpCurrent))
    {
        if ((hwpCurrent & 1) == 0)
        {
            if (msr.WriteMsr64(MsrService.IA32_PM_ENABLE, hwpCurrent | 1))
            {
                // Verify
                if (msr.ReadMsr64(MsrService.IA32_PM_ENABLE, out ulong hwpVerify) && (hwpVerify & 1) != 0)
                    Console.WriteLine("OK (HWP enabled, verified)");
                else
                {
                    Console.WriteLine("WARN (write accepted, verify failed)");
                    errors++;
                }
            }
            else
            {
                Console.WriteLine("FAILED");
                errors++;
            }
        }
        else
        {
            Console.WriteLine("OK (already enabled)");
        }
    }
    else
    {
        Console.WriteLine("FAILED to read");
        errors++;
    }

    // Step 2: Write HWP Request to ALL logical processors
    Console.Write("[2/5] Writing MSR 0x774 (IA32_HWP_REQUEST)... ");
    ulong hwpValue = profile.BuildHwpRequest();
    uint hwpEax = (uint)(hwpValue & 0xFFFFFFFF);
    uint hwpEdx = (uint)(hwpValue >> 32);
    int hwpErrors = 0;
    for (int t = 0; t < cpuCount && t < 64; t++)
    {
        if (!msr.WriteMsrThread(MsrService.IA32_HWP_REQUEST, hwpEax, hwpEdx, t))
            hwpErrors++;
    }
    if (hwpErrors == 0)
        Console.WriteLine($"OK (Min={profile.MinRatio}x Max={profile.MaxRatio}x EPP={profile.EPP}) on {Math.Min(cpuCount, 64)} threads");
    else
    {
        Console.WriteLine($"PARTIAL ({hwpErrors}/{Math.Min(cpuCount, 64)} threads failed)");
        errors++;
    }

    // Step 3: Cap turbo ratio limits
    Console.Write("[3/5] Writing MSR 0x1AD (TURBO_RATIO_LIMIT)... ");
    if (profile.TurboMaxRatio > 0)
    {
        if (msr.ReadMsr64(MsrService.MSR_TURBO_RATIO_LIMIT, out ulong currentTurbo))
        {
            ulong capped = PowerProfile.CapTurboRatios(currentTurbo, profile.TurboMaxRatio);
            if (currentTurbo != capped)
            {
                if (msr.WriteMsr64(MsrService.MSR_TURBO_RATIO_LIMIT, capped))
                {
                    // Verify
                    if (msr.ReadMsr64(MsrService.MSR_TURBO_RATIO_LIMIT, out ulong turboVerify) && turboVerify == capped)
                        Console.WriteLine($"OK (capped to {profile.TurboMaxRatio}x, verified)");
                    else
                        Console.WriteLine($"OK (capped to {profile.TurboMaxRatio}x, verify inconclusive)");
                }
                else
                {
                    Console.WriteLine("FAILED (MSR may be locked by BIOS)");
                    errors++;
                }
            }
            else
            {
                Console.WriteLine("OK (already within cap)");
            }
        }
        else
        {
            Console.WriteLine("FAILED to read");
            errors++;
        }
    }
    else
    {
        Console.WriteLine("SKIPPED (no cap configured)");
    }

    // Step 4: Write PKG_POWER_LIMIT with LOCK — LAST, after everything else is configured
    Console.Write("[4/5] Writing MSR 0x610 (PKG_POWER_LIMIT + LOCK)... ");
    ulong plValue = profile.BuildLockedPowerLimit();
    if (msr.WriteMsr64(MsrService.MSR_PKG_POWER_LIMIT, plValue))
    {
        // Verify lock
        if (!msr.ReadMsr64(MsrService.MSR_PKG_POWER_LIMIT, out ulong verify))
        {
            Console.WriteLine("WARN (write accepted, verification read failed)");
            errors++;
        }
        else
        {
            bool locked = (verify & (1UL << 63)) != 0;
            Console.WriteLine(locked ? "OK (LOCKED)" : "WARN (lock bit did not stick)");
            if (!locked) errors++;
        }
    }
    else
    {
        Console.WriteLine("FAILED");
        errors++;
    }

    // Step 5: Final verification
    Console.Write("[5/5] Verifying... ");
    if (!msr.ReadMsr64(MsrService.MSR_PKG_POWER_LIMIT, out ulong finalPl))
    {
        Console.Error.WriteLine("FAILED (cannot read MSR 0x610)");
        return 1;
    }

    bool finalLocked = (finalPl & (1UL << 63)) != 0;
    if (finalLocked && errors == 0)
    {
        Console.WriteLine("ALL OK");
        Console.WriteLine($"\n[OK] Profile '{profile.Name}' applied and LOCKED.");
        Console.WriteLine("     PredatorSense cannot override power limits until reboot.");
        Console.WriteLine("     intelppm.sys BSOD protection is ACTIVE.");
        return 0;
    }
    else if (finalLocked)
    {
        Console.WriteLine($"PARTIAL ({errors} error(s))");
        Console.WriteLine($"\n[WARN] Profile applied with {errors} error(s). Lock is active.");
        return 1;
    }
    else
    {
        Console.WriteLine("LOCK FAILED");
        Console.Error.WriteLine("\n[FAIL] Lock bit not set. BSOD protection NOT active.");
        return 1;
    }
}

// ──────────────────────────────────────────────
// Argument parsing
// ──────────────────────────────────────────────

static (Command cmd, string profile, string? error) ParseArgs(string[] args)
{
    string profile = "performance";
    Command? cmd = null;

    for (int i = 0; i < args.Length; i++)
    {
        switch (args[i].ToLowerInvariant())
        {
            case "--status":
            case "-s":
                if (cmd is not null && cmd != Command.Status)
                    return (Command.Help, "", $"Error: conflicting commands ({cmd} and Status)");
                cmd = Command.Status;
                break;
            case "--lock-only":
            case "-l":
                if (cmd is not null && cmd != Command.LockOnly)
                    return (Command.Help, "", $"Error: conflicting commands ({cmd} and LockOnly)");
                cmd = Command.LockOnly;
                break;
            case "--unlock":
            case "-u":
                if (cmd is not null && cmd != Command.Unlock)
                    return (Command.Help, "", $"Error: conflicting commands ({cmd} and Unlock)");
                cmd = Command.Unlock;
                break;
            case "--profile":
            case "-p":
                if (i + 1 >= args.Length)
                    return (Command.Help, "", "Error: --profile requires a profile name. Available: " +
                        string.Join(", ", PowerProfile.All.Keys));
                profile = args[++i];
                break;
            case "--help":
            case "-h":
            case "-?":
                return (Command.Help, "", null);
            default:
                if (args[i].StartsWith('-'))
                    return (Command.Help, "", $"Error: unknown option '{args[i]}'");
                if (PowerProfile.GetByName(args[i]) is not null)
                    profile = args[i];
                else
                    return (Command.Help, "", $"Error: unknown argument '{args[i]}'. " +
                        $"Available profiles: {string.Join(", ", PowerProfile.All.Keys)}");
                break;
        }
    }

    return (cmd ?? Command.Apply, profile, null);
}

static void PrintHelp()
{
    Console.WriteLine(BANNER);
    Console.WriteLine();
    Console.WriteLine("""
    Usage: PredatorGuard.exe [command] [options]

    Commands:
      (default)          Apply profile + lock MSR registers
      --status, -s       Show current MSR register values
      --lock-only, -l    Lock MSR 0x610 at current values (don't change them)
      --unlock, -u       Info on how to unlock (requires reboot)
      --help, -h         Show this help

    Options:
      --profile, -p <name>   Power profile to apply (default: performance)

    Profiles:
    """);

    foreach (var (name, p) in PowerProfile.All)
    {
        Console.WriteLine($"  {name,-14} PL1={p.DecodePL1Watts():F0}W  PL2={p.DecodePL2Watts():F0}W  " +
                         $"Max={p.MaxRatio}x({p.MaxRatio / 10.0:F1}GHz)  EPP={p.EPP}  " +
                         $"Turbo={( p.TurboMaxRatio > 0 ? $"{p.TurboMaxRatio}x" : "stock")}");
    }

    Console.WriteLine("""

    Examples:
      PredatorGuard.exe                     Apply Performance profile + lock
      PredatorGuard.exe -p game             Apply Game profile + lock
      PredatorGuard.exe --lock-only         Lock current values without changing
      PredatorGuard.exe --status            Show current MSR values

    Task Scheduler (run at boot):
      schtasks /create /tn "PredatorGuard" /tr "\"C:\path\PredatorGuard.exe\" --lock-only" /sc onstart /rl highest /ru SYSTEM
    """);
}

static string EppDescription(byte epp) => epp switch
{
    0 => "(max performance)",
    <= 64 => "(performance)",
    <= 128 => "(balanced)",
    <= 192 => "(power saving)",
    _ => "(max efficiency)"
};

enum Command { Apply, Status, LockOnly, Unlock, Help }

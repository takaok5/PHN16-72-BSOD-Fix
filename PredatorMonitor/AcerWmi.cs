using System.Management;

namespace PredatorMonitor;

public static class AcerWmi
{
    private const string WmiNamespace = @"root\WMI";
    private const string WmiClass = "AcerGamingFunction";

    public const int FanCpu = 0x01;
    public const int FanGpu = 0x04;

    // Cached WMI instance - refreshed periodically
    private static ManagementObject? _cached;
    private static DateTime _lastRefresh = DateTime.MinValue;

    public static ManagementObject? GetInstance()
    {
        // Refresh every 10 seconds to avoid stale connections
        if (_cached != null && (DateTime.Now - _lastRefresh).TotalSeconds < 10)
            return _cached;

        try
        {
            using var searcher = new ManagementObjectSearcher(WmiNamespace, $"SELECT * FROM {WmiClass}");
            foreach (ManagementObject obj in searcher.Get())
            {
                _cached = obj;
                _lastRefresh = DateTime.Now;
                return obj;
            }
        }
        catch
        {
            _cached = null;
        }
        return null;
    }

    public static void InvalidateCache() { _cached = null; }

    // ── All-in-one read for timer tick ──
    public static (ulong profileId, int cpuTemp, int gpuTemp, int cpuFan, int gpuFan) ReadAll()
    {
        var inst = GetInstance();
        if (inst == null) return (1, 0, 0, 0, 0);

        ulong profileId = 1;
        int cpuTemp = 0, gpuTemp = 0, cpuFan = 0, gpuFan = 0;

        try
        {
            var p = inst.GetMethodParameters("GetGamingProfile");
            p["gmInput"] = (uint)0x01;
            var r = inst.InvokeMethod("GetGamingProfile", p, null);
            profileId = (ulong)r["gmOutput"];
        }
        catch { }

        try
        {
            var p = inst.GetMethodParameters("GetGamingSysInfo");
            p["gmInput"] = (uint)0x0101;
            var r = inst.InvokeMethod("GetGamingSysInfo", p, null);
            cpuTemp = (int)(((ulong)r["gmOutput"] >> 8) & 0xFF);
        }
        catch { }

        try
        {
            var p = inst.GetMethodParameters("GetGamingSysInfo");
            p["gmInput"] = (uint)0x0A01;
            var r = inst.InvokeMethod("GetGamingSysInfo", p, null);
            gpuTemp = (int)(((ulong)r["gmOutput"] >> 8) & 0xFF);
        }
        catch { }

        try
        {
            var p = inst.GetMethodParameters("GetGamingSysInfo");
            p["gmInput"] = (uint)0x0201;
            var r = inst.InvokeMethod("GetGamingSysInfo", p, null);
            cpuFan = (int)(((ulong)r["gmOutput"] >> 8) & 0xFFFF);
        }
        catch { }

        try
        {
            var p = inst.GetMethodParameters("GetGamingSysInfo");
            p["gmInput"] = (uint)0x0601;
            var r = inst.InvokeMethod("GetGamingSysInfo", p, null);
            gpuFan = (int)(((ulong)r["gmOutput"] >> 8) & 0xFFFF);
        }
        catch { }

        return (profileId, cpuTemp, gpuTemp, cpuFan, gpuFan);
    }

    // ── Profile name/color ──

    public static string GetProfileName(ulong id) => id switch
    {
        0 => "Quiet", 1 => "Default", 2 => "Performance",
        3 => "Turbo", 4 => "Turbo+", _ => $"Unknown ({id})"
    };

    // ── Fan ──

    // Fan control via PowerShell (proven reliable)
    private static bool RunWmiCommand(string script)
    {
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = $"-NoProfile -Command \"{script}\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true
            };
            using var proc = System.Diagnostics.Process.Start(psi);
            if (proc == null) return false;
            proc.WaitForExit(5000);
            return proc.ExitCode == 0;
        }
        catch { return false; }
    }

    private static readonly string WmiGet =
        "$o=Get-WmiObject -Namespace 'root\\WMI' -Class 'AcerGamingFunction';";

    public static bool SetFanAuto()
        => RunWmiCommand(WmiGet + "$o.SetGamingFanBehavior([uint64]1)|Out-Null");

    public static bool SetFanTurbo()
        => RunWmiCommand(WmiGet + "$o.SetGamingFanBehavior([uint64]2)|Out-Null");

    public static bool SetBothFanSpeed(int speed)
    {
        speed = Math.Clamp(speed, 0, 100);
        var cpuVal = (speed << 8) | FanCpu;
        var gpuVal = (speed << 8) | FanGpu;
        return RunWmiCommand(WmiGet +
            $"$o.SetGamingFanSpeed([uint64]{cpuVal})|Out-Null;" +
            $"$o.SetGamingFanSpeed([uint64]{gpuVal})|Out-Null");
    }
}

using System.Runtime.InteropServices;

namespace PredatorGuard;

/// <summary>
/// P/Invoke wrapper for WinRing0x64.dll providing MSR read/write access.
/// WinRing0 loads its kernel driver (WinRing0x64.sys) automatically on InitializeOls().
/// </summary>
public sealed class MsrService : IDisposable
{
    private int _initialized; // 0=false, 1=true — using int for Interlocked
    private int _disposed;    // 0=false, 1=true

    #region P/Invoke

    [DllImport("WinRing0x64.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool InitializeOls();

    [DllImport("WinRing0x64.dll", ExactSpelling = true)]
    private static extern void DeinitializeOls();

    [DllImport("WinRing0x64.dll", ExactSpelling = true)]
    private static extern uint GetDllStatus();

    [DllImport("WinRing0x64.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool Rdmsr(uint index, out uint eax, out uint edx);

    [DllImport("WinRing0x64.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool Wrmsr(uint index, uint eax, uint edx);

    [DllImport("WinRing0x64.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool RdmsrTx(uint index, out uint eax, out uint edx, UIntPtr threadAffinityMask);

    [DllImport("WinRing0x64.dll", ExactSpelling = true, SetLastError = true)]
    private static extern bool WrmsrTx(uint index, uint eax, uint edx, UIntPtr threadAffinityMask);

    #endregion

    // DLL status codes
    private const uint OLS_DLL_NO_ERROR = 0;
    private const uint OLS_DLL_DRIVER_NOT_LOADED = 1;
    private const uint OLS_DLL_DRIVER_NOT_FOUND = 2;
    private const uint OLS_DLL_DRIVER_UNLOADED = 3;
    private const uint OLS_DLL_DRIVER_NOT_LOADED_ON_NETWORK = 4;
    private const uint OLS_DLL_UNKNOWN_ERROR = 9;

    // MSR addresses — single source of truth
    public const uint MSR_PKG_POWER_LIMIT = 0x610;
    public const uint MSR_TURBO_RATIO_LIMIT = 0x1AD;
    public const uint IA32_PM_ENABLE = 0x770;
    public const uint IA32_HWP_REQUEST = 0x774;

    public bool Initialize()
    {
        ObjectDisposedException.ThrowIf(Volatile.Read(ref _disposed) == 1, this);

        if (Interlocked.CompareExchange(ref _initialized, 1, 0) == 1)
            return true;

        if (!InitializeOls())
        {
            Volatile.Write(ref _initialized, 0);
            var status = GetDllStatus();
            Console.Error.WriteLine($"WinRing0 initialization failed. Status: {StatusToString(status)}");
            Console.Error.WriteLine("Make sure WinRing0x64.dll and WinRing0x64.sys are in the same directory as the executable.");
            return false;
        }

        var dllStatus = GetDllStatus();
        if (dllStatus != OLS_DLL_NO_ERROR)
        {
            Console.Error.WriteLine($"WinRing0 driver issue: {StatusToString(dllStatus)}");
            DeinitializeOls(); // Cleanup partial init
            Volatile.Write(ref _initialized, 0);
            return false;
        }

        return true;
    }

    public bool ReadMsr(uint index, out uint eax, out uint edx)
    {
        EnsureInitialized();
        return Rdmsr(index, out eax, out edx);
    }

    public bool WriteMsr(uint index, uint eax, uint edx)
    {
        EnsureInitialized();
        return Wrmsr(index, eax, edx);
    }

    public bool ReadMsr64(uint index, out ulong value)
    {
        EnsureInitialized();
        bool result = Rdmsr(index, out uint eax, out uint edx);
        value = result ? ((ulong)edx << 32) | eax : 0UL;
        return result;
    }

    public bool WriteMsr64(uint index, ulong value)
    {
        EnsureInitialized();
        uint eax = (uint)(value & 0xFFFFFFFF);
        uint edx = (uint)(value >> 32);
        return Wrmsr(index, eax, edx);
    }

    /// <summary>
    /// Read MSR on a specific logical processor (0-63).
    /// </summary>
    public bool ReadMsrThread(uint index, out uint eax, out uint edx, int thread)
    {
        EnsureInitialized();
        ArgumentOutOfRangeException.ThrowIfNegative(thread);
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(thread, 64);
        var mask = (UIntPtr)(1UL << thread);
        return RdmsrTx(index, out eax, out edx, mask);
    }

    /// <summary>
    /// Write MSR on a specific logical processor (0-63).
    /// </summary>
    public bool WriteMsrThread(uint index, uint eax, uint edx, int thread)
    {
        EnsureInitialized();
        ArgumentOutOfRangeException.ThrowIfNegative(thread);
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(thread, 64);
        var mask = (UIntPtr)(1UL << thread);
        return WrmsrTx(index, eax, edx, mask);
    }

    ~MsrService()
    {
        if (Volatile.Read(ref _initialized) == 1)
            DeinitializeOls();
    }

    public void Dispose()
    {
        if (Interlocked.CompareExchange(ref _disposed, 1, 0) == 1)
            return;
        if (Interlocked.CompareExchange(ref _initialized, 0, 1) == 1)
            DeinitializeOls();
        GC.SuppressFinalize(this);
    }

    private void EnsureInitialized()
    {
        ObjectDisposedException.ThrowIf(Volatile.Read(ref _disposed) == 1, this);
        if (Volatile.Read(ref _initialized) != 1)
            throw new InvalidOperationException("MsrService not initialized. Call Initialize() first.");
    }

    private static string StatusToString(uint status) => status switch
    {
        OLS_DLL_NO_ERROR => "No error",
        OLS_DLL_DRIVER_NOT_LOADED => "Driver not loaded",
        OLS_DLL_DRIVER_NOT_FOUND => "Driver not found (WinRing0x64.sys missing?)",
        OLS_DLL_DRIVER_UNLOADED => "Driver was unloaded",
        OLS_DLL_DRIVER_NOT_LOADED_ON_NETWORK => "Driver not loaded (network path not supported)",
        OLS_DLL_UNKNOWN_ERROR => "Unknown error",
        _ => $"Unknown status code: {status}"
    };
}

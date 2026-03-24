namespace PredatorMonitor;

public enum FanMode { Auto, Max }

public record ProfilePreset(
    string Name,
    Color IconColor,
    byte R, byte G, byte B,   // RGB keyboard color
    FanMode Fan,
    int ThrottleStopProfile    // 1-4
);

public static class ProfileConfig
{
    // ThrottleStop profiles:
    // 1 = Balanced (Quiet/Default)
    // 2 = Performance
    // 3 = Turbo (aggressive)
    // 4 = Turbo+ (max)

    private static readonly Dictionary<ulong, ProfilePreset> Presets = new()
    {
        [0] = new("Quiet",       Color.DodgerBlue, 30, 144, 255, FanMode.Auto, 1),
        [1] = new("Default",     Color.White,      255, 255, 255, FanMode.Auto, 1),
        [2] = new("Performance", Color.Orange,     255, 165, 0,   FanMode.Auto, 2),
        [3] = new("Turbo",       Color.Red,        255, 0,   0,   FanMode.Max,  3),
        [4] = new("Turbo+",      Color.Magenta,    255, 0,   255, FanMode.Max,  4),
    };

    public static ProfilePreset GetPreset(ulong profileId)
    {
        return Presets.TryGetValue(profileId, out var preset)
            ? preset
            : Presets[1]; // fallback to Default
    }

    public static IReadOnlyDictionary<ulong, ProfilePreset> All => Presets;
}

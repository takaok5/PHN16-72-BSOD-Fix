using System.Diagnostics;

namespace PredatorMonitor;

public class TrayContext : ApplicationContext
{
    private readonly NotifyIcon _trayIcon;
    private readonly System.Windows.Forms.Timer _timer;
    private readonly ContextMenuStrip _menu;

    private readonly ToolStripMenuItem _profileItem;
    private readonly ToolStripMenuItem _cpuTempItem;
    private readonly ToolStripMenuItem _gpuTempItem;
    private readonly ToolStripMenuItem _cpuFanItem;
    private readonly ToolStripMenuItem _gpuFanItem;
    private readonly ToolStripMenuItem _fanStatusItem;

    private ulong _lastProfileId = ulong.MaxValue;
    private string _currentFanMode = "Auto";

    private static readonly string ThrottleStopPath = FindThrottleStop();

    private static string FindThrottleStop()
    {
        // WinGet install path
        var wingetPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            @"Microsoft\WinGet\Packages");
        if (Directory.Exists(wingetPath))
        {
            var match = Directory.EnumerateDirectories(wingetPath, "TechPowerUp.ThrottleStop*")
                .FirstOrDefault();
            if (match is not null)
            {
                var exe = Path.Combine(match, "ThrottleStop.exe");
                if (File.Exists(exe)) return exe;
            }
        }

        // Common manual install locations
        string[] candidates =
        [
            @"C:\Program Files\ThrottleStop\ThrottleStop.exe",
            @"C:\ThrottleStop\ThrottleStop.exe",
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"ThrottleStop\ThrottleStop.exe"),
        ];
        return candidates.FirstOrDefault(File.Exists) ?? "ThrottleStop.exe";
    }

    public TrayContext()
    {
        _profileItem = new ToolStripMenuItem("Profile: ...") { Enabled = false };
        _cpuTempItem = new ToolStripMenuItem("CPU: --°C") { Enabled = false };
        _gpuTempItem = new ToolStripMenuItem("GPU: --°C") { Enabled = false };
        _cpuFanItem = new ToolStripMenuItem("CPU Fan: -- RPM") { Enabled = false };
        _gpuFanItem = new ToolStripMenuItem("GPU Fan: -- RPM") { Enabled = false };
        _fanStatusItem = new ToolStripMenuItem("Fan: Auto") { Enabled = false };

        var fanMenu = new ToolStripMenuItem("Fan Control");
        fanMenu.DropDownItems.Add(new ToolStripMenuItem("Auto", null, (s, e) =>
        {
            if (AcerWmi.SetFanAuto()) _currentFanMode = "Auto";
            else MessageBox.Show("Fan Auto failed", "PredatorMonitor");
        }));
        fanMenu.DropDownItems.Add(new ToolStripMenuItem("Turbo (Max)", null, (s, e) =>
        {
            if (AcerWmi.SetFanTurbo()) _currentFanMode = "Turbo";
            else MessageBox.Show("Fan Turbo failed", "PredatorMonitor");
        }));
        fanMenu.DropDownItems.Add(new ToolStripSeparator());
        foreach (var pct in new[] { 50, 70, 80, 100 })
        {
            var speed = pct;
            fanMenu.DropDownItems.Add(new ToolStripMenuItem($"{pct}%", null, (s, e) =>
            {
                if (AcerWmi.SetBothFanSpeed(speed)) _currentFanMode = $"{speed}%";
                else MessageBox.Show($"Fan {speed}% failed", "PredatorMonitor");
            }));
        }

        _menu = new ContextMenuStrip();
        _menu.Items.Add(_profileItem);
        _menu.Items.Add(_fanStatusItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_cpuTempItem);
        _menu.Items.Add(_gpuTempItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(_cpuFanItem);
        _menu.Items.Add(_gpuFanItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(fanMenu);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(new ToolStripMenuItem("ThrottleStop", null, (s, e) => LaunchApp(ThrottleStopPath)));
        _menu.Items.Add(new ToolStripMenuItem("OpenRGB", null, (s, e) => LaunchApp(@"C:\Program Files\OpenRGB\OpenRGB.exe")));
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(new ToolStripMenuItem("Exit", null, (s, e) => ExitApp()));

        _trayIcon = new NotifyIcon
        {
            Icon = CreateIcon(Color.DodgerBlue, "--"),
            Visible = true,
            Text = "PredatorMonitor",
            ContextMenuStrip = _menu
        };
        _trayIcon.DoubleClick += (s, e) => LaunchApp(ThrottleStopPath);

        _timer = new System.Windows.Forms.Timer { Interval = 2000 };
        _timer.Tick += Timer_Tick;
        _timer.Start();
        Timer_Tick(this, EventArgs.Empty);
    }

    private void Timer_Tick(object? sender, EventArgs e)
    {
        try
        {
            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Timer tick...");
            var (profileId, cpuTemp, gpuTemp, cpuFan, gpuFan) = AcerWmi.ReadAll();
            Console.WriteLine($"  Profile={profileId} CPU={cpuTemp}C GPU={gpuTemp}C FanCPU={cpuFan} FanGPU={gpuFan}");

            var profileName = AcerWmi.GetProfileName(profileId);
            var profileColor = profileId switch
            {
                0 => Color.DodgerBlue,
                1 => Color.White,
                2 => Color.Orange,
                3 => Color.Red,
                4 => Color.Magenta,
                _ => Color.Gray
            };

            if (profileId != _lastProfileId && _lastProfileId != ulong.MaxValue)
            {
                // Hardware button pressed - apply fan preset
                if (profileId >= 3) { AcerWmi.SetFanTurbo(); _currentFanMode = "Turbo"; }
                else { AcerWmi.SetFanAuto(); _currentFanMode = "Auto"; }
            }
            _lastProfileId = profileId;

            _profileItem.Text = $"Profile: {profileName}";
            _fanStatusItem.Text = $"Fan: {_currentFanMode}";
            _cpuTempItem.Text = $"CPU: {cpuTemp}°C";
            _gpuTempItem.Text = $"GPU: {gpuTemp}°C";
            _cpuFanItem.Text = $"CPU Fan: {cpuFan} RPM";
            _gpuFanItem.Text = $"GPU Fan: {gpuFan} RPM";

            var maxTemp = Math.Max(cpuTemp, gpuTemp);
            var iconColor = maxTemp switch
            {
                > 95 => Color.Red,
                > 85 => Color.Orange,
                > 70 => Color.Yellow,
                _ => profileColor
            };

            _trayIcon.Icon = CreateIcon(iconColor, $"{cpuTemp}");
            _trayIcon.Text = $"PredatorMonitor | {profileName}\nCPU:{cpuTemp}°C GPU:{gpuTemp}°C\nFan: {cpuFan}/{gpuFan} RPM";
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  ERROR: {ex}");
            _profileItem.Text = $"ERR: {ex.Message}";
            AcerWmi.InvalidateCache();
        }
    }

    private static Icon CreateIcon(Color color, string text)
    {
        var bmp = new Bitmap(16, 16);
        using var g = Graphics.FromImage(bmp);
        g.Clear(Color.Transparent);
        using var brush = new SolidBrush(color);
        g.FillRectangle(brush, 0, 0, 16, 16);
        using var font = new Font("Segoe UI", 7, FontStyle.Bold);
        using var tb = new SolidBrush(Color.White);
        var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        g.DrawString(text, font, tb, new RectangleF(0, 0, 16, 16), sf);
        return Icon.FromHandle(bmp.GetHicon());
    }

    private static void LaunchApp(string path)
    {
        try
        {
            if (!File.Exists(path)) return;
            Process.Start(new ProcessStartInfo(path)
            {
                UseShellExecute = true,
                WorkingDirectory = Path.GetDirectoryName(path)!
            });
        }
        catch { }
    }

    private void ExitApp()
    {
        _timer.Stop();
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
        Application.Exit();
    }
}

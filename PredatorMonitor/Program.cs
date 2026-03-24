namespace PredatorMonitor;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();

        using var mutex = new System.Threading.Mutex(true, "PredatorMonitor_SingleInstance", out bool isNew);
        if (!isNew)
        {
            MessageBox.Show("PredatorMonitor is already running.", "PredatorMonitor", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        Application.Run(new TrayContext());
    }
}

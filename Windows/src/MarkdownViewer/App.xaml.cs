using System.IO;
using System.Windows;

namespace MarkdownViewer;

public partial class App : Application
{
    internal static string? TestDirectory { get; private set; }
    internal static string? TestSettingsPath { get; private set; }
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (e.Args.Length >= 2 && e.Args[0] == "--smoke-test")
        {
            TestDirectory = Path.GetFullPath(e.Args[1]);
            TestSettingsPath = Path.Combine(TestDirectory, "settings-" + Guid.NewGuid().ToString("N") + ".json");
        }
        var paths = TestDirectory is null ? e.Args.Where(a => !a.StartsWith("--")).ToArray() : [];
        // Independent windows also make Explorer multi-select and Open With predictable.
        if (paths.Length == 0)
        {
            var window = new MainWindow(null);
            if (TestDirectory is not null)
            {
                window.ShowActivated = false;
                window.ShowInTaskbar = false;
                window.WindowStartupLocation = WindowStartupLocation.Manual;
                window.Left = 60;
                window.Top = 60;
            }
            window.Show();
        }
        else foreach (var path in paths) new MainWindow(path).Show();
    }
}

using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Win32;

namespace MarkdownViewer;

public partial class MainWindow : Window
{
    private readonly string? _initialPath;
    private readonly TaskCompletionSource _ready = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private AssetServer? _server;
    private string? _currentPath;
    private string _currentText = "";
    private readonly DispatcherTimer _refreshTimer = new() { Interval = TimeSpan.FromMilliseconds(500) };
    private string? _refreshCandidate, _refreshDelivered;
    private bool _refreshBusy;

    private static string? FileStamp(string path)
    {
        try {
            var info = new FileInfo(path);
            return info.Exists ? $"{info.LastWriteTimeUtc.Ticks}/{info.CreationTimeUtc.Ticks}/{info.Length}" : null;
        } catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { return null; }
    }
    private async Task RefreshIfChangedAsync()
    {
        if (_closed || _refreshBusy || _currentPath is not { } path) return;
        var stamp = FileStamp(path);
        if (stamp != _refreshCandidate) { _refreshCandidate = stamp; return; }
        if (stamp is null || stamp == _refreshDelivered) return;
        var version = _openVersion;
        _refreshBusy = true;
        try {
            var file = await LocalFiles.ReadMarkdownAsync(path);
            if (_closed || version != _openVersion || stamp != FileStamp(path)) return;
            _refreshDelivered = stamp;
            if (file.Text == _currentText) return;
            _currentText = file.Text;
            Post(new { type = "render", markdown = file.Text, name = Path.GetFileName(path), baseUrl = _server!.DocumentBaseUrl,
                view = _sourceView ? "source" : "reading", preserveScroll = true });
            StatusLabel.Text = $"{file.Size / 1024d:0.#} KB · Local file · Read only";
            LastError = "";
        } catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException) {
            // Keep the last readable document during partial saves, deletion or replacement; retry.
        } finally { _refreshBusy = false; }
    }
    private string _theme = "system";
    private int _openVersion;
    private bool _closed;
    private bool _initialNavigation = true;
    private bool _sourceView;
    private bool _fullScreen;
    private WindowState _previousState;
    private WindowStyle _previousStyle;
    private ResizeMode _previousResize;
    private readonly ViewerPreferences _preferences;
    private readonly DispatcherTimer _preferencesSaveTimer = new() { Interval = TimeSpan.FromMilliseconds(400) };
    internal string LastError { get; private set; } = "";
    private string SettingsPath => App.TestSettingsPath
        ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MarkdownViewer", "settings.json");

    public MainWindow(string? initialPath)
    {
        InitializeComponent();
        _initialPath = initialPath;
        _refreshTimer.Tick += async (_, _) => await RefreshIfChangedAsync();
        _preferences = ViewerPreferences.Load(SettingsPath);
        _theme = _preferences.Theme;
        PreviewKeyDown += OnPreviewKeyDown;
        SystemEvents.UserPreferenceChanged += OnSystemPreferenceChanged;
        ApplyTheme();
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var dataFolder = App.TestDirectory is { } test
                ? Path.Combine(test, "webview-profile")
                : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MarkdownViewer", "WebView2");
            // An optional Fixed Version runtime can be deployed beside the executable.
            var fixedRuntime = Path.Combine(AppContext.BaseDirectory, "WebView2Runtime");
            var environment = await CoreWebView2Environment.CreateAsync(
                Directory.Exists(fixedRuntime) ? fixedRuntime : null, dataFolder,
                new CoreWebView2EnvironmentOptions { AllowSingleSignOnUsingOSPrimaryAccount = false });
            if (_closed) return;
            await Browser.EnsureCoreWebView2Async(environment);
            var core = Browser.CoreWebView2;
            core.Settings.AreDevToolsEnabled = App.TestDirectory is not null;
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.AreBrowserAcceleratorKeysEnabled = false;
            core.Settings.IsBuiltInErrorPageEnabled = false;
            core.Settings.IsPasswordAutosaveEnabled = false;
            core.Settings.IsGeneralAutofillEnabled = false;
            core.Settings.IsZoomControlEnabled = true;
            _server = new AssetServer(environment);
            core.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
            core.WebResourceRequested += _server.OnRequest;
            core.NavigationStarting += (_, args) =>
            {
                if (!_initialNavigation || args.Uri != AssetServer.PageUrl) args.Cancel = true;
                else _initialNavigation = false;
            };
            core.FrameNavigationStarting += (_, args) => args.Cancel = true;
            core.NavigationCompleted += (_, args) =>
            {
                if (!args.IsSuccess && !_ready.Task.IsCompleted)
                    _ready.TrySetException(new IOException($"The bundled reader could not load ({args.WebErrorStatus})."));
            };
            core.NewWindowRequested += (_, args) => args.Handled = true;
            core.DownloadStarting += (_, args) => args.Cancel = true;
            core.PermissionRequested += (_, args) => args.State = CoreWebView2PermissionState.Deny;
            core.WebMessageReceived += OnWebMessage;
            if (App.TestDirectory is not null)
                await core.AddScriptToExecuteOnDocumentCreatedAsync("window.startupErrors=[]; window.addEventListener('error',e=>window.startupErrors.push(e.message+' at '+e.filename+':'+e.lineno));");
            core.ProcessFailed += (_, _) => ShowError("The reading engine stopped. Close this window and reopen the file.");
            Browser.ZoomFactorChanged += (_, _) => ZoomButton.Content = $"{Browser.ZoomFactor:P0}";
            core.Navigate(AssetServer.PageUrl);
            await _ready.Task.WaitAsync(TimeSpan.FromSeconds(30));
            if (_closed) return;
            StartupPanel.Visibility = Visibility.Collapsed;
            ApplyTheme();
            ApplyDocumentWidth();
            ApplyWorkspace();
            if (_initialPath is not null) await OpenFileAsync(_initialPath);
            if (App.TestDirectory is { } testOutput) await RunSmokeTestsAsync(testOutput);
        }
        catch (Exception ex)
        {
            var explanation = ex is WebView2RuntimeNotFoundException
                ? "Microsoft Edge WebView2 Runtime is required. Install the Evergreen x64 Runtime from Microsoft's WebView2 download page, then reopen 엠디봄. For offline setup, use the standalone installer. See README."
                : "The reader could not start. " + ex.Message;
            StartupText.Text = explanation;
            StartupPanel.Visibility = Visibility.Visible;
            ShowError(explanation);
            if (App.TestDirectory is { } testOutput)
            {
                Directory.CreateDirectory(testOutput);
                string? diagnostics = null;
                try { diagnostics = await Browser.ExecuteScriptAsync("JSON.stringify({errors:window.startupErrors,html:document.documentElement.outerHTML,marked:typeof marked,purify:typeof DOMPurify,highlight:typeof hljs})"); } catch { }
                await File.WriteAllTextAsync(Path.Combine(testOutput, "results.json"), JsonSerializer.Serialize(new { passed = false, error = ex.ToString(), diagnostics }));
                Application.Current.Shutdown(1);
            }
        }
    }

    internal async Task OpenFileAsync(string path)
    {
        var version = ++_openVersion;
        try
        {
            StatusLabel.Text = "Opening document…";
            await _ready.Task.WaitAsync(TimeSpan.FromSeconds(30));
            var file = await LocalFiles.ReadMarkdownAsync(path);
            if (version != _openVersion || _closed) return;
            var preserveScroll = string.Equals(_currentPath, file.Path, StringComparison.OrdinalIgnoreCase);
            _currentPath = file.Path;
            _currentText = file.Text;
            _refreshCandidate = _refreshDelivered = null;
            _refreshTimer.Start();
            _server!.DocumentDirectory = Path.GetDirectoryName(file.Path);
            _server.DocumentToken = Guid.NewGuid().ToString("N");
            Title = $"{Path.GetFileName(file.Path)} — 엠디봄";
            LastError = "";
            Post(new { type = "render", markdown = file.Text, name = Path.GetFileName(file.Path), baseUrl = _server.DocumentBaseUrl, view = _sourceView ? "source" : "reading", preserveScroll });
            StatusLabel.Text = $"{file.Size / 1024d:0.#} KB · Local file · Read only";
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException or TimeoutException)
        {
            if (version == _openVersion) ShowError(ex.Message);
        }
    }

    private async void OnWebMessage(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        if (e.Source != AssetServer.PageUrl) return;
        try
        {
            using var message = JsonDocument.Parse(e.WebMessageAsJson);
            var root = message.RootElement;
            switch (root.GetProperty("type").GetString())
            {
                case "workspace":
                    if (root.GetProperty("action").GetString() == "command") ExecuteCommand(root.GetProperty("command").GetString());
                    else ChangeWorkspace(root.GetProperty("key").GetString(), root.GetProperty("value").GetString());
                    break;
                case "printReady":
                    if (_printRequested) { _printRequested = false; Browser.CoreWebView2.ShowPrintUI(CoreWebView2PrintDialogKind.Browser); }
                    break;
                case "ready": _ready.TrySetResult(); break;
                case "open": OpenDialog(); break;
                case "drop":
                    var files = e.AdditionalObjects.OfType<CoreWebView2File>().ToArray();
                    if (files.Length > 0) await OpenFileAsync(files[0].Path);
                    break;
                case "command": ExecuteCommand(root.GetProperty("command").GetString()); break;
                case "error": ShowError(root.GetProperty("message").GetString() ?? "Could not render this document."); break;
                case "link": await OpenLinkAsync(root.GetProperty("url").GetString()!); break;
            }
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException or IOException or ArgumentException or UnauthorizedAccessException or NotSupportedException)
        { ShowError(ex.Message); }
    }

    private async Task OpenLinkAsync(string link)
    {
        if (!Uri.TryCreate(link, UriKind.Absolute, out var uri)) return;
        if (uri.Scheme is "https" or "http" or "mailto")
        {
            if (uri.Host == AssetServer.DocumentHost && _server?.DocumentDirectory is { } directory)
            {
                var prefix = $"/{_server.DocumentToken}/";
                if (!uri.AbsolutePath.StartsWith(prefix, StringComparison.Ordinal)) return;
                var path = LocalFiles.ResolveWithinDirectory(directory, Uri.UnescapeDataString(uri.AbsolutePath[prefix.Length..]));
                if (LocalFiles.IsMarkdown(path)) await OpenFileAsync(path);
                else ShowError("Only Markdown links can be opened inside the reader.");
            }
            else if (uri.Host != AssetServer.AppHost)
            {
                try { Process.Start(new ProcessStartInfo(uri.AbsoluteUri) { UseShellExecute = true }); }
                catch (Exception ex) { ShowError("Could not open the link: " + ex.Message); }
            }
        }
    }

    private void OpenDialog()
    {
        var dialog = new OpenFileDialog { Title = "Open Markdown", Filter = "Markdown documents (*.md;*.markdown)|*.md;*.markdown", CheckFileExists = true };
        if (dialog.ShowDialog(this) == true) _ = OpenFileAsync(dialog.FileName);
    }

    private void Post(object payload)
    {
        if (!_closed && Browser.CoreWebView2 is not null) Browser.CoreWebView2.PostWebMessageAsJson(JsonSerializer.Serialize(payload));
    }

    private void ShowError(string message)
    {
        LastError = message;
        StatusLabel.Text = message;
        StatusLabel.ToolTip = message;
        if (_ready.Task.IsCompletedSuccessfully) Post(new { type = "notice", message });
    }

    private bool _printRequested;

    private void ExecuteCommand(string? command)
    {
        switch (command)
        {
            case "fullscreen": ToggleFullScreen(); break;
            case "exitFullscreen": if (_fullScreen) ToggleFullScreen(); break;
            case "toolbar": ChangeWorkspace("toolbar", _preferences.Toolbar == "always" ? "auto" : "always"); break;
            case "open": OpenDialog(); break;
            case "reload": if (_currentPath is not null) _ = OpenFileAsync(_currentPath); break;
            case "find": Post(new { type = "find" }); break;
            case "print":
                if (_currentPath is not null && Browser.CoreWebView2 is not null)
                { _printRequested = true; Post(new {type="preparePrint"}); }
                break;
            case "source": ToggleSourceView(); break;
            case "theme": CycleTheme(); break;
            case "zoomIn": SetZoom(Browser.ZoomFactor + 0.1); break;
            case "zoomOut": SetZoom(Browser.ZoomFactor - 0.1); break;
            case "zoomReset": SetZoom(1); break;
        }
    }
    private void SetZoom(double zoom) { if (Browser.CoreWebView2 is not null) Browser.ZoomFactor = Math.Clamp(zoom, 0.5, 2.5); }

    private void ToggleSourceView()
    {
        if (_currentPath is null || !_ready.Task.IsCompletedSuccessfully) return;
        _preferences.Layout = "single"; ApplyWorkspace();
        _sourceView = !_sourceView;
        Post(new { type = "view", view = _sourceView ? "source" : "reading" });
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        string? command = null;
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
            command = e.Key switch
            {
                Key.O => "open", Key.P => "print", Key.R => "reload", Key.F => "find", Key.U => "source",
                Key.H when Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) => "toolbar",
                Key.T when Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) => "theme",
                Key.Add or Key.OemPlus => "zoomIn", Key.Subtract or Key.OemMinus => "zoomOut",
                Key.D0 or Key.NumPad0 => "zoomReset", _ => null
            };
        else if (e.Key == Key.F11) command = "fullscreen";
        else if (e.Key == Key.Escape && _fullScreen) command = "exitFullscreen";
        else if (e.Key == Key.F5) command = "reload";
        if (command is not null) { e.Handled = true; ExecuteCommand(command); }
    }

    private void ApplyWorkspace()
    {
        Post(new { type = "presentation", layout = _preferences.Layout, toolbar = _preferences.Toolbar,
            sync = _preferences.SyncScroll, ratio = _preferences.SplitRatio,
            reading = _preferences.ReadingFullWidth ? 0 : _preferences.ReadingWidth,
            readingFont = _preferences.ReadingFont, sourceFont = _preferences.SourceFont,
            readingFontSize = _preferences.ReadingFontSize, sourceFontSize = _preferences.SourceFontSize,
            source = _preferences.SourceFullWidth ? 0 : _preferences.SourceWidth });
    }
    private void ChangeWorkspace(string? key, string? value)
    {
        switch (key)
        {
            case "view" when value is "reading" or "source" or "horizontal" or "vertical":
                _preferences.Layout = value is "reading" or "source" ? "single" : value;
                _sourceView = value == "source";
                ApplyWorkspace(); Post(new {type="view", view=_sourceView ? "source" : "reading"}); break;
            case "toolbar" when value is "always" or "auto": _preferences.Toolbar = value; break;
            case "sync": _preferences.SyncScroll = value == "true"; break;
            case "ratio": if (int.TryParse(value, out var ratio)) _preferences.SplitRatio = Math.Clamp(ratio,20,80); break;
            case "readingFont": case "sourceFont":
                if (value is "system" or "sans" or "serif" or "mono") {
                    if (key == "readingFont") _preferences.ReadingFont = value; else _preferences.SourceFont = value;
                }
                break;
            case "readingFontSize": case "sourceFontSize":
                if (int.TryParse(value, out var size) && size >= 12 && size <= 28) {
                    if (key == "readingFontSize") _preferences.ReadingFontSize = size; else _preferences.SourceFontSize = size;
                }
                break;
            case "readingWidth": case "sourceWidth":
                if (int.TryParse(value, out var width) && (width == 0 || width >= ViewerPreferences.MinimumWidth && width <= ViewerPreferences.MaximumWidth))
                {
                    if (key == "readingWidth") { _preferences.ReadingFullWidth = width == 0; if (width > 0) _preferences.ReadingWidth = width; }
                    else { _preferences.SourceFullWidth = width == 0; if (width > 0) _preferences.SourceWidth = width; }
                    ApplyDocumentWidth();
                }
                break;
        }
        ApplyWorkspace(); SavePreferences();
    }
    private void ToggleFullScreen()
    {
        if (!_fullScreen)
        {
            _previousState = WindowState; _previousStyle = WindowStyle; _previousResize = ResizeMode;
            WindowState = WindowState.Normal; WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize; WindowState = WindowState.Maximized; _fullScreen = true;
        }
        else
        {
            WindowState = WindowState.Normal; WindowStyle = _previousStyle;
            ResizeMode = _previousResize; WindowState = _previousState; _fullScreen = false;
        }
    }
    private void CycleTheme()
    {
        _theme = _theme switch { "system" => "light", "light" => "dark", _ => "system" };
        ApplyTheme();
        SavePreferences();
    }

    private void ApplyDocumentWidth()
    {
        if (_ready.Task.IsCompletedSuccessfully)
            Post(new { type = "width", reading = _preferences.ReadingFullWidth ? 0 : _preferences.ReadingWidth,
                readingFont = _preferences.ReadingFont, sourceFont = _preferences.SourceFont,
            readingFontSize = _preferences.ReadingFontSize, sourceFontSize = _preferences.SourceFontSize,
            source = _preferences.SourceFullWidth ? 0 : _preferences.SourceWidth });
    }

    private void SavePreferences()
    {
        _preferencesSaveTimer.Stop();
        _preferences.Theme = _theme;
        try { _preferences.Save(SettingsPath); }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
    }

    private void ApplyTheme()
    {
        var dark = _theme == "dark";
        if (_theme == "system")
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            dark = key?.GetValue("AppsUseLightTheme") is int value && value == 0;
        }
        var colors = dark ? new[] { "#0D1117", "#161B22", "#E6EDF3", "#8B949E", "#30363D", "#252D38" }
            : new[] { "#F6F8FA", "#FFFFFF", "#1F2328", "#656D76", "#D8DEE4", "#EAEFF5" };
        var names = new[] { "WindowBrush", "PanelBrush", "TextBrush", "MutedBrush", "BorderBrush", "HoverBrush" };
        for (var i = 0; i < names.Length; i++) Resources[names[i]] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(colors[i]));
        Browser.DefaultBackgroundColor = dark ? System.Drawing.Color.FromArgb(13, 17, 23) : System.Drawing.Color.White;
        if (_ready.Task.IsCompletedSuccessfully) Post(new { type = "theme", theme = dark ? "dark" : "light" });
        var handle = new WindowInteropHelper(this).Handle;
        if (handle != IntPtr.Zero) { var value = dark ? 1 : 0; DwmSetWindowAttribute(handle, 20, ref value, sizeof(int)); }
    }

    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    private void OnSystemPreferenceChanged(object sender, UserPreferenceChangedEventArgs e) { if (!_closed) Dispatcher.BeginInvoke(ApplyTheme); }
    private void Window_DragOver(object sender, DragEventArgs e) { e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None; e.Handled = true; }
    private async void Window_Drop(object sender, DragEventArgs e) { e.Handled = true; if (e.Data.GetData(DataFormats.FileDrop) is string[] { Length: > 0 } paths) await OpenFileAsync(paths[0]); }
    private void ZoomOut_Click(object sender, RoutedEventArgs e) => ExecuteCommand("zoomOut");
    private void ZoomIn_Click(object sender, RoutedEventArgs e) => ExecuteCommand("zoomIn");
    private void ResetZoom_Click(object sender, RoutedEventArgs e) => SetZoom(1);
    private void Window_Closed(object? sender, EventArgs e)
    {
        if (_preferencesSaveTimer.IsEnabled) SavePreferences();
        _closed = true;
        _refreshTimer.Stop();
        SystemEvents.UserPreferenceChanged -= OnSystemPreferenceChanged;
        Browser.Dispose();
    }
}

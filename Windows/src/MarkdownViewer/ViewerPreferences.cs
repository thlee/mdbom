using System.IO;
using System.Text.Json;

namespace MarkdownViewer;

internal sealed class ViewerPreferences
{
    internal static int MinimumWidth => InterfaceSpec.Width("minimum");
    internal static int MaximumWidth => InterfaceSpec.Width("maximum");
    public string Layout { get; set; } = "single";
    public string Toolbar { get; set; } = "always";
    public bool SyncScroll { get; set; } = true;
    public int SplitRatio { get; set; } = 50;
    internal string Theme { get; set; } = "system";
    internal int ReadingWidth { get; set; } = InterfaceSpec.Width("readingDefault");
    internal int SourceWidth { get; set; } = InterfaceSpec.Width("sourceDefault");
    internal bool ReadingFullWidth { get; set; }
    internal bool SourceFullWidth { get; set; }

    internal string ReadingFont { get; set; } = "system";
    internal int ReadingFontSize { get; set; } = 16;
    internal string SourceFont { get; set; } = "mono";
    internal int SourceFontSize { get; set; } = 14;

    internal static ViewerPreferences Load(string path)
    {
        var preferences = new ViewerPreferences();
        try
        {
            using var json = JsonDocument.Parse(File.ReadAllText(path));
            var root = json.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return preferences;
            if (root.TryGetProperty("readingFont", out var readingFont) && readingFont.ValueKind == JsonValueKind.String && readingFont.GetString() is "system" or "sans" or "serif" or "mono") preferences.ReadingFont = readingFont.GetString()!;
            if (root.TryGetProperty("readingFontSize", out var readingSize) && readingSize.ValueKind == JsonValueKind.Number && readingSize.TryGetInt32(out var readingPixels)) preferences.ReadingFontSize = Math.Clamp(readingPixels,12,28);
            if (root.TryGetProperty("sourceFont", out var sourceFont) && sourceFont.ValueKind == JsonValueKind.String && sourceFont.GetString() is "system" or "sans" or "serif" or "mono") preferences.SourceFont = sourceFont.GetString()!;
            if (root.TryGetProperty("sourceFontSize", out var sourceSize) && sourceSize.ValueKind == JsonValueKind.Number && sourceSize.TryGetInt32(out var sourcePixels)) preferences.SourceFontSize = Math.Clamp(sourcePixels,12,28);

            if (root.TryGetProperty("layout", out var layout) && layout.ValueKind == JsonValueKind.String && layout.GetString() is "single" or "horizontal" or "vertical") preferences.Layout = layout.GetString()!;
            if (root.TryGetProperty("toolbar", out var toolbar) && toolbar.ValueKind == JsonValueKind.String && toolbar.GetString() is "always" or "auto" or "hidden") preferences.Toolbar = toolbar.GetString() == "hidden" ? "auto" : toolbar.GetString()!;
            if (root.TryGetProperty("syncScroll", out var sync) && sync.ValueKind is JsonValueKind.True or JsonValueKind.False) preferences.SyncScroll = sync.GetBoolean();
            if (root.TryGetProperty("splitRatio", out var ratio) && ratio.TryGetInt32(out var r)) preferences.SplitRatio = Math.Clamp(r,20,80);
            if (root.TryGetProperty("theme", out var theme) && theme.ValueKind == JsonValueKind.String &&
                theme.GetString() is "system" or "light" or "dark") preferences.Theme = theme.GetString()!;
            if (root.TryGetProperty("readingWidth", out var reading) && reading.ValueKind == JsonValueKind.Number && reading.TryGetInt32(out var rw))
                preferences.ReadingWidth = Math.Clamp(rw, MinimumWidth, MaximumWidth);
            if (root.TryGetProperty("sourceWidth", out var source) && source.ValueKind == JsonValueKind.Number && source.TryGetInt32(out var sw))
                preferences.SourceWidth = Math.Clamp(sw, MinimumWidth, MaximumWidth);
            if (root.TryGetProperty("readingFullWidth", out var rf) && rf.ValueKind is JsonValueKind.True or JsonValueKind.False)
                preferences.ReadingFullWidth = rf.GetBoolean();
            if (root.TryGetProperty("sourceFullWidth", out var sf) && sf.ValueKind is JsonValueKind.True or JsonValueKind.False)
                preferences.SourceFullWidth = sf.GetBoolean();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException) { }
        return preferences;
    }

    internal void Save(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(new
            {
                readingFont = ReadingFont, readingFontSize = ReadingFontSize,
                sourceFont = SourceFont, sourceFontSize = SourceFontSize,
                layout = Layout, toolbar = Toolbar, syncScroll = SyncScroll, splitRatio = SplitRatio,
                theme = Theme, readingWidth = ReadingWidth, sourceWidth = SourceWidth,
                readingFullWidth = ReadingFullWidth, sourceFullWidth = SourceFullWidth
            }));
            File.Move(temporary, path, overwrite: true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}

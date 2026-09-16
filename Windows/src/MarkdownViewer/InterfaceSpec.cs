using System.Reflection;
using System.Text.Json;

namespace MarkdownViewer;

internal static class InterfaceSpec
{
    private static readonly JsonElement Root = Load();
    private static JsonElement Load()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("Assets/interface.json")!;
        using var document = JsonDocument.Parse(stream);
        return document.RootElement.Clone();
    }
    internal static string Label(string key) => Root.GetProperty("labels").GetProperty(key).GetString()!;
    internal static int Width(string key) => Root.GetProperty("width").GetProperty(key).GetInt32();
    internal static IEnumerable<(string Title, int Value)> Presets => Root.GetProperty("presets").EnumerateArray()
        .Select(p => (p.GetProperty("title").GetString()!, p.GetProperty("value").GetInt32()));
}

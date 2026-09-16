using System.IO;
using System.Reflection;
using Microsoft.Web.WebView2.Core;

namespace MarkdownViewer;

internal sealed class AssetServer
{
    internal const string AppHost = "app.markdownviewer.invalid";
    internal const string DocumentHost = "document.markdownviewer.invalid";
    internal const string PageUrl = "https://" + AppHost + "/index.html";
    private readonly CoreWebView2Environment _environment;
    private readonly Dictionary<string, byte[]> _assets = new(StringComparer.Ordinal);
    internal string? DocumentDirectory { get; set; }
    internal string DocumentToken { get; set; } = Guid.NewGuid().ToString("N");
    internal string DocumentBaseUrl => $"https://{DocumentHost}/{DocumentToken}/";
    internal int BlockedRequests { get; private set; }

    internal AssetServer(CoreWebView2Environment environment)
    {
        _environment = environment;
        var assembly = Assembly.GetExecutingAssembly();
        foreach (var resource in assembly.GetManifestResourceNames())
        {
            var name = resource.Replace('\\', '/');
            if (!name.StartsWith("Assets/", StringComparison.Ordinal)) continue;
            using var stream = assembly.GetManifestResourceStream(resource)!;
            using var bytes = new MemoryStream();
            stream.CopyTo(bytes);
            _assets["/" + name[7..]] = bytes.ToArray();
        }
    }

    internal void OnRequest(object? sender, CoreWebView2WebResourceRequestedEventArgs e)
    {
        try
        {
            var uri = new Uri(e.Request.Uri);
            if (e.Request.Method == "GET" && uri.Scheme == "https" && uri.IsDefaultPort)
            {
                if (uri.Host == AppHost && _assets.TryGetValue(uri.AbsolutePath, out var asset))
                {
                    Respond(e, asset, Mime(uri.AbsolutePath));
                    return;
                }
                if (uri.Host == DocumentHost && DocumentDirectory is not null &&
                    uri.AbsolutePath.StartsWith($"/{DocumentToken}/", StringComparison.Ordinal) &&
                    e.ResourceContext == CoreWebView2WebResourceContext.Image)
                {
                    var relative = Uri.UnescapeDataString(uri.AbsolutePath[(DocumentToken.Length + 2)..]);
                    var path = LocalFiles.ResolveWithinDirectory(DocumentDirectory, relative);
                    var mime = Mime(path);
                    if (mime.StartsWith("image/", StringComparison.Ordinal) && new FileInfo(path).Length <= 20 * 1024 * 1024)
                    {
                        Respond(e, File.ReadAllBytes(path), mime);
                        return;
                    }
                }
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException) { }
        BlockedRequests++;
        e.Response = _environment.CreateWebResourceResponse(new MemoryStream(), 403, "Blocked", "Content-Type: text/plain\r\nCache-Control: no-store");
    }

    private void Respond(CoreWebView2WebResourceRequestedEventArgs e, byte[] bytes, string mime) =>
        e.Response = _environment.CreateWebResourceResponse(new MemoryStream(bytes, writable: false), 200, "OK",
            $"Content-Type: {mime}\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff");

    private static string Mime(string path) => Path.GetExtension(path).ToLowerInvariant() switch
    {
        ".html" => "text/html; charset=utf-8", ".js" => "text/javascript; charset=utf-8", ".css" => "text/css; charset=utf-8",
        ".png" => "image/png", ".jpg" or ".jpeg" => "image/jpeg", ".gif" => "image/gif", ".webp" => "image/webp",
        ".bmp" => "image/bmp", ".ico" => "image/x-icon", _ => "application/octet-stream"
    };
}

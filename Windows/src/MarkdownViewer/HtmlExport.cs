using System.IO;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;

namespace MarkdownViewer;

public partial class MainWindow
{
    private TaskCompletionSource<string>? _exportSnapshot;
    private bool _exporting;

    private async Task ExportHtmlAsync()
    {
        if (_exporting || _currentPath is null || !_ready.Task.IsCompletedSuccessfully) return;
        _exporting = true;
        try
        {
            var source = _currentPath;
            var html = await CreateHtmlExportAsync();
            var dialog = new SaveFileDialog {
                Title = "HTML로 내보내기", Filter = "HTML document (*.html)|*.html",
                FileName = Path.GetFileNameWithoutExtension(source) + ".html",
                DefaultExt = ".html", AddExtension = true, OverwritePrompt = true
            };
            if (dialog.ShowDialog(this) != true) return;
            if (Path.GetExtension(dialog.FileName).ToLowerInvariant() is not (".html" or ".htm"))
                throw new IOException("Please save with an .html extension.");
            // Write to a temporary sibling first, so failures do not truncate an existing file.
            var temporary = dialog.FileName + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try {
                await File.WriteAllTextAsync(temporary, html, new UTF8Encoding(false));
                File.Move(temporary, dialog.FileName, overwrite: true);
            } finally { if (File.Exists(temporary)) File.Delete(temporary); }
            StatusLabel.Text = "HTML 저장 완료: " + Path.GetFileName(dialog.FileName);
        }
        catch (Exception ex) { ShowError("HTML 내보내기 실패: " + ex.Message); }
        finally { _exporting = false; }
    }

    internal async Task<string> CreateHtmlExportAsync()
    {
        if (_exportSnapshot is not null) throw new InvalidOperationException("Export already in progress.");
        var directory = _server?.DocumentDirectory ?? throw new IOException("Open a document first.");
        var prefix = _server!.DocumentBaseUrl;
        var revision = _openVersion;
        var request = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
        _exportSnapshot = request;
        try {
            Post(new { type = "prepareExport" });
            var snapshot = await request.Task.WaitAsync(TimeSpan.FromSeconds(60));
            if (revision != _openVersion) throw new IOException("Document changed while preparing export. Please try again.");
            using var parsed = JsonDocument.Parse(snapshot);
            var images = new Dictionary<string,string>();
            long total = 0;
            foreach (var item in parsed.RootElement.GetProperty("images").EnumerateArray()) {
                var src = item.GetString() ?? "";
                if (src.StartsWith("data:image/", StringComparison.Ordinal)) continue;
                if (!src.StartsWith(prefix, StringComparison.Ordinal)) throw new IOException("Unsupported image location.");
                var uri = new Uri(src);
                var relative = Uri.UnescapeDataString(uri.AbsolutePath[new Uri(prefix).AbsolutePath.Length..]);
                var path = LocalFiles.ResolveWithinDirectory(directory, relative);
                var mime = Path.GetExtension(path).ToLowerInvariant() switch {
                    ".png"=>"image/png", ".jpg" or ".jpeg"=>"image/jpeg", ".gif"=>"image/gif",
                    ".webp"=>"image/webp", ".bmp"=>"image/bmp", ".ico"=>"image/x-icon", ".svg"=>"image/svg+xml",
                    _=>throw new IOException("Unsupported image type.")
                };
                await using var stream = File.OpenRead(path);
                if (stream.Length > 20*1024*1024 || total + stream.Length > 100*1024*1024)
                    throw new IOException("Export images exceed the 20 MiB per image / 100 MiB total limit.");
                var bytes = new byte[(int)stream.Length];
                await stream.ReadExactlyAsync(bytes);
                total += bytes.Length;
                images[src] = "data:"+mime+";base64,"+Convert.ToBase64String(bytes);
            }
            var json = await Browser.ExecuteScriptAsync("MarkdownViewerCore.buildHTML("+snapshot+","+JsonSerializer.Serialize(images)+")");
            return JsonSerializer.Deserialize<string>(json) ?? throw new IOException("Unable to generate HTML.");
        } finally { _exportSnapshot = null; }
    }
}


using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Web.WebView2.Core;

namespace MarkdownViewer;

public partial class MainWindow
{
    // Runs against the actual embedded WebView2 engine, without network test fixtures.
    private async Task RunSmokeTestsAsync(string directory)
    {
        Directory.CreateDirectory(directory);
        var checks = new List<object>();
        var failures = 0;
        void Check(string name, bool passed) { checks.Add(new { name, passed }); if (!passed) failures++; }
        async Task<bool> Js(string expression) => await Browser.ExecuteScriptAsync($"Boolean({expression})") == "true";
        async Task WaitUntil(string expression)
        {
            for (var i = 0; i < 100; i++) { if (await Js(expression)) return; await Task.Delay(100); }
            throw new TimeoutException("Timed out: " + expression);
        }
        async Task OpenAndWait(string path)
        {
            var before = await Browser.ExecuteScriptAsync("document.documentElement.dataset.renderCount || '0'");
            await OpenFileAsync(path);
            if (LastError.Length > 0) throw new IOException(LastError);
            await WaitUntil($"document.documentElement.dataset.renderCount !== {before}");
        }
        try
        {
            Check("Bundled renderer boots offline", await Js("window.MarkdownViewerCore?.apiVersion === 1 && typeof MarkdownViewerCore.render === 'function'"));
            Check("Source view disabled before opening a document", _currentPath is null);
            await CaptureWindowAsync(Path.Combine(directory, "welcome.png"));
            var fixtureDir = Path.Combine(directory, "fixtures");
            Directory.CreateDirectory(fixtureDir);
            var fixture = Path.Combine(fixtureDir, "한글 document.markdown");
            var markdown = """
                # Rendering check
                Unicode: 한글 日本語 ✨

                | Item | Value |
                | --- | ---: |
                | Works | 42 |

                - [x] Complete
                - [ ] Pending

                ```csharp
                var message = "Hello";
                Console.WriteLine(message);
                ```

                ```unknown-language
                <script>literal code</script>
                ```

                [Jump](#another-heading)

                ## Another heading

                **bold** and ~~removed~~ and `inline`

                ![local](pixel.png)
                ![remote](https://example.com/should-never-load.png)
                <img src=x onerror="window.injected=true">
                <script>window.injected=true</script>
                <iframe src="https://example.com"></iframe>
                <svg onload="window.injected=true"></svg>
                <form><input type=text value=edit></form>
                <a href="javascript:window.injected=true">bad link</a>
                <div id="content" name="chrome" style="position:fixed">Safe text</div>
                """;
            await File.WriteAllTextAsync(fixture, markdown, new UTF8Encoding(false));
            var originalHash = SHA256.HashData(await File.ReadAllBytesAsync(fixture));
            await File.WriteAllBytesAsync(Path.Combine(fixtureDir, "pixel.png"), Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="));
            await OpenAndWait(fixture);
            Check("Unicode filename and title", Title == "한글 document.markdown — 엠디봄");
            Check("Unicode document text", await Js("document.getElementById('content').textContent.includes('한글 日本語 ✨')"));
            Check("GFM table", await Js("document.querySelectorAll('#content table tbody tr').length === 1"));
            Check("Task lists are disabled", await Js("document.querySelectorAll('#content input:disabled').length === 2 && document.querySelectorAll('#content input:checked').length === 1"));
            Check("Fenced code is highlighted", await Js("document.querySelectorAll('#content .hljs-keyword').length > 0"));
            Check("Unknown code language remains literal", await Js("document.querySelector('#content .language-unknown-language').textContent.includes('<script>literal code</script>')"));
            Check("Sanitizer removes executable markup", await Js("!window.injected && !document.querySelector('#content script, #content iframe, #content svg, #content form, #content [onerror], #content [style], #content input:not([type=checkbox])')"));
            Check("Sanitizer prevents DOM clobbering", await Js("document.querySelectorAll('#content').length === 1 && !document.querySelector('#content [name]')"));
            Check("Unsafe links removed", await Js("![...document.querySelectorAll('#content a')].some(a=>a.href.startsWith('javascript:'))"));
            Check("External images suppressed", await Js("!document.querySelector('#content img[src^=\"https://example.com\"]') && document.querySelector('.image-placeholder') !== null"));
            await WaitUntil("document.querySelector('#content img').complete");
            Check("Relative local image loads", await Js("document.querySelector('#content img').naturalWidth === 1"));
            Check("Heading anchors", await Js("document.getElementById('another-heading') !== null"));
            Check("Shared stylesheet renders right-aligned tables", await Js("getComputedStyle(document.querySelector('#content td[align=right]')).textAlign === 'right'"));
            Check("Shared parser handles nested and loose task lists", await Js("(() => { const f=MarkdownViewerCore.render('- [x] Parent\\n  - [ ] Child\\n\\n- [X] Loose\\n\\n  paragraph'); return f.querySelectorAll('.task-list-item').length === 3 && f.querySelectorAll('input:disabled').length === 3; })()"));
            Check("Shared sanitizer strips application classes", await Js("!MarkdownViewerCore.render('<div class=welcome>visible</div>').querySelector('[class]')"));
            Check("Shared renderer supports macOS document URLs", await Js("MarkdownViewerCore.render('[Next](next.md)').querySelector('a').href === 'mdviewer://document/next.md'"));
            Check("Shared renderer bounds Windows relative links", await Js("(() => { const f=MarkdownViewerCore.render('[Next](next.md) [Escape](../outside.md)', {baseURL:'https://document.markdownviewer.invalid/token/'}); return f.querySelectorAll('a[href]').length===1 && f.querySelector('a').href==='https://document.markdownviewer.invalid/token/next.md'; })()"));
            var nextDocument = Path.Combine(fixtureDir, "next.md");
            await File.WriteAllTextAsync(nextDocument, "# Linked document");
            await File.WriteAllTextAsync(fixture, "[Next](next.md)");
            await OpenAndWait(fixture);
            await Browser.ExecuteScriptAsync("document.querySelector('#content a').click()");
            await WaitUntil("document.querySelector('#content h1')?.textContent === 'Linked document'");
            Check("Relative Markdown link reaches the native reader", Title == "next.md — 엠디봄");
            await File.WriteAllTextAsync(fixture, markdown, new UTF8Encoding(false));
            await OpenAndWait(fixture);
            Post(new { type = "theme", theme = "dark" });
            await WaitUntil("document.documentElement.dataset.theme === 'dark'");
            Check("Dark theme", await Js("getComputedStyle(document.body).backgroundColor === 'rgb(13, 17, 23)'"));
            ExecuteCommand("find");
            await WaitUntil("!document.getElementById('findbar').hidden");
            Check("Find panel keyboard focus", await Js("document.activeElement.id === 'findinput'"));
            await Browser.ExecuteScriptAsync("document.getElementById('findinput').value='Unicode'; document.getElementById('findnext').click()");
            Check("Find locates text", await Js("[...CSS.highlights.get('current-match')][0].toString() === 'Unicode' && document.getElementById('findresult').textContent === '1 / 1'"));
            await Browser.ExecuteScriptAsync("document.getElementById('findinput').value='[missing.*]'; document.getElementById('findnext').click()");
            Check("Find treats regex punctuation literally", await Js("document.getElementById('findresult').textContent === 'No match'"));
            SetZoom(1.2);
            Check("Native zoom", Math.Abs(Browser.ZoomFactor - 1.2) < 0.001);
            SetZoom(1);
            await Browser.ExecuteScriptAsync("document.getElementById('findclose').click(); window.scrollTo(0,120)");
            ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'source'");
            Check("Toolbar switches to source view", await Js("document.getElementById('content').hidden && !document.getElementById('sourcecontent').hidden"));
            Check("Source preserves the exact decoded Markdown", JsonSerializer.Deserialize<string>(await Browser.ExecuteScriptAsync("document.getElementById('sourcecontent').textContent")) == markdown);
            Check("Source HTML remains inert text", await Js("document.getElementById('sourcecontent').children.length === 0 && !window.injected && !document.getElementById('sourcecontent').isContentEditable"));
            await Browser.ExecuteScriptAsync("var selectionRange=document.createRange(); selectionRange.selectNodeContents(document.getElementById('sourcecontent')); window.getSelection().removeAllRanges(); window.getSelection().addRange(selectionRange)");
            Check("Source text can be selected for copying", JsonSerializer.Deserialize<string>(await Browser.ExecuteScriptAsync("window.getSelection().toString()")) == markdown);
            ExecuteCommand("find");
            await WaitUntil("!document.getElementById('findbar').hidden");
            await Browser.ExecuteScriptAsync("document.getElementById('findinput').value='[Jump](#another-heading)'; document.getElementById('findnext').click()");
            Check("Source search finds Markdown syntax only in the active view", await Js("document.getElementById('findresult').textContent === '1 / 1' && document.getElementById('sourcecontent').contains([...CSS.highlights.get('current-match')][0].startContainer)"));
            Check("Source search scrolls to the matched line", await Js("[...CSS.highlights.get('current-match')][0].getBoundingClientRect().top >= 0 && [...CSS.highlights.get('current-match')][0].getBoundingClientRect().bottom <= window.innerHeight"));
            Check("Source uses dark theme colors", await Js("getComputedStyle(document.getElementById('sourcecontent')).color === 'rgb(230, 237, 243)'"));
            await Browser.ExecuteScriptAsync("document.getElementById('findclose').click(); window.scrollTo(0,300)");
            await Browser.ExecuteScriptAsync("document.dispatchEvent(new KeyboardEvent('keydown',{key:'u',ctrlKey:true,bubbles:true,cancelable:true}))");
            await WaitUntil("document.documentElement.dataset.view === 'reading'");
            Check("Ctrl+U returns to reading view", !_sourceView && !await Js("document.getElementById('content').hidden"));
            ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'source'");
            Check("Documents remain unchanged", originalHash.SequenceEqual(SHA256.HashData(await File.ReadAllBytesAsync(fixture))));
            await File.WriteAllTextAsync(fixture, "# Reloaded\nUpdated on disk.");
            await OpenAndWait(fixture);
            Check("Reload sees disk changes", await Js("document.querySelector('#content h1').textContent === 'Reloaded'"));
            Check("Reload updates source and retains source mode", await Js("document.documentElement.dataset.view === 'source' && document.getElementById('sourcecontent').textContent === '# Reloaded\\nUpdated on disk.'"));
            var empty = Path.Combine(fixtureDir, "empty.md");
            await File.WriteAllTextAsync(empty, "");
            await OpenAndWait(empty);
            Check("Empty document", await Js("document.querySelector('.empty-document') !== null"));
            Check("Empty source has a clear empty state", await Js("document.getElementById('sourcecontent').textContent === '' && !document.getElementById('sourceempty').hidden"));
            ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'reading'");
            var utf16 = Path.Combine(fixtureDir, "utf16.md");
            await File.WriteAllTextAsync(utf16, "# UTF-16 한글", Encoding.Unicode);
            await OpenAndWait(utf16);
            Check("UTF-16 BOM", await Js("document.querySelector('#content h1').textContent === 'UTF-16 한글'"));
            await OpenFileAsync(Path.Combine(fixtureDir, "missing.md"));
            Check("Missing file gives recoverable error", LastError.Length > 0);
            var wrongType = Path.Combine(fixtureDir, "wrong.txt");
            await File.WriteAllTextAsync(wrongType, "hello");
            await OpenFileAsync(wrongType);
            Check("Non-Markdown file rejected", LastError.Contains(".markdown"));
            var large = Path.Combine(fixtureDir, "too-large.md");
            using (var stream = File.Create(large)) stream.SetLength(LocalFiles.MaximumDocumentBytes + 1);
            await OpenFileAsync(large);
            Check("Oversized document rejected", LastError.Contains("16 MB"));
            try { LocalFiles.ResolveWithinDirectory(fixtureDir, "../outside.png"); Check("Parent traversal blocked", false); }
            catch (IOException) { Check("Parent traversal blocked", true); }
            try { LocalFiles.ValidateLocalPath(@"\\server\share\test.md"); Check("UNC path blocked", false); }
            catch (IOException) { Check("UNC path blocked", true); }
            try { LocalFiles.ResolveWithinDirectory(fixtureDir, "pixel.png:secret"); Check("Alternate data stream blocked", false); }
            catch (IOException) { Check("Alternate data stream blocked", true); }
            // ExecuteScriptAsync doesn't await JS promises. Poll an explicit sentinel.
            await Browser.ExecuteScriptAsync("window.networkBlocked=false; fetch('https://example.com').catch(()=>{window.networkBlocked=true})");
            await WaitUntil("window.networkBlocked");
            Check("Network access rejected", await Js("window.networkBlocked"));
            Check("No editor surface", await Js("!document.querySelector('[contenteditable], textarea')"));
            Check("Drop bridge is available", await Js("typeof window.chrome.webview.postMessageWithAdditionalObjects === 'function'"));
            // Use a real browser File backed by a test file, then exercise the
            // same drop handler and native AdditionalObjects path as Explorer.
            await Browser.ExecuteScriptAsync("var testInput=document.createElement('input'); testInput.type='file'; testInput.id='test-file'; testInput.hidden=true; document.body.append(testInput)");
            using (var tree = JsonDocument.Parse(await Browser.CoreWebView2.CallDevToolsProtocolMethodAsync("DOM.getDocument", "{}")))
            {
                var nodeId = tree.RootElement.GetProperty("root").GetProperty("nodeId").GetInt32();
                using var query = JsonDocument.Parse(await Browser.CoreWebView2.CallDevToolsProtocolMethodAsync("DOM.querySelector", JsonSerializer.Serialize(new { nodeId, selector = "#test-file" })));
                var inputId = query.RootElement.GetProperty("nodeId").GetInt32();
                await Browser.CoreWebView2.CallDevToolsProtocolMethodAsync("DOM.setFileInputFiles", JsonSerializer.Serialize(new { nodeId = inputId, files = new[] { fixture } }));
            }
            var beforeDrop = await Browser.ExecuteScriptAsync("document.documentElement.dataset.renderCount");
            await Browser.ExecuteScriptAsync("var transfer=new DataTransfer(); transfer.items.add(document.getElementById('test-file').files[0]); document.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:transfer})); document.getElementById('test-file').remove()");
            await WaitUntil($"document.documentElement.dataset.renderCount !== {beforeDrop}");
            Check("File drop reaches native reader", Title == "한글 document.markdown — 엠디봄" && await Js("document.querySelector('#content h1').textContent === 'Reloaded'"));
            var sample = Path.Combine(AppContext.BaseDirectory, "samples", "Welcome.md");
            if (!File.Exists(sample)) sample = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "samples", "Welcome.md"));
            if (File.Exists(sample)) await OpenAndWait(sample);
            else await OpenAndWait(utf16);
            _theme = "light"; ApplyTheme();
            await WaitUntil("document.documentElement.dataset.theme === 'light'");
            await CaptureWindowAsync(Path.Combine(directory, "reading-light.png"));
            _theme = "dark"; ApplyTheme();
            await WaitUntil("document.documentElement.dataset.theme === 'dark'");
            await CaptureWindowAsync(Path.Combine(directory, "reading-dark.png"));
            ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'source'");
            await CaptureWindowAsync(Path.Combine(directory, "source-dark.png"));
            _theme = "light"; ApplyTheme();
            await WaitUntil("document.documentElement.dataset.theme === 'light'");
            Check("Source uses light theme colors", await Js("getComputedStyle(document.getElementById('sourcecontent')).color === 'rgb(31, 35, 40)'"));
            await CaptureWindowAsync(Path.Combine(directory, "source-light.png"));
            ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'reading'");
            ChangeWorkspace("readingWidth","660");
            await WaitUntil("getComputedStyle(document.getElementById('reader')).maxWidth === '660px'");
            Check("Reading width reaches renderer", await Js("Math.abs(document.getElementById('reader').getBoundingClientRect().width - 660) < 1"));
            ChangeWorkspace("sourceWidth","1280");
            ExecuteCommand("source");
            await WaitUntil("getComputedStyle(document.getElementById('reader')).maxWidth === '1280px'");
            Check("Source width independent", _preferences.ReadingWidth == 660 && _preferences.SourceWidth == 1280);
            ExecuteCommand("source");
            ChangeWorkspace("readingWidth","0");
            await WaitUntil("getComputedStyle(document.getElementById('reader')).maxWidth === 'none'");
            Check("Full width applied", _preferences.ReadingFullWidth);
            ChangeWorkspace("readingWidth","920");
            await WaitUntil("getComputedStyle(document.getElementById('reader')).maxWidth === '920px'");
            Check("Preset exits full width", !_preferences.ReadingFullWidth);
            ChangeWorkspace("readingFont", "serif"); ChangeWorkspace("readingFontSize", "20");
            ChangeWorkspace("sourceFont", "mono"); ChangeWorkspace("sourceFontSize", "17");
            await WaitUntil("getComputedStyle(document.getElementById('content')).fontSize === '20px' && getComputedStyle(document.getElementById('sourcecontent')).fontSize === '17px'");
            var savedFonts = ViewerPreferences.Load(SettingsPath);
            Check("Independent fonts saved", savedFonts.ReadingFont == "serif" && savedFonts.SourceFont == "mono" && savedFonts.ReadingFontSize == 20 && savedFonts.SourceFontSize == 17);
            ChangeWorkspace("readingFontSize", "999"); ChangeWorkspace("sourceFont", "invalid");
            Check("Invalid fonts rejected", _preferences.ReadingFontSize == 20 && _preferences.SourceFont == "mono");
            ChangeWorkspace("readingFont", "system"); ChangeWorkspace("readingFontSize", "16"); ChangeWorkspace("sourceFontSize", "14");
            var savedWidths = ViewerPreferences.Load(SettingsPath);
            Check("Width settings saved", savedWidths.ReadingWidth == 920 && savedWidths.SourceWidth == 1280);
            ChangeWorkspace("view","horizontal"); ChangeWorkspace("toolbar","auto"); ChangeWorkspace("ratio","35");
            var savedWorkspace = ViewerPreferences.Load(SettingsPath);
            Check("Workspace settings saved", savedWorkspace.Layout == "horizontal" && savedWorkspace.Toolbar == "auto" && savedWorkspace.SplitRatio == 35);
            ChangeWorkspace("view","reading"); ChangeWorkspace("toolbar","always"); ChangeWorkspace("ratio","50");
            var oldWidth = Width; Width = MinWidth;
            await Task.Delay(150);
            Check("Floating toolbar fits narrow window", await Js("document.getElementById('floating-tools').getBoundingClientRect().right <= innerWidth"));
            await CaptureWindowAsync(Path.Combine(directory,"width-small-window.png"));
            Width = oldWidth;
            var legacyPath = Path.Combine(directory, "legacy-settings.json");
            await File.WriteAllTextAsync(legacyPath, "{\"theme\":\"dark\"}");
            var legacy = ViewerPreferences.Load(legacyPath);
            Check("Old theme-only settings migrate without losing theme", legacy.Theme == "dark" && legacy.ReadingWidth == 920 && legacy.SourceWidth == 1200);
            await File.WriteAllTextAsync(legacyPath, "{\"theme\":\"light\",\"readingWidth\":-1,\"sourceWidth\":50000}");
            var bounded = ViewerPreferences.Load(legacyPath);
            Check("Out-of-range saved widths are bounded", bounded.ReadingWidth == 600 && bounded.SourceWidth == 1800);
            using var scrollScript = new StreamReader(typeof(MainWindow).Assembly.GetManifestResourceStream("Tests/scroll-sync.js")!);
            await Browser.ExecuteScriptAsync(await scrollScript.ReadToEndAsync());
            var scrollFixture = Path.Combine(fixtureDir, "scroll-position.md");
            await File.WriteAllTextAsync(scrollFixture, JsonSerializer.Deserialize<string>(await Browser.ExecuteScriptAsync("scrollChecks.fixture")));
            await OpenAndWait(scrollFixture);
            ChangeWorkspace("readingWidth","660");
            await Browser.ExecuteScriptAsync("""
                window.scrollChecksResult = null;
                scrollChecks.run(async () => {
                  const before = document.documentElement.dataset.view;
                  document.dispatchEvent(new KeyboardEvent('keydown',{key:'u',ctrlKey:true,bubbles:true,cancelable:true}));
                  for (let i=0; i<100; i++) {
                    if (document.documentElement.dataset.view !== before) return;
                    await new Promise(resolve => setTimeout(resolve,20));
                  }
                  throw new Error('Native view toggle timed out');
                }).then(result => window.scrollChecksResult=result).catch(error => window.scrollChecksResult={error:String(error)});
                """);
            await WaitUntil("window.scrollChecksResult !== null");
            var scrollJson = await Browser.ExecuteScriptAsync("window.scrollChecksResult");
            await File.WriteAllTextAsync(Path.Combine(directory, "scroll-position.json"), scrollJson);
            using var scrollReport = JsonDocument.Parse(scrollJson);
            foreach (var check in scrollReport.RootElement.GetProperty("checks").EnumerateObject()) Check("Scroll: " + check.Name, check.Value.GetBoolean());
            await Browser.ExecuteScriptAsync("scrollBy(0, scrollChecks.top('const codeLine035') + 3)");
            await CaptureWindowAsync(Path.Combine(directory, "scroll-reading.png"));
            ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'source'");
            await CaptureWindowAsync(Path.Combine(directory, "scroll-source.png"));
            if (_sourceView) ExecuteCommand("source");
            await WaitUntil("document.documentElement.dataset.view === 'reading'");
            using var workspaceScript = new StreamReader(typeof(MainWindow).Assembly.GetManifestResourceStream("Tests/workspace.js")!);
            await Browser.ExecuteScriptAsync(await workspaceScript.ReadToEndAsync());
            await Browser.ExecuteScriptAsync("window.workspaceResult=null; runWorkspaceChecks(workspace).then(r=>window.workspaceResult=r).catch(e=>window.workspaceResult={error:String(e)})");
            await WaitUntil("window.workspaceResult !== null");
            using var workspaceReport = JsonDocument.Parse(await Browser.ExecuteScriptAsync("window.workspaceResult"));
            foreach(var check in workspaceReport.RootElement.EnumerateObject()) Check("Workspace: " + check.Name, check.Value.ValueKind == JsonValueKind.True);
            ChangeWorkspace("view","horizontal");
            await Task.Delay(200);
            await CaptureWindowAsync(Path.Combine(directory,"split-horizontal.png"));
            ChangeWorkspace("view","vertical");
            await Task.Delay(200);
            await CaptureWindowAsync(Path.Combine(directory,"split-vertical.png"));
            ChangeWorkspace("view","reading");
            var previousState = WindowState;
            ToggleFullScreen();
            Check("Enter fullscreen", _fullScreen && WindowStyle == WindowStyle.None && WindowState == WindowState.Maximized);
            ExecuteCommand("exitFullscreen");
            Check("Exit fullscreen restores window", !_fullScreen && WindowState == previousState);
            await Browser.ExecuteScriptAsync("""
                window.refreshResult=null; window.refreshRequest=null;
                runRefreshChecks(workspace, (markdown,preserveScroll)=>new Promise(resolve=>{
                  window.refreshDone=resolve;
                  window.refreshRequest={markdown,preserveScroll,layout:workspace.layout};
                })).then(r=>window.refreshResult=r).catch(e=>window.refreshResult={error:String(e)});
                """);
            for(var i=0;i<150 && !await Js("window.refreshResult !== null");i++) {
                using var request = JsonDocument.Parse(await Browser.ExecuteScriptAsync("window.refreshRequest"));
                if (request.RootElement.ValueKind == JsonValueKind.Object) {
                    var data = request.RootElement;
                    var before = await Browser.ExecuteScriptAsync("document.documentElement.dataset.renderCount");
                    Post(new {type="presentation",layout=data.GetProperty("layout").GetString(),sync=false});
                    Post(new {type="render",markdown=data.GetProperty("markdown").GetString(),name="refresh.md",
                        baseUrl=_server!.DocumentBaseUrl,view="reading",preserveScroll=data.GetProperty("preserveScroll").GetBoolean()});
                    await WaitUntil($"document.documentElement.dataset.renderCount !== {before}");
                    await Browser.ExecuteScriptAsync("window.refreshRequest=null; window.refreshDone()");
                }
                await Task.Delay(100);
            }
            await WaitUntil("window.refreshResult !== null");
            using var refreshReport = JsonDocument.Parse(await Browser.ExecuteScriptAsync("window.refreshResult"));
            foreach(var check in refreshReport.RootElement.EnumerateObject()) Check("Refresh viewport: " + check.Name, check.Value.ValueKind == JsonValueKind.True);
            var watched = Path.Combine(fixtureDir, "auto-refresh.md");
            await File.WriteAllTextAsync(watched, "# Original");
            await OpenAndWait(watched);
            await File.WriteAllTextAsync(watched, "# Ordinary save");
            await WaitUntil("document.getElementById('sourcecontent').textContent === '# Ordinary save'");
            Check("Auto refresh ordinary save", true);
            var replacement = watched + ".tmp";
            await File.WriteAllTextAsync(replacement, "# Atomic replacement");
            File.Move(replacement, watched, true);
            await WaitUntil("document.getElementById('sourcecontent').textContent === '# Atomic replacement'");
            Check("Auto refresh atomic replacement", true);
            File.Delete(watched);
            await Task.Delay(1200);
            Check("Auto refresh retains deleted document", _currentText == "# Atomic replacement");
            await File.WriteAllBytesAsync(watched, new byte[]{0xff,0xff,0xff});
            await Task.Delay(1200);
            Check("Auto refresh retains invalid document", _currentText == "# Atomic replacement");
            for (var i=0;i<5;i++) await File.WriteAllTextAsync(watched,$"# Burst {i}");
            await WaitUntil("document.getElementById('sourcecontent').textContent === '# Burst 4'");
            Check("Auto refresh recreated file and burst", true);
            var stableRender = await Browser.ExecuteScriptAsync("document.documentElement.dataset.renderCount");
            await File.WriteAllTextAsync(watched,"# Burst 4");
            await Task.Delay(1200);
            Check("Identical save does not render", stableRender == await Browser.ExecuteScriptAsync("document.documentElement.dataset.renderCount"));
            await OpenAndWait(fixture);
            await File.WriteAllTextAsync(watched,"# Inactive file");
            await Task.Delay(1200);
            Check("Previous file no longer refreshes", _currentPath == fixture && _currentText != "# Inactive file");
            await File.WriteAllTextAsync(Path.Combine(fixtureDir,"rich.svg"), """
                <svg xmlns="http://www.w3.org/2000/svg" width="240" height="80" onload="window.__mdbomRichAttack=true"><rect width="240" height="80" rx="12" fill="#dcefdc"/><text x="24" y="48" fill="#235633" font-size="22">Local SVG</text><script>window.__mdbomRichAttack=true</script></svg>
                """);
            using var richScript = new StreamReader(typeof(MainWindow).Assembly.GetManifestResourceStream("Tests/rich-content.js")!);
            await Browser.ExecuteScriptAsync(await richScript.ReadToEndAsync());
            await Browser.ExecuteScriptAsync("window.richResult=null; window.richRequest=null; runRichChecks(document.getElementById('content'), text => new Promise(resolve=>{window.richDone=resolve;window.richRequest=text;})).then(result=>window.richResult=result).catch(error=>window.richResult={error:String(error)});");
            for(var i=0;i<100 && !await Js("window.richResult !== null");i++) {
                using var request = JsonDocument.Parse(await Browser.ExecuteScriptAsync("window.richRequest"));
                if(request.RootElement.ValueKind == JsonValueKind.String) {
                    var before = await Browser.ExecuteScriptAsync("document.documentElement.dataset.renderCount");
                    Post(new {type="render",markdown=request.RootElement.GetString(),name="rich.md",baseUrl=_server!.DocumentBaseUrl,view="reading"});
                    await WaitUntil($"document.documentElement.dataset.renderCount !== {before}");
                    await Browser.ExecuteScriptAsync("window.richRequest=null; window.richDone()");
                }
                await Task.Delay(100);
            }
            await WaitUntil("window.richResult !== null");
            using var richReport = JsonDocument.Parse(await Browser.ExecuteScriptAsync("window.richResult"));
            foreach(var check in richReport.RootElement.EnumerateObject()) Check("Rich content: " + check.Name, check.Value.ValueKind == JsonValueKind.True);
            Post(new {type="theme",theme="light"});
            ChangeWorkspace("view","reading");
            await Task.Delay(150);
            await CaptureWindowAsync(Path.Combine(directory,"rich-light.png"));
            Post(new {type="theme",theme="dark"});
            ChangeWorkspace("view","horizontal");
            await Task.Delay(150);
            await CaptureWindowAsync(Path.Combine(directory,"rich-dark-split.png"));
            using var printFixture = new StreamReader(typeof(MainWindow).Assembly.GetManifestResourceStream("Tests/print.md")!);
            var printPath = Path.Combine(fixtureDir,"Print.md");
            await File.WriteAllTextAsync(printPath,await printFixture.ReadToEndAsync());
            await OpenAndWait(printPath);
            foreach(var mode in new[]{"reading","source","horizontal","vertical"}) {
                ChangeWorkspace("view",mode);
                await Task.Delay(150);
                Post(new {type="theme",theme="dark"});
                var pdfPath=Path.GetFullPath(Path.Combine(directory,$"print-{mode}.pdf"));
                var printed=await Browser.CoreWebView2.PrintToPdfAsync(pdfPath);
                Check($"Print {mode} PDF",printed && new FileInfo(pdfPath).Length>2000);
            }
            var preview = Path.Combine(directory, "DESIGN.md");
            if (File.Exists(preview))
            {
                await OpenAndWait(preview);
                if (_sourceView) ExecuteCommand("source");
                await WaitUntil("document.documentElement.dataset.view === 'reading'");
                ChangeWorkspace("readingWidth","920");
                await Browser.ExecuteScriptAsync("scrollTo(0,0)");
                await CaptureWindowAsync(Path.Combine(directory, "front-matter-collapsed.png"));
                await Browser.ExecuteScriptAsync("document.querySelector('.front-matter').open=true; scrollTo(0,0)");
                await CaptureWindowAsync(Path.Combine(directory, "front-matter-expanded.png"));
            }
        }
        catch (Exception ex) { failures++; checks.Add(new { name = "Unexpected test failure", passed = false, error = ex.ToString() }); }
        await File.WriteAllTextAsync(Path.Combine(directory, "results.json"), JsonSerializer.Serialize(new
        {
            passed = failures == 0, count = checks.Count, failures,
            runtime = Browser.CoreWebView2.Environment.BrowserVersionString,
            checks
        }, new JsonSerializerOptions { WriteIndented = true }));
        Application.Current.Shutdown(failures == 0 ? 0 : 1);
    }

    private async Task CaptureWindowAsync(string path)
    {
        // Composite the WebView's own preview into WPF's rendered window. This
        // captures only this app, never other windows or the user's desktop.
        await Task.Delay(250);
        UpdateLayout();
        using var stream = new MemoryStream();
        await Browser.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png, stream);
        stream.Position = 0;
        var web = new BitmapImage(); web.BeginInit(); web.CacheOption = BitmapCacheOption.OnLoad; web.StreamSource = stream; web.EndInit();
        var client = (FrameworkElement)Content;
        var width = (int)client.ActualWidth; var height = (int)client.ActualHeight;
        var frame = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32); frame.Render(client);
        var origin = Browser.TransformToAncestor(client).Transform(new Point(0, 0));
        var visual = new DrawingVisual();
        using (var drawing = visual.RenderOpen())
        {
            drawing.DrawImage(frame, new Rect(0, 0, width, height));
            drawing.DrawImage(web, new Rect(origin.X, origin.Y, Browser.ActualWidth, Browser.ActualHeight));
        }
        var image = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32); image.Render(visual);
        var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(image));
        await using var file = File.Create(path); encoder.Save(file);
    }

}

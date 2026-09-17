import AppKit
import WebKit
import SwiftUI
import RendererAssets
import PDFKit

/// Explicit developer mode. Exercises the shipping WKWebView configuration and bundled renderer.
/// Run the packaged executable with --self-test /absolute/path/report.json.
@MainActor
final class IntegrationTest {
    let reportURL: URL
    private var coordinator: WebCoordinator!
    private var window: NSWindow!
    private var finished = false
    private let settingsSuite = "MarkdownViewerUITest." + UUID().uuidString
    private var scrollDiagnostics: [String: Double] = [:]
    init(reportURL: URL) { self.reportURL = reportURL }

    func run() {
        do {
            let fixtureDirectory = reportURL.deletingLastPathComponent().appendingPathComponent("fixtures")
            try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
            let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2ioAAAAASUVORK5CYII=")!
            try png.write(to: fixtureDirectory.appendingPathComponent("local image.png"))
            try Self.svgFixture.write(to: fixtureDirectory.appendingPathComponent("rich.svg"), atomically: true, encoding: .utf8)
            let settings = ViewerSettings(defaults: UserDefaults(suiteName: settingsSuite)!)
            settings.theme = "light"
            let model = ViewerModel(settings: settings)
            model.url = fixtureDirectory.appendingPathComponent("검증.md")
            model.text = Self.fixture
            model.revision = 1
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
                              styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: ViewerContentView(model: model, open: {}, openFiles: { _ in }, onWebReady: { [weak self] coordinator in
                guard let self else { return }
                self.coordinator = coordinator
                coordinator.onRendered = { [weak self] in
                    guard let self else { return }
                    self.coordinator.onRendered = nil
                    Task { await self.inspect() }
                }
            }))
            window.appearance = NSAppearance(named: .aqua)
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.finish(["error": "WKWebView integration test timed out"], success: false)
            }
        } catch { finish(["error": error.localizedDescription], success: false) }
    }

    private func inspect() async {
        do {
            guard let web = coordinator.webView else { return }
            let raw = try await web.callAsyncJavaScript(Self.assertions, arguments: [:], in: nil, contentWorld: .page)
            var checks = raw as? [String: Bool] ?? ["javascriptResults": false]
            let find = try await web.find("안녕하세요", configuration: WKFindConfiguration())
            checks["nativeFind"] = find.matchFound
            web.pageZoom = 1.2
            checks["nativeZoom"] = abs(web.pageZoom - 1.2) < 0.001
            web.pageZoom = 1
            // Exercise the native preference-to-WebKit path and measure layout, not just CSS declarations.
            window.setContentSize(NSSize(width: 1400, height: 760))
            for (width, expected) in [(ReadingWidth.narrow, 680.0), (.standard, 920.0), (.wide, 1200.0), (.full, 1400.0)] {
                try await applyWidth(width)
                let actual = try await web.evaluateJavaScript("document.getElementById('reader').getBoundingClientRect().width") as? Double
                // Full width uses the available content area, excluding a persistent scrollbar.
                let available = try await web.evaluateJavaScript("document.documentElement.clientWidth") as? Double ?? 0
                let expectedWidth = width == .full ? available : expected
                checks["readingWidth_" + width.rawValue] = abs((actual ?? 0) - expectedWidth) < 2
            }
            window.setContentSize(NSSize(width: 760, height: 760))
            try await applyWidth(.wide)
            let fits = try await web.evaluateJavaScript("document.getElementById('reader').getBoundingClientRect().width <= innerWidth")
            checks["readingWidthFitsSmallWindow"] = fits as? Bool == true
            checks["readingWidthPreservesContent"] = coordinator.model.text == Self.fixture && web.pageZoom == 1
            window.setContentSize(NSSize(width: 900, height: 760))
            try await applyWidth(.standard)
            let model = coordinator.model
            model.setWidth(660); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('reader')).maxWidth === '660px'")
            model.toggleSource(); coordinator.update()
            try await waitFor("document.documentElement.dataset.view === 'source'")
            checks["sourceExactText"] = try await web.evaluateJavaScript("document.getElementById('sourcecontent').textContent") as? String == Self.fixture
            checks["sourceInert"] = try await web.evaluateJavaScript("document.getElementById('sourcecontent').children.length === 0 && !document.getElementById('sourcecontent').isContentEditable && !window.compromised") as? Bool == true
            model.showFind = true
            model.search = "[Features](#features)"; model.find(); coordinator.update()
            for _ in 0..<100 {
                if model.findStatus == "1 / 1" { break }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            checks["sourceFindsMarkdownSyntax"] = model.findStatus == "1 / 1"
            model.setWidth(1280); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('reader')).maxWidth === '1280px'")
            checks["sourceIndependentWidth"] = model.settings.readingWidth == 660 && model.settings.sourceWidth == 1280
            let reloaded = ViewerSettings(defaults: UserDefaults(suiteName: settingsSuite)!)
            checks["widthSettingsPersist"] = reloaded.readingWidth == 660 && reloaded.sourceWidth == 1280 && reloaded.theme == "light"
            try await snapshot("source-light.png")
            model.setFullWidth(true); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('reader')).maxWidth === 'none'")
            checks["sourceFullWidth"] = !model.settings.readingFullWidth && model.settings.sourceFullWidth
            model.resetWidth(); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('reader')).maxWidth === '1200px'")
            checks["resetOnlyActiveView"] = model.settings.readingWidth == 660 && !model.fullWidth
            model.toggleSource(); coordinator.update()
            try await waitFor("document.documentElement.dataset.view === 'reading' && getComputedStyle(document.getElementById('reader')).maxWidth === '660px'")
            checks["sourceReturnsToReadingWidth"] = model.width == 660
            model.setFullWidth(true); model.preset(920); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('reader')).maxWidth === '920px'")
            checks["presetLeavesFullWidth"] = !model.fullWidth && model.width == 920
            for (legacy, expected) in [("narrow", 680), ("standard", 864), ("wide", 1200), ("full", 920)] {
                let suite = settingsSuite + "." + legacy
                let defaults = UserDefaults(suiteName: suite)!
                defaults.set(legacy, forKey: "readingWidth")
                let migrated = ViewerSettings(defaults: defaults)
                checks["legacyWidth_" + legacy] = migrated.readingWidth == expected && migrated.readingFullWidth == (legacy == "full")
                defaults.removePersistentDomain(forName: suite)
            }
            model.workspace("readingFont", "serif"); model.workspace("readingFontSize", "20")
            model.workspace("sourceFont", "mono"); model.workspace("sourceFontSize", "17"); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('content')).fontSize === '20px' && getComputedStyle(document.getElementById('sourcecontent')).fontSize === '17px'")
            let savedFonts = ViewerSettings(defaults: UserDefaults(suiteName: settingsSuite)!)
            checks["independentFontsPersist"] = savedFonts.readingFont == "serif" && savedFonts.sourceFont == "mono" && savedFonts.readingFontSize == 20 && savedFonts.sourceFontSize == 17
            model.workspace("readingFontSize", "999"); model.workspace("sourceFont", "invalid")
            checks["invalidFontsRejected"] = model.settings.readingFontSize == 20 && model.settings.sourceFont == "mono"
            model.workspace("readingFont", "system"); model.workspace("readingFontSize", "16"); model.workspace("sourceFontSize", "14"); coordinator.update()
            try await waitFor("getComputedStyle(document.getElementById('content')).fontSize === '16px'")
            window.setContentSize(NSSize(width: 1120, height: 820))
            try await snapshot("render-light.png")
            try await snapshotWindow("main-light.png")
            _ = try await web.evaluateJavaScript("[...document.querySelectorAll('#floating-tools button')].find(b=>b.getAttribute('aria-controls')==='workspace-width').click(); true;")
            checks["sharedWidthPopup"] = try await web.evaluateJavaScript("!document.getElementById('workspace-width').hidden") as? Bool == true
            try await snapshot("width-light.png")
            _ = try await web.evaluateJavaScript("document.querySelector('[aria-controls=workspace-font]').click(); true")
            try await snapshot("font-light.png")
            _ = try await web.evaluateJavaScript("document.querySelector('[aria-controls=workspace-help]').click(); true")
            try await snapshot("help-light.png")
            _ = try await web.evaluateJavaScript("document.getElementById('workspace-help').close(); true")
            _ = try await web.evaluateJavaScript("document.getElementById('workspace-width').hidden=true; true;")
            try await Task.sleep(nanoseconds: 300_000_000)
            let lightScroll = try await web.evaluateJavaScript("window.scrollY") as? Double ?? 0
            scrollDiagnostics["beforeTheme"] = lightScroll
            coordinator.model.settings.theme = "dark"
            coordinator.update()
            window.appearance = NSAppearance(named: .darkAqua)
            web.appearance = NSAppearance(named: .darkAqua)
            try await Task.sleep(nanoseconds: 300_000_000)
            let dark = try await web.evaluateJavaScript("matchMedia('(prefers-color-scheme: dark)').matches")
            checks["darkAppearance"] = dark as? Bool == true
            try await waitFor("document.documentElement.dataset.theme === 'dark'")
            let darkScroll = try await web.evaluateJavaScript("window.scrollY") as? Double ?? 0
            scrollDiagnostics["afterTheme"] = darkScroll
            checks["themePreservesScroll"] = abs(lightScroll - darkScroll) < 2
            checks["themeSelectionPersists"] = ViewerSettings(defaults: UserDefaults(suiteName: settingsSuite)!).theme == "dark"
            try await snapshot("render-dark.png")
            try await snapshotWindow("main-dark.png")
            _ = try await web.evaluateJavaScript("[...document.querySelectorAll('#floating-tools button')].find(b=>b.getAttribute('aria-controls')==='workspace-width').click(); true;")
            checks["sharedWidthPopupDark"] = try await web.evaluateJavaScript("!document.getElementById('workspace-width').hidden") as? Bool == true
            try await snapshot("width-dark.png")
            _ = try await web.evaluateJavaScript("document.querySelector('[aria-controls=workspace-font]').click(); true")
            try await snapshot("font-dark.png")
            _ = try await web.evaluateJavaScript("document.querySelector('[aria-controls=workspace-font]').click(); true")
            _ = try await web.evaluateJavaScript("document.getElementById('workspace-width').hidden=true; true;")
            model.sourceView = true; coordinator.update()
            try await waitFor("document.documentElement.dataset.view === 'source'")
            try await snapshot("source-dark.png")
            model.sourceView = false; coordinator.update()
            try await waitFor("document.documentElement.dataset.view === 'reading'")
            _ = try await web.evaluateJavaScript(String(contentsOf: RendererAssets.scrollChecks, encoding: .utf8) + "\ntrue;")
            let scrollReport = try await web.callAsyncJavaScript("""
                viewer.configure({theme:'dark', reading:660, source:1280, view:'reading'});
                await viewer.render(scrollChecks.fixture, 'scroll-position.md');
                return await scrollChecks.run(async () => {
                  viewer.configure({theme:'dark', reading:660, source:1280,
                    view:document.documentElement.dataset.view === 'source' ? 'reading' : 'source'});
                });
                """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any] ?? [:]
            for (key, value) in scrollReport["checks"] as? [String: Bool] ?? ["report": false] { checks["scroll_" + key] = value }
            for (key, value) in scrollReport["details"] as? [String: Double] ?? [:] { scrollDiagnostics[key] = value }
            _ = try await web.evaluateJavaScript(String(contentsOf: RendererAssets.scrollChecks.deletingLastPathComponent().appendingPathComponent("workspace.js"), encoding: .utf8) + "\ntrue;")
            let workspaceChecks = try await web.callAsyncJavaScript("return await runWorkspaceChecks(viewer.workspace)", arguments: [:], in: nil, contentWorld: .page) as? [String: Bool] ?? ["report": false]
            for (key,value) in workspaceChecks { checks["workspace_" + key] = value }
            _ = try await web.evaluateJavaScript("viewer.configure({layout:'horizontal',toolbar:'always'}); true;")
            try await Task.sleep(nanoseconds: 150_000_000)
            try await snapshot("split-horizontal.png")
            _ = try await web.evaluateJavaScript("viewer.configure({layout:'vertical',ratio:40}); true;")
            try await Task.sleep(nanoseconds: 150_000_000)
            try await snapshot("split-vertical.png")
            _ = try await web.evaluateJavaScript("viewer.configure({layout:'single',ratio:50}); true;")
            _ = try await web.evaluateJavaScript("scrollBy(0, scrollChecks.top('const codeLine035') + 3); true;")
            try await snapshot("scroll-reading.png")
            _ = try await web.evaluateJavaScript("viewer.configure({theme:'dark',reading:660,source:1280,view:'source'}); true;")
            try await snapshot("scroll-source.png")
            _ = try await web.evaluateJavaScript("viewer.configure({theme:'dark',reading:660,source:1280,view:'reading'}); true;")
            _ = try await web.callAsyncJavaScript("return viewer.render('', 'empty.md')", arguments: [:], in: nil, contentWorld: .page)
            let empty = try await web.evaluateJavaScript("document.querySelector('.empty-document') !== null && document.getElementById('welcome').hidden")
            checks["emptyDocument"] = empty as? Bool == true
            _ = try await web.callAsyncJavaScript("return viewer.render('', '')", arguments: [:], in: nil, contentWorld: .page)
            let welcome = try await web.evaluateJavaScript("!document.getElementById('welcome').hidden && document.getElementById('reader').hidden")
            checks["welcomeScreen"] = welcome as? Bool == true
            try await snapshot("welcome-dark.png")
            let refreshChecks = try await web.callAsyncJavaScript("""
                return await runRefreshChecks(viewer.workspace, async (text, preserve) => {
                  viewer.configure({layout:viewer.workspace.layout, sync:false});
                  await viewer.render(text, 'refresh.md', preserve);
                });
                """, arguments: [:], in: nil, contentWorld: .page) as? [String: Bool] ?? ["report": false]
            for (key,value) in refreshChecks { checks["refresh_" + key] = value }
            let watched = reportURL.deletingLastPathComponent().appendingPathComponent("fixtures/auto-refresh.md")
            let live = coordinator.model
            defer { live.stopRefresh() }
            live.url = watched
            live.text = "# Original"; live.revision += 1
            try live.text.write(to: watched, atomically: true, encoding: .utf8)
            coordinator.update()
            func waitForText(_ expected: String) async throws -> Bool {
                for _ in 0..<40 {
                    if live.text == expected {
                        let matches = try await web.callAsyncJavaScript("return document.getElementById('sourcecontent').textContent === expected", arguments: ["expected": expected], in: nil, contentWorld: .page) as? Bool
                        if matches == true { return true }
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                return false
            }
            try "# Ordinary save".write(to: watched, atomically: false, encoding: .utf8)
            checks["auto_ordinarySave"] = try await waitForText("# Ordinary save")
            try "# Atomic replacement".write(to: watched, atomically: true, encoding: .utf8)
            checks["auto_atomicReplacement"] = try await waitForText("# Atomic replacement")
            let revision = live.revision
            try FileManager.default.removeItem(at: watched)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            checks["auto_missingFileRetainsDocument"] = live.text == "# Atomic replacement" && live.revision == revision
            try Data([0xff, 0xff, 0xff]).write(to: watched)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            checks["auto_invalidSaveRetainsDocument"] = live.text == "# Atomic replacement"
            for i in 0..<5 { try "# Burst \(i)".write(to: watched, atomically: true, encoding: .utf8) }
            checks["auto_recreatedFileAndBurst"] = try await waitForText("# Burst 4")
            let unchanged = live.revision
            try "# Burst 4".write(to: watched, atomically: true, encoding: .utf8)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            checks["auto_identicalContentDoesNotRender"] = live.revision == unchanged
            live.stopRefresh()
            try "# After close".write(to: watched, atomically: true, encoding: .utf8)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            checks["auto_stopsOnClose"] = live.revision == unchanged
            _ = try await web.evaluateJavaScript(String(contentsOf: RendererAssets.scrollChecks.deletingLastPathComponent().appendingPathComponent("rich-content.js"), encoding: .utf8) + "\ntrue;")
            let richChecks = try await web.callAsyncJavaScript("""
                viewer.configure({view:'reading',layout:'single',theme:'light'});
                return await runRichChecks(document.getElementById('content'), text => viewer.render(text,'rich.md'));
                """, arguments: [:], in: nil, contentWorld: .page) as? [String: Bool] ?? ["report": false]
            for (key,value) in richChecks { checks["rich_" + key] = value }
            try await snapshot("rich-light.png")
            _ = try await web.evaluateJavaScript("viewer.configure({theme:'dark',layout:'horizontal'}); true")
            try await snapshot("rich-dark-split.png")
            let printable = try String(contentsOf: RendererAssets.scrollChecks.deletingLastPathComponent().appendingPathComponent("print.md"), encoding: .utf8)
            for mode in ["reading", "source", "horizontal", "vertical"] {
                _ = try await web.callAsyncJavaScript("""
                    viewer.configure({view:mode==='source'?'source':'reading',layout:['reading','source'].includes(mode)?'single':mode,theme:'dark'});
                    await viewer.render(text, 'Print.md'); return true;
                    """, arguments: ["mode":mode,"text":printable], in: nil, contentWorld: .page)
                let output = reportURL.deletingLastPathComponent().appendingPathComponent("print-" + mode + ".pdf")
                let info = NSPrintInfo.shared.copy() as! NSPrintInfo
                info.jobDisposition = .save
                info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = output
                info.paperSize = NSSize(width: 595, height: 842)
                info.topMargin = 36; info.bottomMargin = 36; info.leftMargin = 36; info.rightMargin = 36
                let operation = coordinator.makePrintOperation(info)
                operation.showsPrintPanel = false; operation.showsProgressPanel = false
                let printed = await coordinator.runPrintOperation(operation)
                let pdf = PDFDocument(url: output)
                let text = pdf?.string ?? ""
                checks["print_" + mode + "_pdf"] = printed && (2...10).contains(pdf?.pageCount ?? 0)
                checks["print_" + mode + "_fullDocument"] = text.contains("Print verification") && text.contains("Final print marker")
                checks["print_" + mode + "_renderedOnly"] = !text.contains("```") && !text.contains("**강조**") && !text.contains("End of document") && !text.contains("본문 폭")
            }
            finish(["checks": checks, "passed": checks.values.filter { $0 }.count,
                    "total": checks.count, "engine": "WKWebView", "architecture": "arm64"],
                   success: checks.values.allSatisfy { $0 })
        } catch { finish(["error": error.localizedDescription], success: false) }
    }

    private static let svgFixture = ##"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80" onload="window.__mdbomRichAttack=true"><rect width="240" height="80" rx="12" fill="#dcefdc"/><text x="24" y="48" fill="#235633" font-size="22">Local SVG</text><script>window.__mdbomRichAttack=true</script></svg>"##

    private func applyWidth(_ width: ReadingWidth) async throws {
        coordinator.model.readingWidth = width
        coordinator.update()
        for _ in 0..<100 {
            let applied = try await coordinator.webView.evaluateJavaScript("getComputedStyle(document.getElementById('reader')).maxWidth") as? String
            if applied == (width == .full ? "none" : "\(width.pixels)px") { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw NSError(domain: "ReadingWidthTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Width update timed out"])
    }

    private func snapshot(_ name: String) async throws {
        let image = try await coordinator.webView.takeSnapshot(configuration: nil)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try png.write(to: reportURL.deletingLastPathComponent().appendingPathComponent(name))
    }

    private func waitFor(_ expression: String) async throws {
        for _ in 0..<150 {
            if try await coordinator.webView.evaluateJavaScript(expression) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw NSError(domain: "UITest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out: " + expression])
    }

    private func snapshotWindow(_ name: String) async throws {
        guard let root = window.contentView, let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else { return }
        root.cacheDisplay(in: root.bounds, to: bitmap)
        let web = coordinator.webView!
        let rendered = try await web.takeSnapshot(configuration: nil)
        let image = NSImage(size: root.bounds.size)
        image.lockFocus()
        bitmap.draw(in: NSRect(origin: .zero, size: root.bounds.size))
        var frame = web.convert(web.bounds, to: root)
        if root.isFlipped { frame.origin.y = root.bounds.height - frame.maxY }
        rendered.draw(in: frame)
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) {
            try data.write(to: reportURL.deletingLastPathComponent().appendingPathComponent(name))
        }
    }

    private func finish(_ report: [String: Any], success: Bool) {
        guard !finished else { return }
        finished = true
        var report = report
        UserDefaults.standard.removePersistentDomain(forName: settingsSuite)
        report["success"] = success
        report["scrollDiagnostics"] = scrollDiagnostics
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: reportURL)
            print(String(decoding: data, as: UTF8.self))
        } catch { print(error.localizedDescription) }
        exit(success ? 0 : 1)
    }

    static let fixture = #"""
    # Markdown Viewer

    안녕하세요 👋 — Native, offline reading with **bold** and *emphasis*.

    ## Features

    | Feature | Status |
    | :--- | ---: |
    | Tables | Ready |
    | Read only | Yes |

    - [x] Bundled renderer
    - [ ] Never modify this checkbox
      - [X] Nested task

    > A quiet place to read your documents.

    ```swift
    struct Reader {
        let name = "Markdown Viewer"
        func read() -> Bool { true }
    }
    ```

    ```unknown-language
    <script>window.compromised = true</script>
    ```

    ~~Deleted text~~ and `inline code`.

    [Features](#features) · [Website](https://example.com) · [Local](next.md)

    ![Local asset](local%20image.png)
    ![Remote](https://example.com/tracker.png)
    ![Absolute](/etc/private.png)
    ![Unsupported image](untrusted.pdf)

    <details><summary>Details</summary><p>Safe HTML stays readable.</p></details>
    <script>window.compromised = true</script>
    <iframe src="https://example.com"></iframe>
    <img src="https://example.com/bad.png" onerror="window.compromised = true">
    <a href="javascript:alert(1)">Unsafe link</a>
    <a href="file:///etc/passwd">File URL</a>
    <input type="text" value="editable"><input type="checkbox" checked>
    <div id="reader" class="welcome" style="display:none" contenteditable="true">Still visible</div>
    <style>body { display:none }</style>

    ## Features
    """#

    static let assertions = #"""
    const root = document.getElementById('reader');
    await Promise.all([...root.querySelectorAll('img')].map(img => img.complete ? Promise.resolve() : new Promise(resolve => {
      img.addEventListener('load', resolve, {once:true});
      img.addEventListener('error', resolve, {once:true});
      setTimeout(resolve, 3000);
    })));
    const images = [...root.querySelectorAll('img')];
    let networkBlocked = false;
    try { await fetch('https://example.com/markdown-viewer-offline-test'); } catch { networkBlocked = true; }
    return {
      bundledRenderer: typeof viewer.render === 'function',
      sharedRenderer: window.MarkdownViewerCore?.apiVersion === 1,
      unicode: root.textContent.includes('안녕하세요 👋'),
      headings: root.querySelectorAll('h1').length === 1,
      uniqueHeadingIDs: !!root.querySelector('#heading-features') && !!root.querySelector('#heading-features-1'),
      tables: root.querySelectorAll('tbody tr').length === 2,
      tableAlignment: root.querySelector('td[align="right"]')?.textContent === 'Ready',
      taskLists: root.querySelectorAll('.task-list-item').length === 3,
      readOnlyCheckboxes: [...root.querySelectorAll('input')].every(i => i.type === 'checkbox' && i.disabled),
      highlightedSwift: root.querySelectorAll('code.language-swift .hljs-keyword').length > 0,
      unknownLanguageEscaped: root.querySelector('code.language-unknown-language')?.textContent.includes('<script>'),
      strikethrough: root.querySelector('s')?.textContent === 'Deleted text',
      safeHTML: root.querySelector('details summary')?.textContent === 'Details',
      scriptsRemoved: root.querySelectorAll('script,iframe,style,object,embed,form,svg').length === 0,
      eventHandlersRemoved: [...root.querySelectorAll('*')].every(e => [...e.attributes].every(a => !a.name.startsWith('on'))),
      noExecution: !window.compromised,
      noEditing: root.querySelectorAll('[contenteditable],input:not([type="checkbox"]),textarea').length === 0,
      noCSSInjection: root.querySelectorAll('[style],.welcome').length === 0,
      noClobbering: document.querySelectorAll('#reader').length === 1,
      dangerousLinksRemoved: root.querySelectorAll('a[href^="javascript:"],a[href^="file:"]').length === 0,
      localImageLoaded: images.some(i => i.src.startsWith('mdviewer://document/') && i.complete && i.naturalWidth === 1),
      remoteImagesRemoved: images.every(i => !/^https?:/.test(i.src)),
      blockedImagePlaceholders: root.querySelectorAll('.image-placeholder').length === 4,
      localLinks: !!root.querySelector('a[href="mdviewer://document/next.md"]'),
      externalLinks: !!root.querySelector('a[href="https://example.com/"]'),
      offlineNetworkPolicy: networkBlocked,
      lightAppearance: !matchMedia('(prefers-color-scheme: dark)').matches
    };
    """#
}

import AppKit
import SwiftUI
import WebKit
import ViewerCore
import RendererAssets

enum WebAssets {
    // Packaged apps must use their own resources, never the original build machine.
    private static var resourceBundle: Bundle {
        if let url = Bundle.main.url(forResource: "MarkdownViewer_MarkdownViewer", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module // Swift Package / Xcode development runs
    }
    static var directory: URL { resourceBundle.url(forResource: "Web", withExtension: nil)! }
    static let startURL = URL(string: "mdviewer://app/index.html")!
}

final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    var documentDirectory: URL?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        do {
            guard let url = urlSchemeTask.request.url, url.scheme == "mdviewer" else {
                throw URLError(.unsupportedURL)
            }
            let path = String(url.path.dropFirst())
            let resource: URL
            let mime: String
            if url.host == "app" {
                // Only these immutable assets can be served as executable resources.
                let types = ["index.html": "text/html", "viewer.js": "application/javascript", "viewer.css": "text/css",
                             "core.js": "application/javascript", "markdown.css": "text/css", "presentation.css": "text/css"]
                guard let type = types[path] else { throw URLError(.noPermissionsToReadFile) }
                let directory = ["core.js", "markdown.css", "presentation.css"].contains(path) ? RendererAssets.directory : WebAssets.directory
                resource = directory.appendingPathComponent(path)
                mime = type
            } else if url.host == "document", let root = documentDirectory {
                resource = try DocumentLoader.containedURL(path: path, in: root)
                let types = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                             "gif": "image/gif", "webp": "image/webp", "avif": "image/avif", "svg": "image/svg+xml"]
                guard let type = types[resource.pathExtension.lowercased()] else {
                    throw URLError(.noPermissionsToReadFile)
                }
                let info = try resource.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard info.isRegularFile == true, (info.fileSize ?? 0) <= 20 * 1024 * 1024 else {
                    throw URLError(.dataLengthExceedsMaximum)
                }
                mime = type
            } else { throw URLError(.noPermissionsToReadFile) }
            let handle = try FileHandle(forReadingFrom: resource)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 20 * 1024 * 1024 + 1) ?? Data()
            guard data.count <= 20 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
            let response = URLResponse(url: url, mimeType: mime,
                                       expectedContentLength: data.count, textEncodingName: "utf-8")
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch { urlSchemeTask.didFailWithError(error) }
    }
    // All work above completes synchronously on the callback thread; nothing remains to cancel.
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

final class ReadOnlyWebView: WKWebView {
    var openFiles: (([URL]) -> Void)?

    private func draggedFiles(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
          options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter(DocumentLoader.isMarkdown)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggedFiles(sender).isEmpty ? [] : .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { !draggedFiles(sender).isEmpty }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = draggedFiles(sender)
        guard !urls.isEmpty else { return false }
        openFiles?(urls)
        return true
    }
}

struct MarkdownWebContent: NSViewRepresentable {
    @ObservedObject var model: ViewerModel
    let openFiles: ([URL]) -> Void
    let openPanel: () -> Void
    var onReady: ((WebCoordinator) -> Void)? = nil

    func makeCoordinator() -> WebCoordinator { WebCoordinator(model: model, openFiles: openFiles, openPanel: openPanel) }

    func makeNSView(context: Context) -> ReadOnlyWebView {
        let view = context.coordinator.makeWebView()
        onReady?(context.coordinator)
        return view
    }

    func updateNSView(_ webView: ReadOnlyWebView, context: Context) { context.coordinator.update() }

    static func dismantleNSView(_ nsView: ReadOnlyWebView, coordinator: WebCoordinator) {
        nsView.stopLoading()
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "viewer")
        nsView.navigationDelegate = nil
    }
}

@MainActor
final class WebCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let model: ViewerModel
    let handler = LocalSchemeHandler()
    let openFiles: ([URL]) -> Void
    let openPanel: () -> Void
    var webView: ReadOnlyWebView!
    var ready = false
    private var lastRevision = -1
    private var lastFind = 0
    private var renderInFlight = false
    private var printing = false
    private var printCompletion: CheckedContinuation<Bool, Never>?
    private var appliedPresentation: String?
    private var appliedTheme: String?
    var onRendered: (() -> Void)?

    init(model: ViewerModel, openFiles: @escaping ([URL]) -> Void, openPanel: @escaping () -> Void) {
        self.model = model; self.openFiles = openFiles; self.openPanel = openPanel
    }

    func makeWebView() -> ReadOnlyWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(handler, forURLScheme: "mdviewer")
        configuration.userContentController.add(self, name: "viewer")
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = ReadOnlyWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.openFiles = openFiles
        view.registerForDraggedTypes([.fileURL])
        view.allowsBackForwardNavigationGestures = false
        view.setValue(false, forKey: "drawsBackground")
        webView = view
        model.printDocument = { [weak self] in self?.printDocument() }
        // CSP is the primary resource policy; this also blocks every HTTP(S) resource at WebKit level.
        let rules = "[{\"trigger\":{\"url-filter\":\"^https?://\"},\"action\":{\"type\":\"block\"}}]"
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "MarkdownViewerOffline-v1",
            encodedContentRuleList: rules) { [weak self, weak view] list, error in
                guard let self, let view else { return }
                if let list { configuration.userContentController.add(list) }
                if let error {
                    self.model.issue = "Couldn’t initialize the offline renderer: \(error.localizedDescription)"
                    return
                }
                view.load(URLRequest(url: WebAssets.startURL))
            }
        return view
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        appliedPresentation = nil
        update()
    }

    func update() {
        guard ready, !printing, let webView else { return }
        if abs(webView.pageZoom - model.zoom) > 0.001 { webView.pageZoom = model.zoom }
        let settings = model.settings
        let theme = settings.theme
        let reading = settings.readingFullWidth ? 0 : settings.readingWidth
        let source = settings.sourceFullWidth ? 0 : settings.sourceWidth
        let view = model.sourceView ? "source" : "reading"
        let presentation = "\(reading):\(source):\(view):\(settings.theme):\(model.layout):\(model.toolbarMode):\(model.syncScroll):\(model.splitRatio):\(settings.readingFont):\(settings.sourceFont):\(settings.readingFontSize):\(settings.sourceFontSize)"
        if (lastRevision != model.revision || appliedPresentation != presentation), !renderInFlight {
            let revision = model.revision
            let shouldRender = lastRevision != revision
            let preserveScroll = lastRevision >= 0 && model.url != nil
            renderInFlight = true
            handler.documentDirectory = model.url?.deletingLastPathComponent()
            let options: [String: Any] = ["reading": reading, "source": source, "view": view, "theme": settings.theme, "layout": model.layout, "toolbar": model.toolbarMode, "sync": model.syncScroll, "ratio": model.splitRatio, "readingFont": settings.readingFont, "sourceFont": settings.sourceFont, "readingFontSize": settings.readingFontSize, "sourceFontSize": settings.sourceFontSize]
            let arguments: [String: Any] = ["markdown": model.text, "filename": model.url?.lastPathComponent ?? "",
                "preserveScroll": preserveScroll, "shouldRender": shouldRender, "options": options]
            Task { [weak self] in
                guard let self else { return }
                do {
                    let themeChanged = self.appliedTheme != theme
                    var scriptArguments = arguments
                    scriptArguments["restoreScroll"] = false
                    scriptArguments["scrollX"] = 0
                    scriptArguments["scrollY"] = 0
                    if themeChanged {
                        let position = try await webView.evaluateJavaScript("({x:scrollX,y:scrollY,view:document.documentElement.dataset.view})") as? [String: Any]
                        scriptArguments["restoreScroll"] = !shouldRender && position?["view"] as? String == view
                        scriptArguments["scrollX"] = position?["x"] ?? 0
                        scriptArguments["scrollY"] = position?["y"] ?? 0
                        let appearance: NSAppearance? = theme == "system" ? nil : NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
                        webView.appearance = appearance
                        webView.window?.appearance = appearance
                    }
                    _ = try await webView.callAsyncJavaScript(
                        "viewer.configure(options); if (shouldRender) await viewer.render(markdown, filename, preserveScroll); if (restoreScroll) { await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))); window.scrollTo(scrollX, scrollY); }",
                        arguments: scriptArguments, in: nil, contentWorld: .page)
                    self.lastRevision = revision
                    self.appliedPresentation = presentation
                    self.appliedTheme = theme
                    self.model.rendered = true
                    self.renderInFlight = false
                    if shouldRender { self.onRendered?() }
                    self.update()
                } catch {
                    self.renderInFlight = false
                    self.model.issue = "Couldn’t update this document: \(error.localizedDescription)"
                }
            }
        }
        if lastFind != model.findRequest {
            lastFind = model.findRequest
            guard !model.search.isEmpty else { model.findStatus = ""; return }
            let search = model.search
            let backwards = model.findBackwards
            Task { [weak self] in
                do {
                    let result = try await webView.callAsyncJavaScript("return viewer.findText(search, backwards)",
                        arguments: ["search": search, "backwards": backwards], in: nil, contentWorld: .page) as? [String: Any]
                    let total = result?["total"] as? Int ?? 0
                    let current = result?["current"] as? Int ?? 0
                    self?.model.findStatus = total > 0 ? "\(current) / \(total)" : "No matches"
                } catch { self?.model.findStatus = "Search unavailable" }
            }
        }
    }

    func makePrintOperation(_ info: NSPrintInfo) -> NSPrintOperation {
        info.horizontalPagination = .fit
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        let operation = webView.printOperation(with: info)
        operation.jobTitle = model.url?.lastPathComponent ?? "엠디봄"
        return operation
    }
    func runPrintOperation(_ operation: NSPrintOperation) async -> Bool {
        guard let window = webView.window, printCompletion == nil else { return false }
        return await withCheckedContinuation { continuation in
            printCompletion = continuation
            operation.runModal(for: window, delegate: self, didRun: #selector(printFinished(_:success:contextInfo:)), contextInfo: nil)
        }
    }
    @objc private func printFinished(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        let completion = printCompletion; printCompletion = nil
        completion?.resume(returning: success)
    }
    func printDocument() {
        guard ready, model.url != nil, !printing, !renderInFlight else { return }
        printing = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.printing = false; self.update() }
            do {
                _ = try await webView.evaluateJavaScript("window.printViewport = viewer.workspace.captureViewport(); true")
                let info = NSPrintInfo.shared.copy() as! NSPrintInfo
                info.topMargin = 36; info.bottomMargin = 36; info.leftMargin = 36; info.rightMargin = 36
                let operation = makePrintOperation(info)
                operation.showsPrintPanel = true
                operation.showsProgressPanel = true
                _ = await runPrintOperation(operation)
                _ = try await webView.evaluateJavaScript("viewer.workspace.restoreViewport(window.printViewport); delete window.printViewport; true")
            } catch { model.issue = "Couldn’t prepare printing: \(error.localizedDescription)" }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // The document never navigates; user links are handled by the controlled click bridge.
        let isShell = navigationAction.request.url == WebAssets.startURL && navigationAction.navigationType == .other
        decisionHandler(isShell ? .allow : .cancel)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.host == "app",
              let body = message.body as? [String: String], let action = body["action"] else { return }
        if action == "workspace", let key = body["key"], let value = body["value"] { model.workspace(key, value); return }
        if action == "command", let command = body["command"] {
            switch command {
            case "open": openPanel()
            case "reload": model.reload()
            case "print": printDocument()
            case "find": model.showFind.toggle()
            case "theme": model.cycleTheme()
            case "fullscreen": webView.window?.toggleFullScreen(nil)
            case "exitFullscreen": if webView.window?.styleMask.contains(.fullScreen) == true { webView.window?.toggleFullScreen(nil) }
            default: break
            }
            return
        }
        if action == "open" { openPanel(); return }
        guard action == "link", let href = body["href"], let url = URL(string: href) else { return }
        if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        } else if url.scheme == "mdviewer", url.host == "document", let root = handler.documentDirectory {
            do {
                let local = try DocumentLoader.containedURL(path: String(url.path.dropFirst()), in: root)
                guard DocumentLoader.isMarkdown(local) else { return }
                openFiles([local])
            } catch { model.issue = error.localizedDescription }
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false; lastRevision = -1; renderInFlight = false
        model.issue = "The renderer stopped. Reloading the document…"
        webView.load(URLRequest(url: WebAssets.startURL))
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        model.issue = error.localizedDescription
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        model.issue = error.localizedDescription
    }
}

import AppKit
import SwiftUI
import Combine
import ViewerCore

// Kept for native commands/tests; pixel values come from the shared UI contract.
enum ReadingWidth: String, CaseIterable {
    case narrow, standard, wide, full
    var pixels: Int {
        switch self {
        case .narrow: return InterfaceSpec.shared.presets[0].value
        case .standard: return InterfaceSpec.shared.width.readingDefault
        case .wide: return InterfaceSpec.shared.presets[2].value
        case .full: return 0
        }
    }
}

@MainActor
final class ViewerModel: ObservableObject {
    let settings: ViewerSettings
    private var settingsObserver: AnyCancellable?
    private var refresh: DocumentRefresh?
    private var refreshGeneration = UUID()
    @Published var url: URL? { didSet { startRefresh() } }
    func stopRefresh() { refresh = nil; refreshGeneration = UUID() }
    private func startRefresh() {
        stopRefresh()
        guard let url else { return }
        let generation = refreshGeneration
        refresh = DocumentRefresh(url: url) { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self, self.refreshGeneration == generation, self.text != text else { return }
                self.text = text; self.revision += 1; self.issue = nil; self.findStatus = ""
            }
        }
    }
    @Published var text = ""
    @Published var revision = 0
    @Published var zoom: Double = 1
    @Published var layout = "single"
    @Published var toolbarMode = "always"
    @Published var syncScroll = true
    @Published var splitRatio = 50
    @Published var sourceView = false
    @Published var issue: String?
    @Published var showFind = false
    @Published var search = ""
    @Published var findRequest = 0
    @Published var findBackwards = false
    @Published var findStatus = ""
    @Published var rendered = false
    var printDocument: (() -> Void)?

    init(settings: ViewerSettings? = nil) {
        self.settings = settings ?? .shared
        layout = self.settings.defaults.string(forKey: "workspaceLayout") ?? "single"
        toolbarMode = ["auto", "hidden"].contains(self.settings.defaults.string(forKey: "toolbarMode") ?? "always") ? "auto" : "always"
        syncScroll = self.settings.defaults.object(forKey: "syncScroll") as? Bool ?? true
        splitRatio = self.settings.defaults.object(forKey: "splitRatio") as? Int ?? 50
        settingsObserver = self.settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    var width: Int { sourceView ? settings.sourceWidth : settings.readingWidth }
    var fullWidth: Bool { sourceView ? settings.sourceFullWidth : settings.readingFullWidth }
    var readingWidth: ReadingWidth {
        get { settings.readingFullWidth ? .full : (ReadingWidth.allCases.first { $0.pixels == settings.readingWidth } ?? .standard) }
        set {
            settings.readingFullWidth = newValue == .full
            if newValue != .full { settings.readingWidth = newValue.pixels }
        }
    }
    func setWidth(_ width: Int) {
        let spec = InterfaceSpec.shared.width
        let value = min(spec.maximum, max(spec.minimum, width))
        if sourceView { settings.sourceWidth = value } else { settings.readingWidth = value }
    }
    func setFullWidth(_ value: Bool) {
        if sourceView { settings.sourceFullWidth = value } else { settings.readingFullWidth = value }
    }
    func preset(_ width: Int) { setWidth(width); setFullWidth(false) }
    func resetWidth() { preset(sourceView ? InterfaceSpec.shared.width.sourceDefault : InterfaceSpec.shared.width.readingDefault) }
    func workspace(_ key: String, _ value: String) {
        switch key {
        case "view":
            guard ["reading", "source", "horizontal", "vertical"].contains(value) else { return }
            layout = ["reading", "source"].contains(value) ? "single" : value
            sourceView = value == "source"
            settings.defaults.set(layout, forKey: "workspaceLayout")
        case "toolbar":
            guard ["always", "auto"].contains(value) else { return }
            toolbarMode = value; settings.defaults.set(value, forKey: "toolbarMode")
        case "sync": syncScroll = value == "true"; settings.defaults.set(syncScroll, forKey: "syncScroll")
        case "ratio": splitRatio = min(80, max(20, Int(value) ?? 50)); settings.defaults.set(splitRatio, forKey: "splitRatio")
        case "readingFont", "sourceFont":
            guard ["system", "sans", "serif", "mono"].contains(value) else { return }
            if key == "readingFont" { settings.readingFont = value } else { settings.sourceFont = value }
        case "readingFontSize", "sourceFontSize":
            guard let size = Int(value), (12...28).contains(size) else { return }
            if key == "readingFontSize" { settings.readingFontSize = size } else { settings.sourceFontSize = size }
        case "readingWidth", "sourceWidth":
            guard let pixels = Int(value), pixels == 0 || (600...1800).contains(pixels) else { return }
            if key == "readingWidth" { settings.readingFullWidth = pixels == 0; if pixels > 0 { settings.readingWidth = pixels } }
            else { settings.sourceFullWidth = pixels == 0; if pixels > 0 { settings.sourceWidth = pixels } }
        default: break
        }
    }
    func toggleSource() {
        guard url != nil else { return }
        layout = "single"; sourceView.toggle(); showFind = false; findStatus = ""
    }
    func cycleTheme() {
        settings.theme = settings.theme == "system" ? "light" : settings.theme == "light" ? "dark" : "system"
    }
    func reload() {
        guard let url else { return }
        do { text = try DocumentLoader.read(url); revision += 1; issue = nil }
        catch { issue = error.localizedDescription }
    }
    func reveal() { if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
    func changeZoom(_ delta: Double) { zoom = min(2.5, max(0.5, ((zoom + delta) * 10).rounded() / 10)) }
    func find(backwards: Bool = false) { findBackwards = backwards; findRequest += 1 }
}

@MainActor
final class ViewerWindowController: NSWindowController, NSWindowDelegate {
    let model = ViewerModel()
    var openFiles: (([URL]) -> Void)?
    var chooseFile: (() -> Void)?
    var didClose: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "엠디봄"
        window.minSize = NSSize(width: 760, height: 480)
        window.isReleasedWhenClosed = false
        window.titlebarSeparatorStyle = .line
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: ViewerContentView(model: model,
            open: { [weak self] in self?.chooseFile?() }, openFiles: { [weak self] in self?.openFiles?($0) }))
        window.center()
        window.setFrameAutosaveName("MarkdownViewerWindow")
        window.setFrameUsingName("MarkdownViewerWindow")
        if NSApp.windows.contains(where: { $0 !== window && $0.isVisible }) {
            window.cascadeTopLeft(from: NSPoint(x: window.frame.minX + 28, y: window.frame.maxY - 28))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func load(url: URL, text: String) {
        model.url = url; model.text = text; model.revision += 1; model.issue = nil
        window?.title = url.lastPathComponent + " — 엠디봄"
        window?.representedURL = url
    }
    func windowWillClose(_ notification: Notification) { model.stopRefresh(); didClose?() }
}

struct ViewerContentView: View {
    @ObservedObject var model: ViewerModel
    let open: () -> Void
    let openFiles: ([URL]) -> Void
    var onWebReady: ((WebCoordinator) -> Void)? = nil
    @FocusState private var findFocused: Bool
    private let ui = InterfaceSpec.shared

    var body: some View {
        VStack(spacing: 0) {
            if model.showFind {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("문서에서 찾기", text: $model.search).textFieldStyle(.roundedBorder).focused($findFocused)
                        .onSubmit { model.find() }
                    Text(model.findStatus).font(.caption).foregroundStyle(.secondary)
                    Button { model.find(backwards: true) } label: { Image(systemName: "chevron.up") }
                        .accessibilityLabel("이전 검색 결과")
                    Button { model.find() } label: { Image(systemName: "chevron.down") }
                        .accessibilityLabel("다음 검색 결과")
                    Button("닫기") { model.showFind = false }
                }.padding(10).background(.bar).onAppear { findFocused = true }
                    .onExitCommand { model.showFind = false }
                Divider()
            }
            if let issue = model.issue {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(issue).font(.callout); Spacer()
                    Button("닫기") { model.issue = nil }
                }.padding(12).background(Color.orange.opacity(0.12))
                Divider()
            }
            MarkdownWebContent(model: model, openFiles: openFiles, openPanel: open, onReady: onWebReady)
            Divider()
            HStack(spacing: 6) {
                Text(model.url == nil ? "Ready · Local files only" : "\(String(format: "%.1f", Double(model.text.utf8.count) / 1024)) KB · Local file · Read only")
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(ui.label("readOnly")).padding(.trailing, 12)
                Button("−") { model.changeZoom(-0.1) }.disabled(model.zoom <= 0.5).accessibilityLabel("축소")
                Button("\(Int((model.zoom * 100).rounded()))%") { model.zoom = 1 }.monospacedDigit().frame(width: 48)
                Button("+") { model.changeZoom(0.1) }.disabled(model.zoom >= 2.5).accessibilityLabel("확대")
            }.font(.system(size: 11)).foregroundStyle(.secondary).buttonStyle(.borderless)
                .padding(.horizontal, 18).frame(height: 34).background(.bar)
        }
    }
}

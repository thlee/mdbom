import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ViewerCore

@main
enum MarkdownViewerApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var windows: [ViewerWindowController] = []
    private var recentMenu = NSMenu(title: "Open Recent")
    private var selfTest: IntegrationTest?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        if let index = CommandLine.arguments.firstIndex(of: "--self-test"),
           CommandLine.arguments.count > index + 1 {
            selfTest = IntegrationTest(reportURL: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            selfTest?.run()
            return
        }
        if windows.isEmpty { showWelcome() }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        openURLs(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) { openURLs(urls) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWelcome() }
        return true
    }

    func showWelcome() {
        let controller = makeWindow()
        controller.showWindow(nil)
    }

    @discardableResult func makeWindow() -> ViewerWindowController {
        let controller = ViewerWindowController()
        controller.openFiles = { [weak self] urls in self?.openURLs(urls) }
        controller.chooseFile = { [weak self] in self?.openDocument(nil) }
        controller.didClose = { [weak self, weak controller] in
            self?.windows.removeAll { $0 === controller }
        }
        windows.append(controller)
        return controller
    }

    func openURLs(_ urls: [URL]) {
        for url in urls {
            do {
                let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
                if let existing = windows.first(where: { $0.model.url == canonical }) {
                    existing.showWindow(nil)
                    continue
                }
                let text = try DocumentLoader.read(canonical)
                let controller = windows.first(where: { $0.model.url == nil }) ?? makeWindow()
                controller.load(url: canonical, text: text)
                controller.showWindow(nil)
                remember(canonical)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn’t open \(url.lastPathComponent)"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                if let window = NSApp.keyWindow {
                    alert.beginSheetModal(for: window)
                } else {
                    DispatchQueue.main.async { alert.runModal() }
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText,
                                     UTType(filenameExtension: "markdown") ?? .plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        // Keep SwiftUI and accessibility callbacks free of nested modal run loops.
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .OK { self?.openURLs(panel.urls) }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else { panel.begin(completionHandler: completion) }
    }

    var active: ViewerWindowController? {
        windows.first { $0.window === NSApp.keyWindow }
    }
    @objc func printDocument(_ sender: Any?) { active?.model.printDocument?() }
    @objc func reloadDocument(_ sender: Any?) { active?.model.reload() }
    @objc func revealDocument(_ sender: Any?) { active?.model.reveal() }
    @objc func zoomIn(_ sender: Any?) { active?.model.changeZoom(0.1) }
    @objc func zoomOut(_ sender: Any?) { active?.model.changeZoom(-0.1) }
    @objc func actualSize(_ sender: Any?) { active?.model.zoom = 1 }
    @objc func toggleSource(_ sender: Any?) { active?.model.toggleSource() }
    @objc func layoutChoice(_ sender: NSMenuItem) { active?.model.workspace("view", sender.representedObject as? String ?? "reading") }
    @objc func toolbarChoice(_ sender: NSMenuItem) { active?.model.workspace("toolbar", sender.representedObject as? String ?? "always") }
    @objc func toggleToolbar(_ sender: Any?) { if let model = active?.model { model.workspace("toolbar", model.toolbarMode == "always" ? "auto" : "always") } }
    @objc func cycleTheme(_ sender: Any?) { active?.model.cycleTheme() }
    @objc func find(_ sender: Any?) { active?.model.showFind = true }
    @objc func openRecent(_ sender: NSMenuItem) {
        if let path = sender.representedObject as? String { openURLs([URL(fileURLWithPath: path)]) }
    }
    @objc func clearRecent(_ sender: Any?) {
        UserDefaults.standard.removeObject(forKey: "recentDocuments")
        refreshRecentMenu()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if [#selector(printDocument), #selector(reloadDocument), #selector(revealDocument), #selector(find), #selector(toggleSource)].contains(item.action) {
            return active?.model.url != nil
        }
        if [#selector(zoomIn), #selector(zoomOut), #selector(actualSize)].contains(item.action) {
            return active != nil
        }
        return true
    }

    private func remember(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: "recentDocuments") ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(10)), forKey: "recentDocuments")
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecentMenu()
    }

    private func refreshRecentMenu() {
        recentMenu.removeAllItems()
        for path in UserDefaults.standard.stringArray(forKey: "recentDocuments") ?? [] {
            let url = URL(fileURLWithPath: path)
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent), keyEquivalent: "")
            item.target = self
            item.representedObject = path
            item.toolTip = path
            recentMenu.addItem(item)
        }
        if recentMenu.items.isEmpty {
            let empty = NSMenuItem(title: "No Recent Documents", action: nil, keyEquivalent: "")
            recentMenu.addItem(empty)
        } else {
            recentMenu.addItem(.separator())
            let clear = NSMenuItem(title: "Clear Menu", action: #selector(clearRecent), keyEquivalent: "")
            clear.target = self
            recentMenu.addItem(clear)
        }
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.applicationVersion: Bundle.main.object(forInfoDictionaryKey: "MDBomDisplayVersion") as? String ?? "1.0.0-beta.4"])
    }
    private func buildMenu() {
        let bar = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            item.submenu = menu; bar.addItem(item)
            return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = target
            menu.addItem(item)
        }
        let app = submenu("엠디봄")
        add(app, "About 엠디봄", #selector(showAbout), target: self)
        app.addItem(.separator())
        add(app, "Hide 엠디봄", #selector(NSApplication.hide(_:)), "h")
        app.addItem(.separator())
        add(app, "Quit 엠디봄", #selector(NSApplication.terminate(_:)), "q")
        let file = submenu("File")
        add(file, "Open…", #selector(openDocument), "o", target: self)
        let recent = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        recent.submenu = recentMenu; file.addItem(recent)
        file.addItem(.separator())
        add(file, "Reload from Disk", #selector(reloadDocument), "r", target: self)
        add(file, "Show in Finder", #selector(revealDocument), target: self)
        file.addItem(.separator())
        add(file, "Print…", #selector(printDocument), "p", target: self)
        file.addItem(.separator())
        add(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = submenu("Edit")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())
        add(edit, "Find…", #selector(find), "f", target: self)
        let view = submenu("View")
        add(view, "소스 / 문서 보기", #selector(toggleSource), "u", target: self)
        for (label, value) in [("문서", "reading"), ("소스", "source"), ("좌우 분할", "horizontal"), ("상하 분할", "vertical")] {
            let item = NSMenuItem(title: label, action: #selector(layoutChoice), keyEquivalent: "")
            item.target = self; item.representedObject = value; view.addItem(item)
        }
        view.addItem(.separator())
        for (label, value) in [("도구 항상 표시", "always"), ("도구 자동 숨김", "auto")] {
            let item = NSMenuItem(title: label, action: #selector(toolbarChoice), keyEquivalent: "")
            item.target = self; item.representedObject = value; view.addItem(item)
        }
        let tools = NSMenuItem(title: "도구바 고정 / 자동 숨김", action: #selector(toggleToolbar), keyEquivalent: "h")
        tools.keyEquivalentModifierMask = [.command, .shift]; tools.target = self; view.addItem(tools)
        let fullscreen = NSMenuItem(title: "전체화면 전환", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullscreen.keyEquivalentModifierMask = [.command, .control]; view.addItem(fullscreen)
        let themeItem = NSMenuItem(title: "테마 전환", action: #selector(cycleTheme), keyEquivalent: "t")
        themeItem.keyEquivalentModifierMask = [.command, .shift]
        themeItem.target = self
        view.addItem(themeItem)
        view.addItem(.separator())
        add(view, "Zoom In", #selector(zoomIn), "+", target: self)
        add(view, "Zoom Out", #selector(zoomOut), "-", target: self)
        add(view, "Actual Size", #selector(actualSize), "0", target: self)
        let window = submenu("Window")
        add(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(window, "Zoom", #selector(NSWindow.performZoom(_:)))
        NSApp.windowsMenu = window
        NSApp.mainMenu = bar
        refreshRecentMenu()
    }
}

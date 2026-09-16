import Foundation
import Combine
import RendererAssets

struct InterfaceSpec: Decodable {
    struct Width: Decodable { let minimum, maximum, step, readingDefault, sourceDefault: Int }
    struct Preset: Decodable, Identifiable { let title: String; let value: Int; var id: Int { value } }
    let width: Width
    let presets: [Preset]
    let toolbar: [String]
    let labels: [String: String]
    static let shared: InterfaceSpec = {
        let data = try! Data(contentsOf: RendererAssets.directory.appendingPathComponent("interface.json"))
        return try! JSONDecoder().decode(InterfaceSpec.self, from: data)
    }()
    func label(_ key: String) -> String { labels[key] ?? key }
}

@MainActor
final class ViewerSettings: ObservableObject {
    static let shared = ViewerSettings()
    let defaults: UserDefaults
    @Published var readingWidth: Int { didSet { defaults.set(readingWidth, forKey: "readingWidthPixels") } }
    @Published var sourceWidth: Int { didSet { defaults.set(sourceWidth, forKey: "sourceWidthPixels") } }
    @Published var readingFullWidth: Bool { didSet { defaults.set(readingFullWidth, forKey: "readingFullWidth") } }
    @Published var sourceFullWidth: Bool { didSet { defaults.set(sourceFullWidth, forKey: "sourceFullWidth") } }
    @Published var theme: String { didSet { defaults.set(theme, forKey: "viewerTheme") } }

    @Published var readingFont: String { didSet { defaults.set(readingFont, forKey: "readingFont") } }
    @Published var readingFontSize: Int { didSet { defaults.set(readingFontSize, forKey: "readingFontSize") } }
    @Published var sourceFont: String { didSet { defaults.set(sourceFont, forKey: "sourceFont") } }
    @Published var sourceFontSize: Int { didSet { defaults.set(sourceFontSize, forKey: "sourceFontSize") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let readingFamily = defaults.string(forKey: "readingFont") ?? "system"
        readingFont = ["system", "sans", "serif", "mono"].contains(readingFamily) ? readingFamily : "system"
        readingFontSize = min(28, max(12, defaults.object(forKey: "readingFontSize") as? Int ?? 16))
        let sourceFamily = defaults.string(forKey: "sourceFont") ?? "mono"
        sourceFont = ["system", "sans", "serif", "mono"].contains(sourceFamily) ? sourceFamily : "mono"
        sourceFontSize = min(28, max(12, defaults.object(forKey: "sourceFontSize") as? Int ?? 14))

        let spec = InterfaceSpec.shared.width
        // Preserve the exact width of the old Mac presets, including Standard=864.
        let legacy = defaults.string(forKey: "readingWidth")
        let legacyPixels = ["narrow": 680, "standard": 864, "wide": 1200][legacy ?? ""] ?? spec.readingDefault
        func pixels(_ key: String, fallback: Int) -> Int {
            guard let number = defaults.object(forKey: key) as? NSNumber else { return fallback }
            return min(spec.maximum, max(spec.minimum, number.intValue))
        }
        readingWidth = pixels("readingWidthPixels", fallback: legacyPixels)
        sourceWidth = pixels("sourceWidthPixels", fallback: spec.sourceDefault)
        readingFullWidth = defaults.object(forKey: "readingFullWidth") as? Bool ?? (legacy == "full")
        sourceFullWidth = defaults.bool(forKey: "sourceFullWidth")
        let savedTheme = defaults.string(forKey: "viewerTheme") ?? "system"
        theme = ["system", "light", "dark"].contains(savedTheme) ? savedTheme : "system"
    }
}

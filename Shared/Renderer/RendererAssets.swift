import Foundation

/// The same generated renderer and stylesheet embedded in the Windows executable.
public enum RendererAssets {
    // Packaged apps must use their own resources, never the original build machine.
    private static var resourceBundle: Bundle {
        if let url = Bundle.main.url(forResource: "RendererAssets_RendererAssets", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module // Swift Package / Xcode development runs
    }
    public static var directory: URL { resourceBundle.url(forResource: "Web", withExtension: nil)! }
    public static var scrollChecks: URL { resourceBundle.url(forResource: "Tests", withExtension: nil)!.appendingPathComponent("scroll-sync.js") }
}

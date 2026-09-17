// swift-tools-version: 5.9
import PackageDescription

// Swift resource wrapper over the same assets embedded by the Windows project.
let package = Package(
    name: "RendererAssets",
    products: [.library(name: "RendererAssets", targets: ["RendererAssets"])],
    targets: [
        .target(name: "RendererAssets", path: ".",
                exclude: ["renderer.js", "position.js", "workspace.js", "search.js", "rich-content.js"],
                resources: [.copy("Resources/Web"), .copy("Resources/Tests")])
    ]
)

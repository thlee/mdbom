// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownViewer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MarkdownViewer", targets: ["MarkdownViewer"])],
    dependencies: [.package(path: "../Shared/Renderer")],
    targets: [
        .target(name: "ViewerCore"),
        .executableTarget(name: "MarkdownViewer", dependencies: ["ViewerCore", .product(name: "RendererAssets", package: "Renderer")],
                          resources: [.copy("Resources/Web")])
    ]
)

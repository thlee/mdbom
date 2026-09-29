import AppKit

// From the repository root: swift macOS/Scripts/make-icon.swift /tmp/MDBom.iconset
// Both platform icons are resized from the same approved artwork.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("Shared/Branding/AppIcon.png")
guard let artwork = NSImage(contentsOf: source) else { fatalError("Cannot read \(source.path)") }
guard CommandLine.arguments.count == 2 else { fatalError("Provide an output .iconset directory") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func png(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    artwork.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                 from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for (name, pixels) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32),
                       ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256),
                       ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512),
                       ("icon_512x512@2x",1024)] {
    try png(pixels).write(to: directory.appendingPathComponent(name + ".png"))
}
// Windows ICO supports PNG-compressed entries; no Windows host is required to regenerate it.
let sizes = [16, 24, 32, 48, 64, 128, 256]
let images = sizes.map(png)
var ico = Data()
func word(_ value: UInt16) { ico.append(UInt8(value & 255)); ico.append(UInt8(value >> 8)) }
func dword(_ value: UInt32) {
    for shift in stride(from: 0, to: 32, by: 8) { ico.append(UInt8((value >> shift) & 255)) }
}
word(0); word(1); word(UInt16(sizes.count))
var offset = 6 + 16 * sizes.count
for (size, bytes) in zip(sizes, images) {
    ico.append(contentsOf: [UInt8(size == 256 ? 0 : size), UInt8(size == 256 ? 0 : size), 0, 0])
    word(1); word(32); dword(UInt32(bytes.count)); dword(UInt32(offset))
    offset += bytes.count
}
for bytes in images { ico.append(bytes) }
try ico.write(to: root.appendingPathComponent("Windows/src/MarkdownViewer/Assets/app.ico"))

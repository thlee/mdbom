import AppKit

// Rebuild with: swift macOS/Scripts/make-icon.swift /absolute/path/MarkdownViewer.iconset
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32),
                       ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256),
                       ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512),
                       ("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let outer = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888), xRadius: 195, yRadius: 195)
    NSGradient(starting: NSColor(calibratedRed: 0.13, green: 0.28, blue: 0.48, alpha: 1),
               ending: NSColor(calibratedRed: 0.055, green: 0.12, blue: 0.24, alpha: 1))!.draw(in: outer, angle: -90)
    let page = NSBezierPath(roundedRect: NSRect(x: 256, y: 198, width: 512, height: 636), xRadius: 44, yRadius: 44)
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill(); page.fill()
    NSColor(calibratedRed: 0.72, green: 0.8, blue: 0.9, alpha: 1).setStroke()
    for y in [710, 655, 338, 283] {
        let line = NSBezierPath(); line.move(to: NSPoint(x: 322, y: y)); line.line(to: NSPoint(x: y > 600 ? 660 : 700, y: y))
        line.lineWidth = 16; line.lineCapStyle = .round; line.stroke()
    }
    let color = NSColor(calibratedRed: 0.13, green: 0.29, blue: 0.53, alpha: 1)
    let m = NSBezierPath(); m.move(to: NSPoint(x: 325, y: 413)); m.line(to: NSPoint(x: 325, y: 566))
    m.line(to: NSPoint(x: 404, y: 476)); m.line(to: NSPoint(x: 483, y: 566)); m.line(to: NSPoint(x: 483, y: 413))
    m.lineWidth = 34; m.lineJoinStyle = .round; color.setStroke(); m.stroke()
    let arrow = NSBezierPath(); arrow.move(to: NSPoint(x: 635, y: 566)); arrow.line(to: NSPoint(x: 635, y: 423))
    arrow.move(to: NSPoint(x: 578, y: 480)); arrow.line(to: NSPoint(x: 635, y: 423)); arrow.line(to: NSPoint(x: 692, y: 480))
    arrow.lineWidth = 31; arrow.lineJoinStyle = .round; arrow.lineCapStyle = .round; arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
}

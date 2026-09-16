import Foundation

// A standalone test runner also works with Command Line Tools, which do not ship XCTest.
@main
struct CoreChecks {
    static var checks: [String: Bool] = [:]
    static func check(_ name: String, _ passed: Bool) { checks[name] = passed }
    static func rejects(_ name: String, _ operation: () throws -> Void) {
        do { try operation(); check(name, false) } catch { check(name, true) }
    }
    static func main() throws {
        let text = "# 안녕하세요 👋\n日本語 · café"
        check("UTF8", try DocumentLoader.decode(Data(text.utf8)) == text)
        check("UTF8_BOM", try DocumentLoader.decode(Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)) == text)
        check("UTF16_LE", try DocumentLoader.decode(Data([0xFF, 0xFE]) + text.data(using: .utf16LittleEndian)!) == text)
        check("UTF16_BE", try DocumentLoader.decode(Data([0xFE, 0xFF]) + text.data(using: .utf16BigEndian)!) == text)
        check("empty", try DocumentLoader.decode(Data()) == "")
        rejects("invalidEncoding") { _ = try DocumentLoader.decode(Data([0xFF, 0xFC, 0x00])) }
        rejects("binaryText") { _ = try DocumentLoader.decode(Data([65, 0, 66])) }
        check("uppercaseExtension", DocumentLoader.isMarkdown(URL(fileURLWithPath: "/tmp/README.MD")))
        check("markdownExtension", DocumentLoader.isMarkdown(URL(fileURLWithPath: "/tmp/한글.markdown")))
        check("rejectTextExtension", !DocumentLoader.isMarkdown(URL(fileURLWithPath: "/tmp/document.txt")))
        check("rejectRemoteFile", !DocumentLoader.isMarkdown(URL(string: "https://example.com/test.md")!))
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = base.appendingPathComponent("docs")
        let outside = base.appendingPathComponent("docs-other")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"), withDestinationURL: outside)
        check("localImagePath", try DocumentLoader.containedURL(path: "assets/한글 image.png", in: root).lastPathComponent == "한글 image.png")
        rejects("pathTraversal") { _ = try DocumentLoader.containedURL(path: "../docs-other/private.png", in: root) }
        rejects("symlinkEscape") { _ = try DocumentLoader.containedURL(path: "escape/private.png", in: root) }
        rejects("absolutePath") { _ = try DocumentLoader.containedURL(path: "/etc/passwd", in: root) }
        rejects("backslashPath") { _ = try DocumentLoader.containedURL(path: "..\\private.png", in: root) }
        let file = root.appendingPathComponent("test.md")
        let original = Data("# Original\n- [ ] unchanged".utf8)
        try original.write(to: file)
        _ = try DocumentLoader.read(file)
        check("originalUnchanged", try Data(contentsOf: file) == original)
        let big = root.appendingPathComponent("large.md")
        FileManager.default.createFile(atPath: big.path, contents: nil)
        let handle = try FileHandle(forWritingTo: big)
        try handle.truncate(atOffset: UInt64(DocumentLoader.maximumBytes + 1))
        try handle.close()
        rejects("oversizedFile") { _ = try DocumentLoader.read(big) }
        let report: [String: Any] = ["checks": checks, "passed": checks.values.filter { $0 }.count,
                                    "total": checks.count, "success": checks.values.allSatisfy { $0 }]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if !checks.values.allSatisfy({ $0 }) { exit(1) }
    }
}

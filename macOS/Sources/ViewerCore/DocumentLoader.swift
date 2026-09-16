import Foundation

public enum ViewerError: LocalizedError {
    case unsupportedFile, tooLarge, invalidEncoding, outsideFolder

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile: return "Choose a .md or .markdown file."
        case .tooLarge: return "This file is larger than the 10 MB reading limit."
        case .invalidEncoding: return "This file could not be read as UTF-8 or UTF-16 text."
        case .outsideFolder: return "Only files inside this document’s folder are accessible."
        }
    }
}

public enum DocumentLoader {
    public static let maximumBytes = 10 * 1024 * 1024

    public static func isMarkdown(_ url: URL) -> Bool {
        url.isFileURL && ["md", "markdown"].contains(url.pathExtension.lowercased())
    }

    public static func read(_ url: URL) throws -> String {
        guard isMarkdown(url) else { throw ViewerError.unsupportedFile }
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard attributes.isRegularFile == true else { throw ViewerError.unsupportedFile }
        guard (attributes.fileSize ?? 0) <= maximumBytes else { throw ViewerError.tooLarge }
        // A bounded read also handles files that grow after the size check.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw ViewerError.tooLarge }
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> String {
        let bytes = [UInt8](data.prefix(3))
        let encoding: String.Encoding
        let payload: Data
        if bytes.starts(with: [0xFF, 0xFE]) {
            encoding = .utf16LittleEndian; payload = data.dropFirst(2)
        } else if bytes.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16BigEndian; payload = data.dropFirst(2)
        } else {
            encoding = .utf8
            payload = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
        }
        guard let text = String(data: payload, encoding: encoding), !text.contains("\0") else {
            throw ViewerError.invalidEncoding
        }
        return text
    }

    /// The caller supplies a URL-decoded, relative path. Resolve symlinks before checking containment.
    public static func containedURL(path: String, in directory: URL) throws -> URL {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0"), !path.contains("\\") else {
            throw ViewerError.outsideFolder
        }
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        // Resolve each component so an existing symlink is still resolved when its final child does not exist.
        let requested = root.appendingPathComponent(path).standardizedFileURL
        var candidate = URL(fileURLWithPath: "/", isDirectory: true)
        for component in requested.pathComponents.dropFirst() {
            candidate = candidate.appendingPathComponent(component).resolvingSymlinksInPath()
        }
        guard candidate.path.hasPrefix(root.path == "/" ? "/" : root.path + "/") else {
            throw ViewerError.outsideFolder
        }
        return candidate
    }
}

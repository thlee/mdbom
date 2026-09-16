import Foundation
import ViewerCore

/// Poll the path, not an open file descriptor: editor atomic replacements remain visible.
/// Only metadata is read while idle. Two equal samples debounce writes; failed reads retry.
final class DocumentRefresh {
    private let timer: DispatchSourceTimer
    init(url: URL, changed: @escaping @Sendable (String) -> Void) {
        let queue = DispatchQueue(label: "MarkdownViewer.refresh", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        var candidate: String?
        var delivered: String?
        timer.setEventHandler {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                candidate = nil
                return
            }
            let signature = [.modificationDate, .size, .systemFileNumber].map {
                String(describing: attributes[$0])
            }.joined(separator: "|")
            guard candidate == signature else { candidate = signature; return }
            guard signature != delivered, let text = try? DocumentLoader.read(url),
                  let after = try? FileManager.default.attributesOfItem(atPath: url.path),
                  [.modificationDate, .size, .systemFileNumber].allSatisfy({
                      String(describing: attributes[$0]) == String(describing: after[$0])
                  }) else { return }
            delivered = signature
            changed(text)
        }
        timer.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500), leeway: .milliseconds(100))
        timer.resume()
    }
    deinit { timer.cancel() }
}

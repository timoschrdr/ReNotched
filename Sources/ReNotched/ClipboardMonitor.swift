import AppKit

/// Detects new clipboard entries.
final class ClipboardMonitor {
    var onCopy: ((String, String) -> Void)?   // (preview, SF Symbol)

    private var lastCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    func start() {
        let t = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.15 // lets the system coalesce wakeups
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount

        let types = pb.types ?? []
        let concealed = types.contains { $0.rawValue == "org.nspasteboard.ConcealedType" }
        if concealed { onCopy?(NSLocalizedString("Confidential content", comment: ""), "lock.fill"); return }

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            let extra = urls.count > 1 ? " +\(urls.count - 1)" : ""
            onCopy?(first.lastPathComponent + extra, "doc.fill")
        } else if let s = pb.string(forType: .string) {
            let flat = s.split(whereSeparator: \.isNewline).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            guard !flat.isEmpty else { return }
            onCopy?(String(flat.prefix(90)), "text.alignleft")
        } else if types.contains(.tiff) || types.contains(.png) {
            onCopy?(NSLocalizedString("Image", comment: ""), "photo.fill")
        } else {
            onCopy?(NSLocalizedString("Content", comment: ""), "doc.on.clipboard.fill")
        }
    }
}

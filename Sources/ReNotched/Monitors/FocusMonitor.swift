import Foundation

/// Reports Focus modes turning on or off.
///
/// macOS has no public API for this that works without a developer entitlement, so this reads the Focus
/// database in `~/Library/DoNotDisturb/DB` (read-only). That folder is protected: the feature only works
/// after the user grants Full Disk Access to the app. Without it, `isAvailable` is false and nothing happens.
final class FocusMonitor {
    struct State: Equatable { var id: String; var name: String; var symbol: String; var tint: String }

    /// Called with the active mode, or nil when Focus was turned off.
    var onChange: ((State?) -> Void)?

    private let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/DoNotDisturb/DB")
    private var source: DispatchSourceFileSystemObject?
    private var current: State?
    private var pending: DispatchWorkItem?

    var isAvailable: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) != nil
    }

    func start() {
        stop()
        guard isAvailable else { return }
        current = readState()
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .extend], queue: .main)
        src.setEventHandler { [weak self] in self?.scheduleRead() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel(); source = nil
        pending?.cancel(); pending = nil
    }

    /// The database is rewritten in several steps → read once, shortly after the last change.
    private func scheduleRead() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let new = self.readState()
            if new != self.current { self.current = new; self.onChange?(new) }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func json(_ name: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func readState() -> State? {
        guard let entries = json("Assertions.json")?["data"] as? [[String: Any]] else { return nil }
        for entry in entries {
            guard let records = entry["storeAssertionRecords"] as? [[String: Any]] else { continue }
            for record in records {
                guard let details = record["assertionDetails"] as? [String: Any],
                      let id = details["assertionDetailsModeIdentifier"] as? String else { continue }
                return describe(id)
            }
        }
        return nil
    }

    /// Fallbacks for the system's own modes: name, SF Symbol and tint.
    private static let builtIn: [String: (String, String, String)] = [
        "com.apple.donotdisturb.mode.default": ("Do Not Disturb", "moon.fill", "systemIndigoColor"),
        "com.apple.sleep.sleep-mode": ("Sleep", "bed.double.fill", "systemTealColor"),
        "com.apple.focus.work": ("Work", "person.lanyardcard.fill", "systemBlueColor"),
        "com.apple.focus.personal-time": ("Personal", "person.fill", "systemPurpleColor"),
        "com.apple.donotdisturb.mode.driving": ("Driving", "car.fill", "systemBlueColor"),
        "com.apple.focus.fitness": ("Fitness", "figure.run", "systemGreenColor"),
        "com.apple.focus.gaming": ("Gaming", "gamecontroller.fill", "systemIndigoColor"),
        "com.apple.focus.mindfulness": ("Mindfulness", "apple.meditate", "systemTealColor"),
        "com.apple.focus.reading": ("Reading", "book.fill", "systemOrangeColor"),
    ]

    /// Uses the name and symbol from the user's own mode configuration when available.
    private func describe(_ id: String) -> State {
        var name = Self.builtIn[id]?.0 ?? "Focus"
        var symbol = Self.builtIn[id]?.1 ?? "moon.fill"
        var tint = Self.builtIn[id]?.2 ?? "systemIndigoColor"
        if let configs = (json("ModeConfigurations.json")?["data"] as? [[String: Any]])?.first?["modeConfigurations"] as? [String: Any],
           let mode = (configs[id] as? [String: Any])?["mode"] as? [String: Any] {
            if let n = mode["name"] as? String, !n.isEmpty { name = n }
            if let s = mode["symbolImageName"] as? String, !s.isEmpty { symbol = s }
            if let t = mode["tintColorName"] as? String, !t.isEmpty { tint = t }
        }
        return State(id: id, name: name, symbol: symbol, tint: tint)
    }
}

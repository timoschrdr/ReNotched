import AppKit

/// Reads system-wide now-playing info (Music, Spotify, browsers, …) via the MediaRemote adapter.
@MainActor
final class NowPlayingMonitor {
    private let model: IslandModel
    private var process: Process?
    private var clearTask: Task<Void, Never>?
    private var stopped = false
    private let adapter: (script: String, framework: String)? = {
        guard let r = Bundle.main.resourceURL else { return nil }
        let s = r.appending(path: "mediaremote-adapter.pl").path
        let f = r.appending(path: "MediaRemoteAdapter.framework").path
        let fm = FileManager.default
        return fm.fileExists(atPath: s) && fm.fileExists(atPath: f) ? (s, f) : nil
    }()

    init(model: IslandModel) { self.model = model }

    func start() {
        guard let adapter, process == nil else { return }
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/perl")
        task.arguments = [adapter.script, adapter.framework, "stream", "--micros", "--debounce=180"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        let decoder = StreamDecoder()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            if data.isEmpty { h.readabilityHandler = nil; return }
            let updates = decoder.feed(data)
            guard !updates.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { updates.forEach { self?.apply($0) } } }
        }
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.process = nil
                    if !self.stopped { self.start() }
                }
            }
        }
        do { try task.run(); process = task } catch { NSLog("Adapter: \(error)") }
    }

    func stop() { stopped = true; process?.terminate() }

    private func apply(_ u: StreamDecoder.Update) {
        guard var t = u.track else {
            // Some players report nothing when paused, and all do so briefly between tracks → treat as paused after 1.5 s and drop the track only after 30 s.
            if model.track != nil, clearTask == nil {
                clearTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard !Task.isCancelled, let self else { return }
                    self.model.isPlaying = false   // treated as paused: cover shrinks
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    self.clearTask = nil
                    self.model.track = nil
                }
            }
            return
        }
        clearTask?.cancel(); clearTask = nil

        let old = model.track
        t.artwork = old?.artwork; t.artID = old?.artID ?? 0; t.tint = old?.tint ?? .white
        switch u.artwork {
        case .unchanged: break
        case .cleared: t.artwork = nil; t.tint = .white; t.artID += 1
        case .updated(let img, let tint): t.artwork = img; t.tint = tint; t.artID += 1
        }
        model.position = u.elapsed
        model.positionDate = u.stamp
        model.rate = u.rate
        model.track = t
        if model.isPlaying != u.playing { model.isPlaying = u.playing }
    }

    // MARK: Controls

    private func run(_ args: [String]) {
        guard let adapter else { return }
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/perl")
        task.arguments = [adapter.script, adapter.framework] + args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    func playPause() {
        model.position = model.livePosition
        model.positionDate = Date()
        model.isPlaying.toggle()
        run(["send", "2"])
    }
    func next() { run(["send", "4"]) }
    func previous() { run(["send", "5"]) }

    func seek(to seconds: Double) {
        model.position = seconds
        model.positionDate = Date()
        run(["seek", String(Int(seconds * 1e6))])
    }
}

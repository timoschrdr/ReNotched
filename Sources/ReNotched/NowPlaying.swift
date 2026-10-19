import AppKit
import ImageIO
import SwiftUI

/// Assembles the adapter's line-by-line JSON stream into the current now-playing state.
final class StreamDecoder {
    enum Artwork { case unchanged, cleared, updated(NSImage, Color) }
    struct Update { var track: Track?; var playing: Bool; var elapsed: Double; var stamp: Date; var rate: Double; var artwork: Artwork }

    private var buffer = Data()
    private var state: [String: Any] = [:]
    private var lastArtwork: String?

    func feed(_ data: Data) -> [Update] {
        buffer.append(data)
        var out: [Update] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let msg = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = msg["payload"] as? [String: Any] else { continue }
            if !(msg["diff"] as? Bool ?? false) { state.removeAll(keepingCapacity: true) }
            for (k, v) in payload { state[k] = v is NSNull ? nil : v }
            out.append(makeUpdate())
        }
        if buffer.count > 8_000_000 { buffer.removeAll() } // guard against unbounded growth
        return out
    }

    private func num(_ k: String) -> Double? { (state[k] as? NSNumber)?.doubleValue }

    private func makeUpdate() -> Update {
        var track: Track?
        if let title = state["title"] as? String, !title.isEmpty {
            track = Track(title: title, artist: state["artist"] as? String ?? "",
                          duration: max(0, num("durationMicros").map { $0 / 1e6 } ?? num("duration") ?? 0))
        }
        let rate = num("playbackRate").flatMap { $0 > 0 ? $0 : nil } ?? 1
        let stamp = num("timestampEpochMicros").map { Date(timeIntervalSince1970: $0 / 1e6) } ?? Date()
        let elapsed = max(0, num("elapsedTimeMicros").map { $0 / 1e6 } ?? num("elapsedTime") ?? 0)

        var art = Artwork.unchanged
        let current = state["artworkData"] as? String
        if current != lastArtwork {
            lastArtwork = current
            if let current, let data = Data(base64Encoded: current, options: .ignoreUnknownCharacters),
               let (img, tint) = Self.thumbnail(data) { art = .updated(img, tint) } else { art = .cleared }
        }
        return Update(track: track, playing: (state["playing"] as? NSNumber)?.boolValue ?? false,
                      elapsed: elapsed, stamp: stamp, rate: rate, artwork: art)
    }

    /// Downscaled cover (saves memory and rendering time) plus its dominant colour.
    private static func thumbnail(_ data: Data) -> (NSImage, Color)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 160] as CFDictionary) else { return nil }
        return (NSImage(cgImage: cg, size: .zero), dominantColor(cg))
    }

    /// Averages an 8×8 version weighted by saturation and brightens the colour so it reads on black.
    private static func dominantColor(_ cg: CGImage) -> Color {
        var px = [UInt8](repeating: 0, count: 8 * 8 * 4)
        guard let ctx = CGContext(data: &px, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .white }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        var r = 0.0, g = 0.0, b = 0.0, wsum = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let (pr, pg, pb) = (Double(px[i]) / 255, Double(px[i + 1]) / 255, Double(px[i + 2]) / 255)
            let mx = max(pr, pg, pb), mn = min(pr, pg, pb)
            let w = (mx - mn) * mx + 0.02
            r += pr * w; g += pg * w; b += pb * w; wsum += w
        }
        let c = NSColor(red: r / wsum, green: g / wsum, blue: b / wsum, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0
        c.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &v, alpha: nil)
        return Color(hue: h, saturation: s < 0.12 ? s : max(s, 0.55), brightness: max(v, 0.9))
    }
}

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
            // On track changes the adapter briefly reports nothing → only clear the track after a pause.
            if model.track != nil, clearTask == nil {
                clearTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard !Task.isCancelled, let self else { return }
                    self.clearTask = nil
                    self.model.track = nil
                    self.model.isPlaying = false
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

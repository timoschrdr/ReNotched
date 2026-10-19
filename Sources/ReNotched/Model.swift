import AppKit
import SwiftUI

struct Track {
    var title: String
    var artist: String
    var artwork: NSImage?
    var artID = 0              // changes with every new cover → triggers the cover animation
    var tint: Color = .white   // dominant colour of the cover
    var duration: Double = 0
}

enum Transient: Equatable {
    case volume(level: Float, muted: Bool)
    case copied(preview: String, symbol: String)
    case charging(percent: Int, plugged: Bool)
    case device(name: String, battery: Int?)
}

enum IslandMode: Equatable {
    case idle, volume, copied, device, musicCompact, musicExpanded
}

@MainActor
final class IslandModel: ObservableObject {
    @Published var notch = CGSize(width: 185, height: 32)
    @Published var transient: Transient?
    @Published var track: Track?
    @Published var isPlaying = false
    var position: Double = 0
    var positionDate = Date()
    var rate: Double = 1
    @Published private(set) var expanded = false

    private var transientTask: Task<Void, Never>?

    var mode: IslandMode {
        if let transient {
            switch transient {
            case .volume: return .volume
            case .copied: return .copied
            case .charging: return .volume
            case .device: return .device
            }
        }
        if track != nil { return expanded ? .musicExpanded : .musicCompact }
        return .idle
    }

    func size(for mode: IslandMode) -> CGSize {
        // The physical notch extends slightly below the safe-area inset → active island is 2 pt taller.
        let w = notch.width, h = notch.height + (mode == .idle ? 0 : 2)
        switch mode {
        case .idle: return CGSize(width: w, height: h)
        case .volume: return CGSize(width: w + 2 * 76, height: h)
        case .copied: return CGSize(width: w + 2 * 84, height: h + 36)
        case .device: return CGSize(width: w + 2 * 92, height: h + 40)
        case .musicCompact: return CGSize(width: w + 2 * 40, height: h)
        case .musicExpanded: return CGSize(width: max(w + 150, 380), height: h + 122)
        }
    }

    var currentSize: CGSize { size(for: mode) }

    // MARK: Transient events

    func show(_ value: Transient, for seconds: Double = 1.8) {
        transient = value
        transientTask?.cancel()
        transientTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.transient = nil
        }
    }

    func setExpanded(_ value: Bool) { if expanded != value { expanded = value } }

    var livePosition: Double {
        let p = position + (isPlaying ? Date().timeIntervalSince(positionDate) * rate : 0)
        guard let d = track?.duration, d > 0 else { return p }
        return min(p, d)
    }
}

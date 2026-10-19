import SwiftUI

/// Short-lived events that temporarily take over the island.
enum Transient: Equatable {
    case volume(level: Float, muted: Bool)
    case copied(preview: String, symbol: String)
    case charging(percent: Int, plugged: Bool)
    case device(name: String, battery: Int?)
    case focus(symbol: String, tint: String, on: Bool)
}

enum IslandMode: Equatable {
    case idle, volume, copied, device, focus, musicCompact, musicExpanded
}

/// Everything the island shows. `mode` is stored and only published when it really changes.
@MainActor
final class IslandModel: ObservableObject {
    @Published var notch = CGSize(width: 185, height: 32)
    @Published private(set) var transient: Transient? { didSet { refreshMode() } }
    @Published var track: Track? { didSet { updateDormancy(); refreshMode() } }
    @Published var isPlaying = false { didSet { updateDormancy() } }
    @Published private(set) var expanded = false { didSet { refreshMode() } }
    /// True once playback has been paused for 30 s: the island closes completely until playback resumes.
    @Published private(set) var dormant = false { didSet { refreshMode() } }
    @Published private(set) var mode = IslandMode.idle

    // Playback position is extrapolated from these, so they are not published.
    var position: Double = 0
    var positionDate = Date()
    var rate: Double = 1

    private var transientTask: Task<Void, Never>?
    private var dormantTask: Task<Void, Never>?

    var currentSize: CGSize { size(for: mode) }

    func size(for mode: IslandMode) -> CGSize {
        // The physical notch extends slightly below the safe-area inset → an active island is 2 pt taller.
        let w = notch.width, h = notch.height + (mode == .idle ? 0 : 2)
        switch mode {
        case .idle: return CGSize(width: w, height: h)
        case .volume: return CGSize(width: w + 2 * 76, height: h)
        case .copied: return CGSize(width: w + 2 * 84, height: h + 36)
        case .device: return CGSize(width: w + 2 * 92, height: h + 32)
        case .focus: return CGSize(width: w + 2 * 76, height: h)
        case .musicCompact: return CGSize(width: w + 2 * 40, height: h)
        case .musicExpanded: return CGSize(width: max(w + 150, 380), height: h + 122)
        }
    }

    var livePosition: Double {
        let p = position + (isPlaying ? Date().timeIntervalSince(positionDate) * rate : 0)
        guard let d = track?.duration, d > 0 else { return p }
        return min(p, d)
    }

    // MARK: State changes

    func show(_ value: Transient, for seconds: Double = 1.8) {
        transient = value
        transientTask?.cancel()
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.transient = nil
        }
    }

    func setExpanded(_ value: Bool) { if expanded != value { expanded = value } }

    // MARK: Derived state

    private func refreshMode() {
        let new = computeMode()
        if new != mode { mode = new }
    }

    private func computeMode() -> IslandMode {
        if let transient {
            switch transient {
            case .volume, .charging: return .volume
            case .copied: return .copied
            case .device: return .device
            case .focus: return .focus
            }
        }
        if track != nil && !dormant { return expanded ? .musicExpanded : .musicCompact }
        return .idle
    }

    /// After 30 s of pause the island closes completely; resuming brings it back.
    private func updateDormancy() {
        if track != nil && !isPlaying {
            guard dormantTask == nil, !dormant else { return }
            dormantTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                self.dormantTask = nil
                self.expanded = false
                self.dormant = true
            }
        } else {
            dormantTask?.cancel(); dormantTask = nil
            if dormant { dormant = false }
        }
    }
}

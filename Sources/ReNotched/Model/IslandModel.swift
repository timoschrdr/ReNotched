import SwiftUI

/// Short-lived events that temporarily take over the island.
enum Transient: Equatable {
    case volume(level: Float, muted: Bool, symbol: String?)   // symbol: headphones, if connected
    case copied(preview: String, symbol: String)
    case charging(percent: Int, plugged: Bool)
    case device(name: String, battery: Int?, symbol: String)
    case focus(symbol: String, tint: String, on: Bool)
}

enum IslandMode: Equatable {
    case idle, volume, charging, copied, device, focus, musicCompact, musicExpanded
}

/// Everything the island shows. `mode` is stored and only published when it really changes.
@MainActor
final class IslandModel: ObservableObject {
    @Published var notch = CGSize(width: 185, height: 32)
    /// How far an active island reaches below the notch's safe-area height. The panel sets it to the menu bar
    /// height, so the island ends exactly where windows begin on every MacBook and display scaling.
    var notchExtra: CGFloat = 1
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

    /// Width of the widest content beside the notch, per mode (the island is symmetric around the notch).
    private static func content(for mode: IslandMode) -> CGFloat {
        switch mode {
        case .volume: 34            // level bar (the speaker on the left is narrower)
        case .charging: 40          // "100%"
        case .copied: 64            // "Copied" and the check mark
        case .device: 28            // battery ring
        case .focus: 28             // "Off" (the wider of the two words)
        case .musicCompact: 22      // cover
        case .idle, .musicExpanded: 0
        }
    }

    func size(for mode: IslandMode) -> CGSize {
        // The physical notch reaches down to the menu bar's lower edge, slightly below the safe-area inset.
        let w = notch.width, h = notch.height + (mode == .idle ? 0 : notchExtra)
        let side = Self.content(for: mode) + SideLayout<EmptyView, EmptyView>.gap + SideLayout<EmptyView, EmptyView>.outer
        switch mode {
        case .idle: return CGSize(width: w, height: h)
        case .volume, .charging, .focus, .musicCompact: return CGSize(width: w + 2 * side, height: h)
        case .copied: return CGSize(width: w + 2 * side, height: h + 36)
        case .device: return CGSize(width: w + 2 * side, height: h + 32)
        case .musicExpanded: return CGSize(width: max(w + 175, 360), height: h + 124)
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
            case .volume: return .volume
            case .charging: return .charging
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

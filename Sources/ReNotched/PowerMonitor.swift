import Foundation
import IOKit.ps

/// Reports the charger being plugged in or removed (event-driven, no polling).
final class PowerMonitor {
    var onChange: ((Int, Bool) -> Void)?
    private var lastPlugged: Bool?
    private var source: CFRunLoopSource?

    func start() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue().check()
        }, ctx).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        check(announce: false)
    }

    private func check(announce: Bool = true) {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as? [CFTypeRef], let ps = list.first,
              let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] else { return }
        let plugged = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let percent = d[kIOPSCurrentCapacityKey] as? Int ?? 0
        defer { lastPlugged = plugged }
        if announce, let last = lastPlugged, last != plugged { onChange?(percent, plugged) }
    }
}

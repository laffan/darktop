import CoreGraphics
import DarktopCore

/// Thin wrapper over the Quartz Display Services gamma-table calls.
enum DisplayGamma {
    enum TableState {
        case matches
        case differs
        case unreadable
    }

    static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let capacity = count
        guard CGGetOnlineDisplayList(capacity, &displays, &count) == .success else { return [] }
        return Array(displays.prefix(Int(count)))
    }

    /// Loads the red-only tables. Returns false if the display refused them
    /// (AirPlay, Sidecar and DisplayLink displays typically do).
    @discardableResult
    static func apply(_ transfer: RedTransfer, to display: CGDirectDisplayID) -> Bool {
        let size = tableSize(for: display)
        let red = transfer.redTable(size: size)
        let zeros = [CGGammaValue](repeating: 0, count: size)
        return CGSetDisplayTransferByTable(display, UInt32(size), red, zeros, zeros) == .success
    }

    static func state(of transfer: RedTransfer, on display: CGDirectDisplayID) -> TableState {
        let capacity = tableSize(for: display)
        var red = [CGGammaValue](repeating: 0, count: capacity)
        var green = red
        var blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, UInt32(capacity), &red, &green, &blue, &count) == .success,
              count >= 2
        else { return .unreadable }
        let n = min(Int(count), capacity)
        let satisfied = transfer.isSatisfied(
            red: Array(red.prefix(n)),
            green: Array(green.prefix(n)),
            blue: Array(blue.prefix(n))
        )
        return satisfied ? .matches : .differs
    }

    static func isAsleep(_ display: CGDirectDisplayID) -> Bool {
        CGDisplayIsAsleep(display) != 0
    }

    /// Puts every display back on its ColorSync profile.
    static func restoreAll() {
        CGDisplayRestoreColorSyncSettings()
    }

    private static func tableSize(for display: CGDirectDisplayID) -> Int {
        let capacity = Int(CGDisplayGammaTableCapacity(display))
        return capacity >= 2 ? capacity : 256
    }
}

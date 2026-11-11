import AppKit
import DarktopCore

/// Owns the on/off state and keeps the red tables loaded while red mode is on.
///
/// macOS resets gamma tables after sleep, display changes and when other
/// color tools (f.lux, Night Shift, display utilities) apply their own, so a
/// once-a-second watchdog reads the tables back and reloads them if needed.
@MainActor
final class RedModeController: NSObject {
    private(set) var isOn = false

    var transfer: RedTransfer {
        didSet {
            if isOn && transfer != oldValue { applyToAll() }
        }
    }

    /// Awake displays that refused the gamma table and are still in full color.
    private(set) var unsupportedDisplayCount = 0

    /// True when something else keeps overwriting the tables.
    private(set) var isContested = false

    var onChange: (() -> Void)?

    private var watchdog: Timer?
    private var overwriteTimes: [Date] = []

    private static let watchdogInterval: TimeInterval = 1
    private static let contestWindow: TimeInterval = 30
    private static let contestThreshold = 3

    init(transfer: RedTransfer) {
        self.transfer = transfer
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ] {
            workspace.addObserver(self, selector: #selector(environmentChanged), name: name, object: nil)
        }
    }

    func toggle() {
        setOn(!isOn)
    }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        overwriteTimes.removeAll()
        isContested = false

        if on {
            applyToAll()
            startWatchdog()
        } else {
            stopWatchdog()
            DisplayGamma.restoreAll()
            unsupportedDisplayCount = 0
        }
        NSLog("Darktop: red mode %@", on ? "on" : "off")
        onChange?()
    }

    private func applyToAll() {
        var failures = 0
        for display in DisplayGamma.onlineDisplays() {
            if !DisplayGamma.apply(transfer, to: display) && !DisplayGamma.isAsleep(display) {
                failures += 1
            }
        }
        update(unsupported: failures, contested: isContested)
    }

    /// Reloads the tables on any display where they no longer match.
    @objc private func enforce() {
        guard isOn else { return }
        var failures = 0
        var overwritten = false

        for display in DisplayGamma.onlineDisplays() {
            let state = DisplayGamma.state(of: transfer, on: display)
            if state == .matches { continue }
            if DisplayGamma.apply(transfer, to: display) {
                if state == .differs { overwritten = true }
            } else if !DisplayGamma.isAsleep(display) {
                failures += 1
            }
        }

        let now = Date()
        if overwritten { overwriteTimes.append(now) }
        overwriteTimes.removeAll { now.timeIntervalSince($0) > Self.contestWindow }
        update(unsupported: failures, contested: overwriteTimes.count >= Self.contestThreshold)
    }

    private func update(unsupported: Int, contested: Bool) {
        guard unsupported != unsupportedDisplayCount || contested != isContested else { return }
        if unsupported > unsupportedDisplayCount {
            NSLog("Darktop: %ld display(s) refused the red gamma table", unsupported)
        }
        if contested && !isContested {
            NSLog("Darktop: another process keeps overwriting the gamma tables")
        }
        unsupportedDisplayCount = unsupported
        isContested = contested
        onChange?()
    }

    @objc private func environmentChanged(_ notification: Notification) {
        guard isOn else { return }
        // Reload now, then check again once the display pipeline has settled.
        applyToAll()
        perform(#selector(enforce), with: nil, afterDelay: 1)
        perform(#selector(enforce), with: nil, afterDelay: 3)
    }

    private func startWatchdog() {
        let timer = Timer(
            timeInterval: Self.watchdogInterval,
            target: self,
            selector: #selector(enforce),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0.1
        // .common keeps it firing while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
}

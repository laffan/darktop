import AppKit
import DarktopCore

/// Menu bar item: click toggles red mode, right-click (or control-click)
/// opens a small options menu.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let levelPercents = [100, 50, 25, 10]
    private static let levelKey = "redLevelPercent"
    private static let invertedKey = "inverted"

    private let startOn: Bool
    private lazy var controller = RedModeController(transfer: savedTransfer)
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var signalSources: [DispatchSourceSignal] = []

    init(startOn: Bool) {
        self.startOn = startOn
        super.init()
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Clear anything a previous run that crashed may have left on screen.
        DisplayGamma.restoreAll()
        restoreColorsOnSignals()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        menu.delegate = self

        controller.onChange = { [weak self] in self?.refreshIcon() }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )

        refreshIcon()
        if startOn { controller.setOn(true) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.setOn(false)
        DisplayGamma.restoreAll()
    }

    /// Gamma tables are normally dropped when the process exits, but restore
    /// explicitly on the usual termination signals as well.
    private func restoreColorsOnSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                DisplayGamma.restoreAll()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: - Status item

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            showMenu()
        } else {
            controller.toggle()
        }
    }

    private func showMenu() {
        rebuildMenu()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Detach so the next left click toggles instead of opening the menu.
        statusItem?.menu = nil
    }

    @objc private func displayOptionsChanged(_ notification: Notification) {
        refreshIcon()
    }

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        let summary: String
        if !controller.isOn {
            symbol = "lightbulb"
            summary = "Red mode off"
        } else if warnings.isEmpty {
            symbol = "lightbulb.fill"
            summary = "Red mode on"
        } else {
            symbol = "exclamationmark.triangle.fill"
            summary = "Red mode on, with warnings"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: summary)
        image?.isTemplate = true
        button.image = image
        button.toolTip = ([summary] + warnings).joined(separator: "\n")
            + "\nClick to toggle. Right-click for options."
    }

    /// Conditions under which the screen may not be fully red.
    private var warnings: [String] {
        guard controller.isOn else { return [] }
        var list: [String] = []
        let unsupported = controller.unsupportedDisplayCount
        if unsupported == 1 {
            list.append("1 display can't be switched and is still in full color")
        } else if unsupported > 1 {
            list.append("\(unsupported) displays can't be switched and are still in full color")
        }
        if controller.isContested {
            list.append("Another app keeps resetting display colors (f.lux, Night Shift, a display utility?)")
        }
        if NSWorkspace.shared.accessibilityDisplayShouldInvertColors {
            list.append("Accessibility › Invert Colors is on and can turn the red output cyan")
        }
        return list
    }

    // MARK: - Menu

    private func rebuildMenu() {
        menu.removeAllItems()

        let power = NSMenuItem(title: "Red Mode", action: #selector(toggleRedMode), keyEquivalent: "")
        power.target = self
        power.state = controller.isOn ? .on : .off
        menu.addItem(power)

        for warning in warnings {
            let item = NSMenuItem(title: "⚠︎ " + warning, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let invert = NSMenuItem(title: "Invert (Black Background)", action: #selector(toggleInverted), keyEquivalent: "")
        invert.target = self
        invert.state = controller.transfer.inverted ? .on : .off
        menu.addItem(invert)

        let levelMenu = NSMenu()
        let currentPercent = Int((controller.transfer.level * 100).rounded())
        for percent in Self.levelPercents {
            let item = NSMenuItem(title: "\(percent)%", action: #selector(chooseLevel(_:)), keyEquivalent: "")
            item.target = self
            item.tag = percent
            item.state = percent == currentPercent ? .on : .off
            levelMenu.addItem(item)
        }
        let level = NSMenuItem(title: "Red Level", action: nil, keyEquivalent: "")
        level.submenu = levelMenu
        menu.addItem(level)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Darktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    @objc private func toggleRedMode() {
        controller.toggle()
    }

    @objc private func toggleInverted() {
        UserDefaults.standard.set(!controller.transfer.inverted, forKey: Self.invertedKey)
        controller.transfer = savedTransfer
    }

    @objc private func chooseLevel(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: Self.levelKey)
        controller.transfer = savedTransfer
    }

    // MARK: - Settings

    private var savedTransfer: RedTransfer {
        let defaults = UserDefaults.standard
        let stored = defaults.integer(forKey: Self.levelKey)
        let percent = Self.levelPercents.contains(stored) ? stored : 100
        return RedTransfer(level: Float(percent) / 100, inverted: defaults.bool(forKey: Self.invertedKey))
    }
}

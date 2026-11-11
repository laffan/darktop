import AppKit

@main
enum DarktopMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        // `--on` starts with red mode already on, e.g. `open -a Darktop --args --on`.
        let delegate = AppDelegate(startOn: CommandLine.arguments.contains("--on"))
        app.delegate = delegate
        // Menu bar only: no Dock icon, even when run outside the .app bundle.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

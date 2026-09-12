import AppKit
import SwiftUI

/// AppKit owns this app's windows; SwiftUI owns the settings content.
@MainActor
final class SettingsController: NSWindowController {
    private let model: SettingsModel

    init(appDelegate: AppDelegate) {
        model = SettingsModel(ghostty: appDelegate.ghostty)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Settings"
        window.identifier = NSUserInterfaceItemIdentifier("quickStart.settings")
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 740, height: 560)
        window.setFrameAutosaveName("QuickStartSettings")
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model, appDelegate: appDelegate))
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        model.refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func close(_ sender: Any?) { window?.performClose(sender) }

    @IBAction func closeWindow(_ sender: Any?) { window?.performClose(sender) }
}

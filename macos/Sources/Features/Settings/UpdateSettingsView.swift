import Combine
import Sparkle
import SwiftUI

/// Observe Sparkle itself so menu checks and config reloads stay in sync with Settings.
final class UpdatePreferences: ObservableObject {
    @Published private(set) var checks = false
    @Published private(set) var downloads = false
    @Published private(set) var canCheck = false
    @Published private(set) var lastCheck: Date?

    init(updater: SPUUpdater) {
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$checks)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$downloads)
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        updater.publisher(for: \.lastUpdateCheckDate).assign(to: &$lastCheck)
    }
}

struct UpdateSettingsView: View {
    let controller: UpdateController
    @ObservedObject var settings: SettingsModel
    @ObservedObject private var state: UpdateViewModel
    @StateObject private var preferences: UpdatePreferences

    init(controller: UpdateController, settings: SettingsModel) {
        self.controller = controller
        self.settings = settings
        self.state = controller.viewModel
        _preferences = StateObject(wrappedValue: UpdatePreferences(updater: controller.updater))
    }

    private var sourceBuild: Bool { Bundle.main.infoDictionary?["QuickStartSourceBuild"] as? Bool == true }
    private var automaticUpdatesAllowed: Bool {
        !sourceBuild && Bundle.main.infoDictionary?["SUEnableAutomaticChecks"] as? Bool != false
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Ghostty Quick Start", value: version)
                if sourceBuild {
                    Label("Local source build", systemImage: "hammer")
                    Text("This build receives changes when you rebuild the project. Automatic updates are available in signed releases.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Updates come from Ghostty Quick Start releases.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Section("Automatic Updates") {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { preferences.checks },
                    set: { settings.set("auto-update", to: $0 ? "check" : "off") }
                ))
                .disabled(!automaticUpdatesAllowed)
                Toggle("Download updates automatically", isOn: Binding(
                    get: { preferences.downloads },
                    set: { settings.set("auto-update", to: $0 ? "download" : "check") }
                ))
                .disabled(!automaticUpdatesAllowed || !preferences.checks)
                Text("Downloaded updates are installed when you quit. You can also choose when to restart.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Check Now") {
                if let date = preferences.lastCheck {
                    LabeledContent("Last checked", value: date.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("No update check recorded.").foregroundStyle(.secondary)
                }
                Button("Check for Updates…") { controller.checkForUpdates() }
                    .disabled(sourceBuild || !preferences.canCheck)
                if !sourceBuild && state.state != .idle {
                    if case .installing = state.state {
                        Text(state.text)
                        Button("Restart to Complete Update…") { controller.checkForUpdates() }
                    } else {
                        UpdatePopoverView(model: state).padding(.vertical, 8)
                    }
                }
            }
        }
        .settingsFormStyle()
    }

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let appDelegate: AppDelegate
    @State private var selection: Page? = .layout
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    enum Page: String, CaseIterable, Identifiable {
        case layout = "Tabs & Sidebar", appearance = "Appearance", projects = "Projects"
        case updates = "Updates", advanced = "Advanced"
        var id: Self { self }
        var icon: String {
            switch self {
            case .layout: return "sidebar.left"
            case .appearance: return "textformat"
            case .projects: return "folder"
            case .updates: return "arrow.triangle.2.circlepath"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                navigation
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                withAnimation {
                                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                                }
                            } label: {
                                Image(systemName: "sidebar.left")
                            }
                            .help(columnVisibility == .detailOnly ? "Show Settings Sidebar" : "Hide Settings Sidebar")
                            .accessibilityLabel(columnVisibility == .detailOnly ? "Show Settings Sidebar" : "Hide Settings Sidebar")
                        }
                    }
            } else {
                navigation
            }
        }
        .alert("Settings Could Not Be Saved", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var sidebar: some View {
        List(Page.allCases, selection: $selection) { page in
            Label(page.rawValue, systemImage: page.icon).tag(page)
        }
        .listStyle(.sidebar)
    }

    private var navigation: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if #available(macOS 14.0, *) {
                    sidebar.toolbar(removing: .sidebarToggle)
                } else {
                    sidebar
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 180)
        } detail: {
            Group {
                switch selection ?? .layout {
                case .layout: LayoutSettingsView()
                case .appearance: AppearanceSettingsView(model: model, ghostty: model.ghostty)
                case .projects: ProjectSettingsView()
                case .updates: UpdateSettingsView(controller: appDelegate.updateController, settings: model)
                case .advanced: AdvancedSettingsView(model: model, ghostty: model.ghostty)
                }
            }
            .navigationTitle((selection ?? .layout).rawValue)
        }
    }
}

private struct LayoutSettingsView: View {
    @ObservedObject private var layout = QuickStartLayout.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show top tab bar", isOn: $layout.showsTopTabBar)
                Text("Keep tabs above the terminal while the project sidebar is open.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Sidebar") {
                Toggle("Collapse sidebar to icons", isOn: $layout.isCollapsed)
                Stepper(value: $layout.width, in: 200...440, step: 8) {
                    Text("Sidebar width: \(Int(layout.width)) pt").monospacedDigit()
                }
                .accessibilityValue("\(Int(layout.width)) points")
                Text("You can also drag the sidebar edge. Narrow windows keep space for the terminal.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Button("Reset Layout") {
                layout.width = QuickStartLayout.defaultWidth
                layout.isCollapsed = false
                layout.showsTopTabBar = true
            }
        }
        .settingsFormStyle()
    }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var ghostty: Ghostty.App

    var body: some View {
        Form {
            Section("Configuration") {
                Button("Open Ghostty Config File…") { ghostty.openConfigFile() }
                Button("Reload Configuration") {
                    model.refresh()
                    ghostty.reloadConfig()
                }
                Text("Settings choices apply to this fork only. Use “Use Config File” in Appearance to remove a choice and use your file again.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Show Settings File in Finder") {
                    let url = SettingsFile.url
                    NSWorkspace.shared.activateFileViewerSelecting([
                        FileManager.default.fileExists(atPath: url.path) ? url : url.deletingLastPathComponent()
                    ])
                }
            }
            Section("Configuration Errors") {
                if ghostty.config.errors.isEmpty {
                    Label("No configuration errors", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(ghostty.config.errors.enumerated()), id: \.offset) { _, error in
                        Text(error).font(.callout).textSelection(.enabled)
                    }
                }
            }
        }
        .settingsFormStyle()
    }
}

extension View {
    @ViewBuilder
    func settingsFormStyle() -> some View {
        if #available(macOS 26.0, *) {
            // The AppKit-hosted form has its own toolbar. Keep its first row clear.
            self.formStyle(.grouped).scrollEdgeEffectHidden(true)
        } else {
            self.formStyle(.grouped)
        }
    }
}

import AppKit
import SwiftUI

struct QuickStartSidebar: View {
    @ObservedObject var ghostty: Ghostty.App
    let controller: TerminalController
    @ObservedObject private var layout = QuickStartLayout.shared
    @ObservedObject private var store = PinnedFolderStore.shared
    @ObservedObject private var sessions = QuickStartSessions.shared
    @State private var errorMessage: String?
    @State private var hoveredFolder: URL?
    @State private var editingFolder: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if layout.isCollapsed {
                collapsedContent
            } else {
                expandedContent
            }
        }
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .sheet(isPresented: Binding(
            get: { editingFolder != nil },
            set: { if !$0 { editingFolder = nil } }
        )) {
            if let folder = editingFolder {
                QuickStartOptionsView(folder: folder, options: store.options(for: folder)) { options in
                    try store.setOptions(options, for: folder)
                }
            }
        }
        .alert("Quick Start", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var windowSessions: [QuickStartSessions.Session] {
        sessions.sessions(in: controller)
    }

    private var header: some View {
        HStack(spacing: 6) {
            if !layout.isCollapsed {
                Text("Quick Start").font(.headline)
                Spacer(minLength: 0)
                Button(action: addFolders) { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.borderless)
                    .help("Pin a folder")
                    .accessibilityLabel("Pin a folder")
            }
            Button { layout.isCollapsed.toggle() } label: {
                Image(systemName: "sidebar.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help(layout.isCollapsed ? "Expand sidebar" : "Collapse sidebar")
            .accessibilityLabel(layout.isCollapsed ? "Expand sidebar" : "Collapse sidebar")
        }
        .padding(.horizontal, layout.isCollapsed ? 6 : 12)
        .padding(.vertical, 10)
    }

    private var expandedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                sectionTitle("PINNED FOLDERS")
                if store.folders.isEmpty {
                    Button("Pin a Folder…", action: addFolders).padding(8)
                }
                ForEach(store.folders, id: \.self) { folder in
                    folderRow(folder)
                }
                Divider().padding(.vertical, 8)
                HStack {
                    sectionTitle("OPEN TABS · \(windowSessions.count)")
                    Spacer()
                    newTabButton
                }
                ForEach(windowSessions) { session in
                    QuickStartSessionRow(session: session, isCollapsed: false)
                }
            }
            .padding(8)
        }
    }

    private var collapsedContent: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.folders, id: \.self) { folder in
                    Button {
                        if let existing = sessions.sessions(for: folder).last {
                            sessions.focus(existing)
                        } else {
                            openNewTab(folder)
                        }
                    } label: {
                        Image(systemName: "folder")
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help(folder.path)
                    .accessibilityLabel("Open \(folder.lastPathComponent)")
                    .contextMenu {
                        Button("Open New Tab") { openNewTab(folder) }
                        Button("Configure…") { editingFolder = folder }
                        Button("Remove Pin", role: .destructive) { store.remove(folder) }
                    }
                }
                Divider().padding(.vertical, 4)
                ForEach(windowSessions) { session in
                    QuickStartSessionRow(session: session, isCollapsed: true)
                }
                newTabButton
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
    }

    private var newTabButton: some View {
        Button { controller.newTab(nil) } label: {
            Image(systemName: "plus").frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help("New tab (⌘T)")
        .accessibilityLabel("New tab")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func folderRow(_ folder: URL) -> some View {
        let openSessions = sessions.sessions(for: folder)
        return HStack(spacing: 0) {
            Button {
                if let existing = openSessions.first(where: \.isSelected) ?? openSessions.last {
                    sessions.focus(existing)
                } else {
                    openNewTab(folder)
                }
            } label: {
                HStack(spacing: 9) {
                    if store.options(for: folder).action == .shell || store.options(for: folder).action == .custom {
                        Image(systemName: "folder").foregroundStyle(.secondary).frame(width: 20)
                    } else {
                        QuickStartProgramIcon(program: .init(action: store.options(for: folder).action))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(folder.lastPathComponent.isEmpty ? folder.path : folder.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(store.options(for: folder).action.title)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if !openSessions.isEmpty {
                        Text("\(openSessions.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .help("Open tabs for this folder")
                    }
                }
                .padding(.vertical, 10)
                .padding(.leading, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(openSessions.isEmpty ? "Open \(folder.path)" : "Return to open tab for \(folder.path)")
            .accessibilityLabel("Open \(folder.lastPathComponent)")

            Button { editingFolder = folder } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Configure folder action")
            .accessibilityLabel("Configure \(folder.lastPathComponent)")
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(hoveredFolder == folder ? Color.primary.opacity(0.07) : .clear)
        )
        .onHover { hoveredFolder = $0 ? folder : nil }
        .contextMenu {
            Button("Open New Tab") { openNewTab(folder) }
            Button("Configure…") { editingFolder = folder }
            Divider()
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
            }
            Button("Remove Pin", role: .destructive) { store.remove(folder) }
        }
    }

    private func openNewTab(_ folder: URL) {
        do {
            try QuickStartLauncher.launch(
                folder, options: store.options(for: folder), ghostty: ghostty, parent: controller.window)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFolders() {
        let panel = NSOpenPanel()
        panel.title = "Pin Project Folders"
        panel.prompt = "Pin"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        guard let window = controller.window else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            do {
                for url in panel.urls { try store.pin(url) }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

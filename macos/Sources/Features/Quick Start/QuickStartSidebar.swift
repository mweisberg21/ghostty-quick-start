import AppKit
import SwiftUI

struct QuickStartSidebar: View {
    @ObservedObject var ghostty: Ghostty.App
    @ObservedObject private var store = PinnedFolderStore.shared
    @ObservedObject private var sessions = QuickStartSessions.shared
    @State private var errorMessage: String?
    @State private var hoveredFolder: URL?
    @State private var editingFolder: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Start").font(.headline)
                    Text("Your folders and open tabs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: addFolders) { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
                    .help("Pin a folder")
                    .accessibilityLabel("Pin a folder")
            }
            .padding(16)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    sectionTitle("PINNED FOLDERS")
                    if store.folders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pin a folder to open it in a terminal.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Pin a Folder…", action: addFolders)
                        }
                        .padding(8)
                    }
                    ForEach(store.folders, id: \.self) { folder in
                        folderRow(folder)
                    }
                    if !sessions.sessions.isEmpty {
                        Divider().padding(.vertical, 8)
                        sectionTitle("OPEN TABS · \(sessions.sessions.count)")
                        ForEach(sessions.sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
                .padding(8)
            }
            Divider()
            Text("Select an open tab to return to it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(14)
        }
        .frame(width: 224)
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

    private func sessionRow(_ session: QuickStartSessions.Session) -> some View {
        Button { sessions.focus(session) } label: {
            HStack(spacing: 9) {
                QuickStartProgramIcon(program: session.program)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.displayTitle)
                        .font(.system(size: 12, weight: session.isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    if let folder = session.folder {
                        Text(folder.path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                if session.isSelected {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                }
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(session.isSelected ? Color.accentColor.opacity(0.12) : .clear))
        .accessibilityLabel("Switch to \(session.displayTitle)")
        .accessibilityValue(session.isSelected ? "Selected" : "")
        .help(session.folder?.path ?? session.title)
    }

    private func openNewTab(_ folder: URL) {
        do {
            try QuickStartLauncher.launch(
                folder, options: store.options(for: folder), ghostty: ghostty, parent: NSApp.keyWindow)
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
        guard let window = NSApp.keyWindow else { return }
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

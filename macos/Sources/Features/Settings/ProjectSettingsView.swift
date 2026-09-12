import AppKit
import SwiftUI

struct ProjectSettingsView: View {
    @ObservedObject private var store = PinnedFolderStore.shared
    @State private var editingFolder: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Choose what starts in each project. Changes apply when you open a new tab.")
                    .foregroundStyle(.secondary)
                Button("Pin a Folder…", action: addFolders)
            }
            Section("Pinned Folders") {
                if store.folders.isEmpty {
                    Text("Pin a project folder to give it a launch action.").foregroundStyle(.secondary)
                }
                ForEach(store.folders, id: \.self) { folder in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(folder.lastPathComponent).fontWeight(.medium)
                            Text(folder.path).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle).help(folder.path)
                            Text(store.options(for: folder).action.title).font(.caption)
                        }
                        Spacer()
                        Button("Configure…") { editingFolder = folder }
                        Menu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                            }
                            Button("Remove Pin", role: .destructive) { store.remove(folder) }
                        } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .accessibilityLabel("Options for \(folder.lastPathComponent)")
                    }
                    .padding(.vertical, 4)
                }
            }
            Text("Removing a pin keeps the folder and its open tabs.").font(.callout).foregroundStyle(.secondary)
        }
        .settingsFormStyle()
        .sheet(isPresented: Binding(
            get: { editingFolder != nil }, set: { if !$0 { editingFolder = nil } }
        )) {
            if let folder = editingFolder {
                QuickStartOptionsView(folder: folder, options: store.options(for: folder)) { options in
                    try store.setOptions(options, for: folder)
                }
            }
        }
        .alert("Project Could Not Be Added", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

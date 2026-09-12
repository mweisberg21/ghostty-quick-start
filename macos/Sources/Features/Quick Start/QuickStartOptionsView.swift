import SwiftUI

struct QuickStartOptionsView: View {
    let folder: URL
    @State var options: QuickStartOptions
    let save: (QuickStartOptions) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(folder.lastPathComponent).font(.title3.weight(.semibold))
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Picker("On a new tab", selection: $options.action) {
                ForEach(QuickStartAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            .pickerStyle(.menu)
            if options.action == .custom {
                TextField("Command, for example: npm run dev", text: $options.customCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Custom command")
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("First, change to this folder.")
                if let command = options.command, !command.isEmpty {
                    Text("Then run:")
                    Text(command).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                } else {
                    Text("Keep the shell ready for your commands.")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            Text("An open tab keeps its current session. Use Open New Tab to run the saved action again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    do {
                        try save(options)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!options.isValid)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

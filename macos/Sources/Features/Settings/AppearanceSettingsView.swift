import AppKit
import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var ghostty: Ghostty.App
    @State private var choosesTheme = false
    @State private var themeSearch = ""
    private let fonts = NSFontManager.shared.availableFontFamilies.sorted()
    private let themes: [String] = {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("ghostty/themes") else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { !$0.hasPrefix(".") }.sorted()
    }()

    var body: some View {
        Form {
            Section {
                preview
            }
            Section("Colors") {
                LabeledContent("Theme") {
                    Button(model.values["theme"] ?? "Use Config File") { choosesTheme = true }
                        .lineLimit(1)
                }
                Stepper(value: Binding(
                    get: { ghostty.config.backgroundOpacity },
                    set: { model.set("background-opacity", to: String($0)) }
                ), in: 0.2...1, step: 0.05) {
                    Text("Background opacity: \(Int((ghostty.config.backgroundOpacity * 100).rounded()))%")
                        .monospacedDigit()
                }
                .accessibilityValue("\(Int((ghostty.config.backgroundOpacity * 100).rounded())) percent")
                Text("Opacity changes can require a new window.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Text") {
                Picker("Font", selection: choice("font-family")) {
                    Text("Use Config File").tag("")
                    if let selected = model.values["font-family"], !fonts.contains(selected) {
                        Text(selected).tag(selected)
                    }
                    ForEach(fonts, id: \.self) { Text($0).tag($0) }
                }
                Stepper(value: Binding(
                    get: { ghostty.config.settingsFontSize },
                    set: { model.set("font-size", to: String($0)) }
                ), in: 6...72, step: 1) {
                    Text("Text size: " + ghostty.config.settingsFontSize.formatted() + " pt").monospacedDigit()
                }
                .accessibilityValue(ghostty.config.settingsFontSize.formatted() + " points")
                Text("Tabs with a manual zoom can keep their current text size.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Spacing") {
                paddingPicker("Horizontal padding", key: "window-padding-x")
                paddingPicker("Vertical padding", key: "window-padding-y")
            }
            Button("Use Config File for All Appearance Settings") { model.resetAppearance() }
                .disabled(SettingsFile.appearanceKeys.isDisjoint(with: model.values.keys))
        }
        .settingsFormStyle()
        .sheet(isPresented: $choosesTheme) { themePicker }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("~/Projects/your-app").opacity(0.65)
            Text("❯ git status")
            Text("On branch main\nYour project is ready.")
        }
        .font(previewFont)
        .foregroundStyle(ghostty.config.settingsForeground)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ghostty.config.backgroundColor, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample terminal text in the current colors")
    }

    private var previewFont: Font {
        let size = min(ghostty.config.settingsFontSize, 24)
        if let family = model.values["font-family"],
           let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return Font(font)
        }
        return .system(size: size, design: .monospaced)
    }

    private func choice(_ key: String) -> Binding<String> {
        Binding(get: { model.values[key] ?? "" }, set: { model.set(key, to: $0.isEmpty ? nil : $0) })
    }

    private func paddingPicker(_ title: String, key: String) -> some View {
        Picker(title, selection: choice(key)) {
            Text("Use Config File").tag("")
            ForEach(["0", "2", "4", "8", "12", "16", "24", "32"], id: \.self) { Text($0 + " pt").tag($0) }
            if let value = model.values[key], !["0", "2", "4", "8", "12", "16", "24", "32"].contains(value) {
                Text(value + " pt").tag(value)
            }
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Theme").font(.title2.weight(.semibold))
            TextField("Search themes", text: $themeSearch).textFieldStyle(.roundedBorder)
            List {
                Button("Use Config File") {
                    model.set("theme", to: nil)
                    choosesTheme = false
                }
                ForEach(themes.filter { themeSearch.isEmpty || $0.localizedCaseInsensitiveContains(themeSearch) }, id: \.self) { theme in
                    Button {
                        model.set("theme", to: theme)
                        choosesTheme = false
                    } label: {
                        Text(theme)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text("Colors change when you select a theme.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { choosesTheme = false }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 460)
    }
}

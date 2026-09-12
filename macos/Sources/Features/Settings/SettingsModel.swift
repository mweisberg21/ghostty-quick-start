import SwiftUI
import GhosttyKit

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var values: [String: String] = [:]
    @Published var errorMessage: String?
    let ghostty: Ghostty.App
    private let file: SettingsFile

    init(ghostty: Ghostty.App, file: SettingsFile = SettingsFile(url: SettingsFile.url)) {
        self.ghostty = ghostty
        self.file = file
        refresh()
    }

    func refresh() {
        do { values = try file.read() } catch { errorMessage = error.localizedDescription }
    }

    func set(_ key: String, to value: String?) {
        change { $0[key] = value }
    }

    func resetAppearance() {
        change { values in
            for key in SettingsFile.appearanceKeys { values.removeValue(forKey: key) }
        }
    }

    private func change(_ edit: (inout [String: String]) -> Void) {
        do {
            // Read again so another Settings action or external edit is not lost.
            var next = try file.read()
            edit(&next)
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ghostty")
            defer { try? FileManager.default.removeItem(at: temporary) }
            try SettingsFile.text(for: next).write(to: temporary, atomically: true, encoding: .utf8)
            let candidate = Ghostty.Config(config: Ghostty.Config.loadConfig(at: nil, finalize: true, settingsURL: temporary))
            guard candidate.loaded else { throw SettingsError.loadFailed }
            guard candidate.errors.isEmpty else { throw SettingsError.invalid(candidate.errors.joined(separator: "\n")) }
            try file.write(next)
            values = next
            ghostty.reloadConfig()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    enum SettingsError: LocalizedError {
        case loadFailed
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .loadFailed: return "The settings could not be loaded. Your saved settings have not changed."
            case .invalid(let message): return message
            }
        }
    }
}

extension Ghostty.Config {
    var settingsFontSize: Double {
        var value: Float = 13
        _ = ghostty_config_get(config, &value, "font-size", 9)
        return Double(value)
    }

    var settingsForeground: Color {
        var value = ghostty_config_color_s()
        guard ghostty_config_get(config, &value, "foreground", 10) else { return .primary }
        return Color(red: Double(value.r) / 255, green: Double(value.g) / 255, blue: Double(value.b) / 255)
    }
}

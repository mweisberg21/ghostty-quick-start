import Foundation
import Testing
@testable import Ghostty

struct SettingsFileTests {
    @Test func savesAndRestoresOnlyForkSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = SettingsFile(url: directory.appendingPathComponent("settings.ghostty"))
        #expect(try file.read().isEmpty)
        let values = ["font-family": "JetBrains Mono", "font-size": "18", "auto-update": "download"]
        try file.write(values)
        #expect(try file.read() == values)
        let text = try String(contentsOf: file.url, encoding: .utf8)
        #expect(text.contains("font-family =\nfont-family = JetBrains Mono\n"))
        try file.write(["auto-update": "check"])
        #expect(try file.read() == ["auto-update": "check"])
    }

    @Test func refusesUnknownContentAndExtraConfigLines() throws {
        #expect(throws: SettingsFile.FileError.self) {
            try SettingsFile.parse("command = echo hello\n")
        }
        #expect(throws: SettingsFile.FileError.self) {
            try SettingsFile.text(for: ["font-family": "Menlo\ncommand = echo hello"])
        }
        #expect(throws: SettingsFile.FileError.self) {
            try SettingsFile.text(for: ["command": "echo hello"])
        }
    }

    @Test func overridesApplyAfterBaseAndResetRestoresBase() throws {
        let base = try TemporaryConfig("font-size = 17\nbackground-opacity = 0.85\nauto-update = off\n")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = SettingsFile(url: directory.appendingPathComponent("settings.ghostty"))
        let original = try Data(contentsOf: base.temporaryFile)
        try file.write(["font-size": "22", "auto-update": "download"])
        let config = Ghostty.Config(config: Ghostty.Config.loadConfig(
            at: base.temporaryFile.path, finalize: true, settingsURL: file.url))
        #expect(config.errors.isEmpty)
        #expect(config.settingsFontSize == 22)
        #expect(config.backgroundOpacity == 0.85)
        #expect(config.autoUpdate == .download)
        try file.write([:])
        let reset = Ghostty.Config(config: Ghostty.Config.loadConfig(
            at: base.temporaryFile.path, finalize: true, settingsURL: file.url))
        #expect(reset.settingsFontSize == 17)
        #expect(reset.autoUpdate == .off)
        #expect(try Data(contentsOf: base.temporaryFile) == original)
    }

    @Test func invalidWriteLeavesSavedFileIntact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = SettingsFile(url: directory.appendingPathComponent("settings.ghostty"))
        try file.write(["font-size": "16"])
        #expect(throws: SettingsFile.FileError.self) {
            try file.write(["font-family": "Menlo\rcommand = false"])
        }
        #expect(try file.read() == ["font-size": "16"])
    }
}

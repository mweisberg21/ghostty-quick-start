import Foundation
import Testing
@testable import Ghostty

@MainActor
struct QuickStartTests {
    @Test func pinsPersistWithoutDuplicatesAndCanBeRemoved() throws {
        let name = "QuickStartTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let store = PinnedFolderStore(defaults: defaults)
        try store.pin(folder)
        try store.pin(folder.appendingPathComponent("."))
        #expect(store.folders.count == 1)
        let restored = PinnedFolderStore(defaults: defaults)
        #expect(restored.folders.map(\.path) == [folder.path])
        restored.remove(restored.folders[0])
        #expect(PinnedFolderStore(defaults: defaults).folders.isEmpty)
    }

    @Test func rejectsMissingFoldersAndRegularFiles() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(throws: PinnedFolderStore.FolderError.self) {
            try QuickStartLauncher.configuration(for: file)
        }
        #expect(throws: PinnedFolderStore.FolderError.self) {
            try QuickStartLauncher.configuration(for: file.appendingPathComponent("missing"))
        }
    }

    @Test func specialCharactersRemainDataAndLaunchInTheSelectedFolder() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Quick Start '\";$()\n\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let marker = UUID().uuidString
        try Data(marker.utf8).write(to: folder.appendingPathComponent("quick-start-cwd-check.txt"))
        let config = try QuickStartLauncher.configuration(for: folder, options: .init(action: .claude))
        #expect(config.workingDirectory == folder.path)
        #expect(config.initialInput?.contains(folder.path) == false)

        // Execute the real startup input with a harmless Claude substitute.
        // Start elsewhere to prove cd still works after shell startup.
        for shell in ["/bin/zsh", "/bin/bash"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.currentDirectoryURL = URL(fileURLWithPath: "/")
            process.environment = ProcessInfo.processInfo.environment.merging(config.environmentVariables) { _, new in new }
            process.arguments = ["-c", "claude() { /bin/cat quick-start-cwd-check.txt; }; " + (config.initialInput ?? "")]
            let output = Pipe()
            process.standardOutput = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            #expect(String(data: data, encoding: .utf8) == marker)
        }
    }

    @Test func defaultsToShellAndSavesIndependentFolderActions() throws {
        let name = "QuickStartTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let folder = FileManager.default.temporaryDirectory
        // Existing pins load without a destructive migration.
        defaults.set([folder.path], forKey: PinnedFolderStore.storageKey)
        let store = PinnedFolderStore(defaults: defaults)
        #expect(store.folders.count == 1)
        #expect(store.options(for: folder).action == .shell)
        let config = try QuickStartLauncher.configuration(for: folder)
        #expect(config.environmentVariables["GHOSTTY_QUICK_START_COMMAND"] == nil)
        #expect(config.initialInput == "cd -- \"$GHOSTTY_QUICK_START_DIRECTORY\"\n")
        try store.setOptions(.init(action: .codex), for: folder)
        let restored = PinnedFolderStore(defaults: defaults)
        #expect(restored.options(for: folder).action == .codex)
        #expect(restored.options(for: URL(fileURLWithPath: "/")).action == .shell)
        restored.remove(restored.folders[0])
        #expect(PinnedFolderStore(defaults: defaults).options(for: folder).action == .shell)
    }

    @Test func cliPresetsAndCustomCommands() throws {
        let folder = FileManager.default.temporaryDirectory
        for (action, command) in [(QuickStartAction.claude, "claude"), (.codex, "codex"), (.cursor, "agent")] {
            let config = try QuickStartLauncher.configuration(for: folder, options: .init(action: action))
            #expect(config.environmentVariables["GHOSTTY_QUICK_START_COMMAND"] == command)
        }
        #expect(!QuickStartOptions(action: .custom).isValid)
        #expect(!QuickStartOptions(action: .custom, customCommand: "echo one\necho two").isValid)
        #expect(throws: PinnedFolderStore.FolderError.self) {
            try QuickStartLauncher.configuration(for: folder, options: .init(action: .custom))
        }
        let command = "printf 'custom command'; printf ' in folder'"
        let config = try QuickStartLauncher.configuration(
            for: folder, options: .init(action: .custom, customCommand: command))
        #expect(config.environmentVariables["GHOSTTY_QUICK_START_COMMAND"] == command)
        // The folder can disappear after validation. No part of a compound
        // custom command must run if the later cd fails.
        for shell in ["/bin/zsh", "/bin/bash"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            var environment = config.environmentVariables
            environment["GHOSTTY_QUICK_START_DIRECTORY"] = "/missing-\(UUID().uuidString)"
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
            process.arguments = ["-c", config.initialInput ?? ""]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            #expect(process.terminationStatus != 0)
            #expect(data.isEmpty)
        }
    }
}

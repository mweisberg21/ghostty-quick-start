import AppKit
import GhosttyKit

@MainActor
enum QuickStartLauncher {
    static func configuration(
        for folder: URL,
        options: QuickStartOptions = .init()
    ) throws -> Ghostty.SurfaceConfiguration {
        try PinnedFolderStore.validate(folder)
        guard options.isValid else { throw PinnedFolderStore.FolderError.invalidCommand }
        var config = Ghostty.SurfaceConfiguration()
        config.context = GHOSTTY_SURFACE_CONTEXT_TAB
        config.workingDirectory = folder.path
        // Pass the path as data, never as terminal input. This also handles names
        // containing quotes, newlines, and shell syntax. Repeat cd after shell
        // startup because login scripts can change the working directory.
        config.environmentVariables["GHOSTTY_QUICK_START_DIRECTORY"] = folder.path
        let changeDirectory = "cd -- \"$GHOSTTY_QUICK_START_DIRECTORY\""
        if let command = options.command {
            // Evaluate the user-selected command only after cd succeeds, even
            // when a custom command contains several shell operations.
            config.environmentVariables["GHOSTTY_QUICK_START_COMMAND"] = command
            config.initialInput = changeDirectory + " && eval \"$GHOSTTY_QUICK_START_COMMAND\"\n"
        } else {
            config.initialInput = changeDirectory + "\n"
        }
        return config
    }

    static func launch(
        _ folder: URL,
        options: QuickStartOptions,
        ghostty: Ghostty.App,
        parent: NSWindow?
    ) throws {
        let config = try configuration(for: folder, options: options)
        if let controller = TerminalController.newTab(ghostty, from: parent, withBaseConfig: config) {
            controller.quickStartFolder = folder
            QuickStartSessions.shared.refresh()
        }
    }
}

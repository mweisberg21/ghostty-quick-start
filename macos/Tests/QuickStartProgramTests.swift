import Foundation
import Testing
@testable import Ghostty

struct QuickStartProgramTests {
    @Test func identifiesNativeCLIInstallations() {
        #expect(QuickStartProgram.identify(executablePath: "/Users/test/.local/share/claude/versions/2.1.269") == .claude)
        #expect(QuickStartProgram.identify(executablePath: "/opt/homebrew/bin/claude") == .claude)
        #expect(QuickStartProgram.identify(executablePath: "/Users/test/.codex/packages/bin/codex") == .codex)
        #expect(QuickStartProgram.identify(executablePath: "/Users/test/.local/share/cursor-agent/versions/123/node") == .cursor)
    }

    @Test func identifiesNodeScriptsWithoutReadingPromptsAsPrograms() {
        #expect(QuickStartProgram.identify(executablePath: "/usr/bin/node", arguments: [
            "node", "--no-warnings", "/lib/node_modules/@openai/codex/bin/codex.js"
        ]) == .codex)
        #expect(QuickStartProgram.identify(executablePath: "/usr/bin/node", arguments: [
            "node", "/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        ]) == .claude)
        #expect(QuickStartProgram.identify(executablePath: "/usr/bin/node", arguments: [
            "node", "/projects/server.js", "claude", "codex"
        ]) == .terminal)
    }

    @Test func shellAndOtherProgramsKeepTerminalIcon() {
        #expect(QuickStartProgram.identify(executablePath: "/bin/zsh", arguments: ["zsh", "claude"]) == .terminal)
        #expect(QuickStartProgram.identify(executablePath: "/usr/bin/vim") == .terminal)
        #expect(QuickStartProgram.identify(executablePath: "/tools/agent") == .terminal)
        #expect(QuickStartProgram.foreground(pid: nil) == .terminal)
        #expect(QuickStartProgram.foreground(pid: -1) == .terminal)
    }

    @Test func readsLiveProcessAndHandlesExit() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["10"]
        try process.run()
        #expect(QuickStartProgram.foreground(pid: Int(process.processIdentifier)) == .terminal)
        process.terminate()
        process.waitUntilExit()
        #expect(QuickStartProgram.foreground(pid: Int(process.processIdentifier)) == .terminal)
    }

    @Test func configuredActionsUseMatchingIcons() {
        #expect(QuickStartProgram(action: .claude) == .claude)
        #expect(QuickStartProgram(action: .cursor) == .cursor)
        #expect(QuickStartProgram(action: .codex) == .codex)
        #expect(QuickStartProgram(action: .shell) == .terminal)
        #expect(QuickStartProgram(action: .custom) == .terminal)
    }
}

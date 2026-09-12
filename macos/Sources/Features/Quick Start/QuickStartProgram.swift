import AppKit
import Darwin
import SwiftUI

enum QuickStartProgram: Equatable {
    case terminal, claude, cursor, codex

    var title: String {
        switch self {
        case .terminal: return "Terminal"
        case .claude: return "Claude"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .terminal: return nil
        case .claude: return "com.anthropic.claudefordesktop"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .codex: return "com.openai.codex"
        }
    }

    init(action: QuickStartAction) {
        switch action {
        case .claude: self = .claude
        case .cursor: self = .cursor
        case .codex: self = .codex
        case .shell, .custom: self = .terminal
        }
    }

    /// Identify executable paths, including native and npm installations.
    /// Do not use tab titles: they can be renamed or left behind after exit.
    static func identify(executablePath: String, arguments: [String] = []) -> Self {
        if let program = identifyPath(executablePath) { return program }
        let executable = URL(fileURLWithPath: executablePath).lastPathComponent.lowercased()
        guard ["node", "bun", "deno"].contains(executable) else { return .terminal }
        // Only inspect the runtime's script, never prompts or later arguments.
        if let script = arguments.dropFirst().first(where: { !$0.hasPrefix("-") }),
           let program = identifyPath(script) {
            return program
        }
        return .terminal
    }

    private static func identifyPath(_ path: String) -> Self? {
        let path = path.lowercased()
        let name = URL(fileURLWithPath: path).lastPathComponent
        if name == "claude" || path.contains("/claude/versions/") || path.contains("/@anthropic-ai/claude-code/") {
            return .claude
        }
        if name == "codex" || path.contains("/@openai/codex/") { return .codex }
        if name == "cursor-agent" || path.contains("/cursor-agent/") { return .cursor }
        return nil
    }

    static func foreground(pid: Int?) -> Self {
        guard let pid, let processID = Int32(exactly: pid), processID > 0 else { return .terminal }
        // libproc's PROC_PIDPATHINFO_MAXSIZE macro is 4 * MAXPATHLEN.
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(processID, &buffer, UInt32(buffer.count)) > 0 else { return .terminal }
        let path = String(cString: buffer)
        if let program = identifyPath(path) { return program }
        guard ["node", "bun", "deno"].contains(URL(fileURLWithPath: path).lastPathComponent) else {
            return .terminal
        }
        return identify(executablePath: path, arguments: arguments(for: processID))
    }

    private static func arguments(for pid: Int32) -> [String] {
        var query: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&query, UInt32(query.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size, size <= 1_048_576 else { return [] }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctl(&query, UInt32(query.count), &bytes, &size, nil, 0) == 0 else { return [] }
        let count = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard count > 0 else { return [] }
        var index = MemoryLayout<Int32>.size
        // Skip the executable path and padding before argv[0].
        while index < size && bytes[index] != 0 { index += 1 }
        while index < size && bytes[index] == 0 { index += 1 }
        var result: [String] = []
        for _ in 0..<min(Int(count), 16) {
            guard index < size else { break }
            let start = index
            while index < size && bytes[index] != 0 { index += 1 }
            guard let argument = String(bytes: bytes[start..<index], encoding: .utf8) else { return [] }
            result.append(argument)
            index += 1
        }
        // Stop at argc. Environment variables are not decoded or retained.
        return result
    }
}

struct QuickStartProgramIcon: View {
    let program: QuickStartProgram
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let icon = Self.icons[program] {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "terminal")
                    .resizable()
                    .scaledToFit()
                    .padding(2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(program.title)
    }

    /// Cache the native app icons once instead of loading them on each refresh.
    private static let icons: [QuickStartProgram: NSImage] = {
        var result: [QuickStartProgram: NSImage] = [:]
        for program in [QuickStartProgram.claude, .cursor, .codex] {
            if let identifier = program.bundleIdentifier,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                result[program] = NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return result
    }()
}

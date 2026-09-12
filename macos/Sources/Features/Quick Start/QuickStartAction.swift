import Foundation

enum QuickStartAction: String, Codable, CaseIterable, Identifiable {
    case shell, claude, codex, cursor, custom

    var id: Self { self }

    var title: String {
        switch self {
        case .shell: return "Shell only"
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor CLI"
        case .custom: return "Custom command"
        }
    }
}

struct QuickStartOptions: Codable, Equatable {
    var action: QuickStartAction = .shell
    var customCommand: String = ""

    var command: String? {
        switch action {
        case .shell: return nil
        case .claude: return "claude"
        case .codex: return "codex"
        case .cursor: return "agent"
        case .custom: return customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var isValid: Bool {
        guard action == .custom else { return true }
        guard let command, !command.isEmpty else { return false }
        // One input line prevents accidental submission of extra terminal lines.
        return !command.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}

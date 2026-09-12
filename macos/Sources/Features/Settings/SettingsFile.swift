import Foundation

/// The settings window owns this file. The user's normal Ghostty files stay intact.
struct SettingsFile {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.markweisberg.ghostty.quickstart", isDirectory: true)
            .appendingPathComponent("settings.ghostty")
    }

    static let appearanceKeys: Set<String> = [
        "theme", "font-family", "font-size", "background-opacity", "window-padding-x", "window-padding-y"
    ]
    static let allowedKeys = appearanceKeys.union(["auto-update"])
    let url: URL

    func read() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try Self.parse(String(contentsOf: url, encoding: .utf8))
    }

    static func parse(_ text: String) throws -> [String: String] {
        var values: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let separator = line.firstIndex(of: "=") else { throw FileError.unsupportedContent }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard allowedKeys.contains(key) else { throw FileError.unsupportedContent }
            values[key] = value
        }
        return values
    }

    static func text(for values: [String: String]) throws -> String {
        var lines = ["# Managed by Ghostty Quick Start Settings.",
                     "# These choices override the normal Ghostty config for this fork only."]
        for key in values.keys.sorted() {
            guard allowedKeys.contains(key), let value = values[key],
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw FileError.unsupportedContent
            }
            // Font families accumulate in Ghostty. Clear the inherited list first.
            if key == "font-family" { lines.append("font-family =") }
            lines.append("\(key) = \(value)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func write(_ values: [String: String]) throws {
        let text = try Self.text(for: values)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    enum FileError: LocalizedError {
        case unsupportedContent
        var errorDescription: String? {
            "The saved settings contain text this window cannot edit. Open the settings file in Advanced to review it."
        }
    }
}

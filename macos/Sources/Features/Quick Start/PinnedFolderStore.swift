import Foundation
import Combine

/// Pins are shared by all terminal windows and saved separately from terminal state.
@MainActor
final class PinnedFolderStore: ObservableObject {
    static let shared = PinnedFolderStore()
    static let storageKey = "quickStart.pinnedFolders.v1"
    private static let optionsKey = "quickStart.folderOptions.v1"

    @Published private(set) var folders: [URL]
    @Published private(set) var folderOptions: [String: QuickStartOptions]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        folderOptions = defaults.data(forKey: Self.optionsKey)
            .flatMap { try? JSONDecoder().decode([String: QuickStartOptions].self, from: $0) } ?? [:]
        var seen = Set<String>()
        folders = (defaults.stringArray(forKey: Self.storageKey) ?? []).compactMap { path in
            guard path.hasPrefix("/") else { return nil }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            return seen.insert(url.path).inserted ? url : nil
        }
    }

    func pin(_ url: URL) throws {
        try Self.validate(url)
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        guard !folders.contains(canonical) else { return }
        folders.append(canonical)
        save()
    }

    func remove(_ url: URL) {
        folders.removeAll { $0 == url }
        folderOptions.removeValue(forKey: url.path)
        save()
    }

    func options(for folder: URL) -> QuickStartOptions {
        folderOptions[folder.path] ?? QuickStartOptions()
    }

    func setOptions(_ options: QuickStartOptions, for folder: URL) throws {
        guard options.isValid else { throw FolderError.invalidCommand }
        folderOptions[folder.path] = options
        save()
    }

    static func validate(_ url: URL) throws {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey]),
              values.isDirectory == true,
              values.isReadable == true else {
            throw FolderError.unavailable(url.path)
        }
    }

    private func save() {
        defaults.set(folders.map(\.path), forKey: Self.storageKey)
        if let data = try? JSONEncoder().encode(folderOptions) {
            defaults.set(data, forKey: Self.optionsKey)
        }
    }

    enum FolderError: LocalizedError {
        case unavailable(String)
        case invalidCommand

        var errorDescription: String? {
            switch self {
            case .unavailable(let path):
                return "Cannot open this folder: \(path)\nCheck that the folder exists and that you can read it."
            case .invalidCommand:
                return "Enter a command on one line."
            }
        }
    }
}

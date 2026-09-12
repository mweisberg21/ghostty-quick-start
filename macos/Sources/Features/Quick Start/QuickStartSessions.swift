import AppKit
import Combine

/// Observes actual terminal windows. Closing a tab removes its sidebar entry.
@MainActor
final class QuickStartSessions: ObservableObject {
    static let shared = QuickStartSessions()

    struct Session: Identifiable, Equatable {
        let id: ObjectIdentifier
        let title: String
        let folder: URL?
        let isSelected: Bool
        let program: QuickStartProgram
        let color: TerminalTabColor
        let groupID: ObjectIdentifier?
        let tabIndex: Int

        var displayTitle: String {
            guard program != .terminal, !title.localizedCaseInsensitiveContains(program.title) else { return title }
            return "\(program.title) · \(title)"
        }
    }

    private final class Observation {
        weak var controller: TerminalController?
        var subscriptions = Set<AnyCancellable>()

        init(_ controller: TerminalController) {
            self.controller = controller
        }
    }

    @Published private(set) var sessions: [Session] = []
    private var observations: [ObjectIdentifier: Observation] = [:]
    private var order: [ObjectIdentifier] = []
    private var processTimer: AnyCancellable?

    func register(_ controller: TerminalController) {
        let id = ObjectIdentifier(controller)
        guard observations[id] == nil, let window = controller.window else { return }
        let observation = Observation(controller)
        observations[id] = observation
        order.append(id)
        if processTimer == nil {
            processTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.refresh() }
        }
        window.publisher(for: \.title)
            .merge(with: window.publisher(for: \.representedURL).map { $0?.path ?? "" })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &observation.subscriptions)
        refresh()
    }

    func unregister(_ controller: TerminalController) {
        let id = ObjectIdentifier(controller)
        observations.removeValue(forKey: id)
        order.removeAll { $0 == id }
        if observations.isEmpty { processTimer = nil }
        refresh()
    }

    func refresh() {
        let updated = order.compactMap { id -> Session? in
            guard let controller = observations[id]?.controller, let window = controller.window else { return nil }
            return Session(
                id: id,
                title: window.title.isEmpty ? "Terminal" : window.title,
                folder: controller.quickStartFolder ?? window.representedURL,
                isSelected: window.tabGroup?.selectedWindow === window || window.isKeyWindow,
                program: QuickStartProgram.foreground(
                    pid: (controller.focusedSurface ?? controller.surfaceTree.first)?.surfaceModel?.foregroundPID),
                color: (window as? TerminalWindow)?.tabColor ?? .none,
                groupID: window.tabGroup.map(ObjectIdentifier.init),
                tabIndex: window.tabGroup?.windows.firstIndex(of: window) ?? 0)
        }
        if sessions != updated { sessions = updated }
    }

    func sessions(for folder: URL) -> [Session] {
        let path = folder.standardizedFileURL.resolvingSymlinksInPath().path
        return sessions.filter { $0.folder?.standardizedFileURL.resolvingSymlinksInPath().path == path }
    }

    func controller(for session: Session) -> TerminalController? {
        observations[session.id]?.controller
    }

    /// Match the native tab order and keep window-scoped actions unambiguous.
    func sessions(in controller: TerminalController) -> [Session] {
        guard let window = controller.window else { return [] }
        return (window.tabGroup?.windows ?? [window]).compactMap { window in
            guard let controller = window.windowController as? TerminalController else { return nil }
            return sessions.first { $0.id == ObjectIdentifier(controller) }
        }
    }

    func close(_ session: Session) {
        guard let controller = controller(for: session) else { return }
        // Bring any process confirmation sheet to the front.
        focus(session)
        controller.closeTab(nil)
    }

    func focus(_ session: Session) {
        guard let controller = observations[session.id]?.controller,
              let window = controller.window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.tabGroup?.selectedWindow = window
        window.makeKeyAndOrderFront(nil)
        if let surface = controller.focusedSurface ?? controller.surfaceTree.first {
            controller.focusSurface(surface)
        }
        refresh()
    }
}

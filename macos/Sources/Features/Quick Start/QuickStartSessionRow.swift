import AppKit
import SwiftUI

struct QuickStartSessionRow: View {
    let session: QuickStartSessions.Session
    let isCollapsed: Bool
    @ObservedObject private var sessions = QuickStartSessions.shared
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button { sessions.focus(session) } label: {
                HStack(spacing: 9) {
                    QuickStartProgramIcon(program: session.program)
                    if !isCollapsed {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.displayTitle)
                                .font(.system(size: 12, weight: session.isSelected ? .semibold : .regular))
                                .lineLimit(1)
                            if let folder = session.folder {
                                Text(folder.path)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch to \(session.displayTitle)")
            .accessibilityValue(session.isSelected ? "Selected" : "")
            if !isCollapsed {
                Button { sessions.close(session) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 26, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .opacity(isHovered ? 1 : 0)
                .accessibilityLabel("Close \(session.displayTitle)")
                .help("Close tab")
            }
        }
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(session.isSelected ? Color.accentColor.opacity(0.12) :
                    (isHovered ? Color.primary.opacity(0.05) : .clear)))
        .overlay(alignment: .leading) {
            if let color = session.color.displayColor {
                Capsule().fill(Color(nsColor: color)).frame(width: 3)
                    .padding(.vertical, 7)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if session.isSelected {
                Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                    .padding(4)
                    .accessibilityHidden(true)
            }
        }
        .onHover { isHovered = $0 }
        .help([session.displayTitle, session.folder?.path].compactMap { $0 }.joined(separator: "\n"))
        .contextMenu { tabMenu }
    }

    @ViewBuilder private var tabMenu: some View {
        if let controller = sessions.controller(for: session), let window = controller.window {
            let tabs = sessions.sessions(in: controller)
            Button("Close Tab") { sessions.close(session) }
            Button("Close Other Tabs") {
                sessions.focus(session)
                controller.closeOtherTabs(nil)
            }
            .disabled(tabs.count < 2)
            Button("Close Tabs Below") {
                sessions.focus(session)
                controller.closeTabsOnTheRight(nil)
            }
            .disabled(tabs.last?.id == session.id)
            Divider()
            Button("Move Tab to New Window") {
                sessions.focus(session)
                window.moveTabToNewWindow(nil)
                sessions.refresh()
            }
            .disabled(tabs.count < 2)
            Button("Show All Tabs") {
                sessions.focus(session)
                window.toggleTabOverview(nil)
            }
            Divider()
            Button("Rename Tab…") {
                sessions.focus(session)
                controller.promptTabTitle()
            }
            Menu("Tab Color") {
                ForEach(TerminalTabColor.allCases, id: \.self) { color in
                    Button {
                        (window as? TerminalWindow)?.tabColor = color
                        sessions.refresh()
                    } label: {
                        Label {
                            Text(color.localizedName)
                        } icon: {
                            Image(nsImage: color.swatchImage(selected: session.color == color))
                        }
                    }
                }
            }
        }
    }
}

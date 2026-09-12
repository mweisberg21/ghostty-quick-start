import AppKit
import Combine
import SwiftUI

/// Layout preferences shared by terminal windows and restored on launch.
@MainActor
final class QuickStartLayout: ObservableObject {
    static let shared = QuickStartLayout()
    static let defaultWidth: Double = 224
    static let collapsedWidth: Double = 52
    private let defaults: UserDefaults

    @Published var width: Double {
        didSet { defaults.set(Self.clamp(width), forKey: "quickStart.sidebarWidth") }
    }
    @Published var isCollapsed: Bool {
        didSet { defaults.set(isCollapsed, forKey: "quickStart.sidebarCollapsed") }
    }
    @Published var showsTopTabBar: Bool {
        didSet { defaults.set(showsTopTabBar, forKey: "quickStart.showsTopTabBar") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        width = Self.clamp(defaults.object(forKey: "quickStart.sidebarWidth") as? Double ?? Self.defaultWidth)
        isCollapsed = defaults.bool(forKey: "quickStart.sidebarCollapsed")
        showsTopTabBar = defaults.bool(forKey: "quickStart.showsTopTabBar")
    }

    static func clamp(_ width: Double) -> Double {
        width.isFinite ? min(440, max(200, width)) : defaultWidth
    }

    func visibleWidth(available: Double) -> Double {
        isCollapsed ? Self.collapsedWidth : min(Self.clamp(width), max(100, available * 0.45))
    }
}

struct QuickStartResizeHandle: View {
    @ObservedObject private var layout = QuickStartLayout.shared
    @State private var startingWidth: Double?
    let visibleWidth: Double

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .overlay(Divider())
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
            }
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if startingWidth == nil { startingWidth = visibleWidth }
                    layout.width = QuickStartLayout.clamp((startingWidth ?? visibleWidth) + value.translation.width)
                }
                .onEnded { _ in startingWidth = nil })
            .onTapGesture(count: 2) { layout.width = QuickStartLayout.defaultWidth }
            .accessibilityLabel("Sidebar width")
            .accessibilityValue("\(Int(visibleWidth)) points")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: layout.width = QuickStartLayout.clamp(layout.width + 20)
                case .decrement: layout.width = QuickStartLayout.clamp(layout.width - 20)
                @unknown default: break
                }
            }
            .help("Drag to resize the sidebar. Double-click to reset its width.")
    }
}

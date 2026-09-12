import Foundation
import Testing
@testable import Ghostty

@MainActor
struct QuickStartLayoutTests {
    @Test func layoutRestoresWidthAndVisibility() throws {
        let name = "QuickStartLayoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let layout = QuickStartLayout(defaults: defaults)
        #expect(layout.showsTopTabBar)
        layout.width = 318
        layout.isCollapsed = true
        layout.showsTopTabBar = false
        let restored = QuickStartLayout(defaults: defaults)
        #expect(restored.width == 318)
        #expect(restored.isCollapsed)
        #expect(!restored.showsTopTabBar)
        #expect(restored.visibleWidth(available: 1000) == 52)
        restored.isCollapsed = false
        #expect(restored.visibleWidth(available: 1000) == 318)
    }

    @Test func narrowWindowPreservesTerminalSpaceWithoutLosingPreferredWidth() throws {
        let name = "QuickStartLayoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let layout = QuickStartLayout(defaults: defaults)
        layout.width = 400
        #expect(layout.visibleWidth(available: 500) == 225)
        #expect(layout.width == 400)
        #expect(layout.visibleWidth(available: 1000) == 400)
    }

    @Test func invalidSavedWidthUsesSafeBounds() throws {
        let name = "QuickStartLayoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(-300, forKey: "quickStart.sidebarWidth")
        #expect(QuickStartLayout(defaults: defaults).width == 200)
        defaults.set(9000, forKey: "quickStart.sidebarWidth")
        #expect(QuickStartLayout(defaults: defaults).width == 440)
        #expect(QuickStartLayout.clamp(.nan) == 224)
    }
}

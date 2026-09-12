# Ghostty Quick Start

This local Ghostty fork adds a macOS sidebar for pinned project folders.

## Use

1. Click **Pin a Folder…** or the folder-plus button in the sidebar.
2. Select one or more folders.
3. Click a folder to open a shell in that folder. If a tab for that folder is already open, the click returns to that tab.
4. Use **Open Tabs** to switch between running tabs. The selected tab has a colored marker. Folder rows show the number of open tabs.
5. Click the **…** button beside a folder to configure its action: **Shell only**, **Claude**, **Codex**, **Cursor CLI**, or **Custom command**.
6. Right-click a folder and select **Open New Tab** to start another session with the saved action. You can also select **Show in Finder** or **Remove Pin**.

Pins are saved between app launches and shared across windows. Removing a pin does not remove the folder. Missing or unreadable folders show an error. The standard Quick Terminal remains compact.

Every new tab first changes to the selected folder. **Shell only** is the default, including for pins saved by the first version. Each folder has independent settings.

The CLI choices run `claude`, `codex`, or `agent` (Cursor CLI) through the normal shell, with their normal authentication and permission controls. The shell must be able to find the selected command on `PATH`. A custom command runs in the selected folder and must fit on one line. When the command exits, the terminal remains available.

Open tabs show the native Claude, Cursor, or Codex app icon for the foreground program. Icons update once per second, including when a command starts from the shell. The blue row highlight and dot mark the selected tab. If a matching desktop app is not installed, the row uses a terminal icon.

Selecting an existing tab brings back its current process and terminal content. Changing a folder action does not change a running session. To use the new action, select **Open New Tab**. Closed CLI sessions are not resumed automatically.

## Sidebar and tabs

Drag the sidebar's right edge to change its width. Double-click the edge to restore the default width. The app saves your chosen width. A narrow window limits the sidebar width to keep room for the terminal.

Click the sidebar button beside **Quick Start** to collapse the sidebar to icons. Click it again to expand it. Hover over an icon to see the tab name and folder. The **View** menu also has **Collapse Sidebar** and **Expand Sidebar**.

The top tab bar is visible by default. A saved choice from an earlier version is kept. Select **View → Show Top Tab Bar**, or use **Settings → Tabs & Sidebar**, to change it. This setting is saved between launches. Existing tab keyboard shortcuts still work.

The **+** button in **Open Tabs** creates a tab. Hover over a tab row to show its close button. Right-click a tab for **Close Tab**, **Close Other Tabs**, **Close Tabs Below**, **Move Tab to New Window**, **Show All Tabs**, **Rename Tab…**, and **Tab Color**. The sidebar uses the same tab color as the top bar. Normal warnings for running processes still apply.

Each window's sidebar lists that window's tabs in their native order. Folder pins can still return to a matching session in another window.

## Settings

Open **Ghostty → Settings…** or press **⌘,**. Settings opens in its own window and keeps your terminal tabs in place.

- **Tabs & Sidebar:** show the top tab bar, collapse the sidebar, change its width, or reset the layout.
- **Appearance:** search bundled themes, choose an installed font, change text size and opacity, or set horizontal and vertical padding. The sample shows the current terminal colors. Changes apply when selected. Opacity can require a new window; a tab with manual zoom can keep its text size.
- **Projects:** add and remove pins or configure the launch action for each folder. These are the same pins and actions shown in the sidebar. Changes apply to new tabs.
- **Updates:** control automatic checks and downloads, check now, and see update status and the last check time. Local source builds show these controls as unavailable. Signed releases use this fork's existing update feed.
- **Advanced:** open the normal Ghostty config file, reload configuration, locate the Settings file, and read configuration errors.

Appearance and update choices are saved in `~/Library/Application Support/com.markweisberg.ghostty.quickstart/settings.ghostty`. The app loads these choices after the normal configuration. It validates changes before saving and does not rewrite the shared Ghostty config. **Use Config File** removes a Settings choice so the file value takes effect again. **Use Config File for All Appearance Settings** removes only the appearance choices; update preferences and project pins stay intact.

## Build and run

Requirements: Xcode, Zig 0.16.0, Nushell, and SwiftLint. The first build downloads Ghostty's dependencies.

```sh
./script/build_and_run.sh
```

The Codex **Run** action uses this script. To build without opening the app:

```sh
./script/build_and_run.sh --build-only
```

The app is at `macos/build/ReleaseLocal/Ghostty.app`. Its display name is **Ghostty Quick Start**. Its bundle ID is `com.markweisberg.ghostty.quickstart`, so its pins and macOS preferences are separate from the installed upstream app. Ghostty's normal terminal configuration files still apply. Upstream automatic updates are disabled for this source build.

To run the macOS unit tests after building the core:

```sh
macos/build.nu --native --action test --only-testing GhosttyTests/QuickStartTests
```

## Source

Upstream: https://github.com/ghostty-org/ghostty

Base commit: `44f2a44df7e8c4a0c6df3f7d872ef3d7ead88e51` (`1.3.2-dev`).

Branch: `quick-start`. The original source remote is `upstream`; the public fork remote is `origin` at https://github.com/mweisberg21/ghostty-quick-start. See [RELEASING.md](RELEASING.md) for signed downloads and app updates.

The upstream MIT license and copyright notice remain in `LICENSE`.

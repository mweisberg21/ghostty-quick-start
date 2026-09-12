# Ghostty Quick Start

An unofficial macOS fork of [Ghostty](https://github.com/ghostty-org/ghostty) with a sidebar for project folders and running CLI sessions.

[Download the latest release](https://github.com/mweisberg21/ghostty-quick-start/releases/latest) · [How to use it](QUICK_START.md) · [Release and update guide](RELEASING.md)

## Features

- Pin folders and open a shell in one click.
- Choose Claude, Codex, Cursor CLI, or a custom command for each folder.
- Select an open tab to return to the same running session.
- See native app icons for supported foreground programs.
- Receive signed app updates from this repository.

## Install

Download the release ZIP, open it, and drag **Ghostty Quick Start.app** to **Applications**. The app supports macOS 13 and later on Apple silicon and Intel Macs. Distributed releases are signed with Developer ID and notarized by Apple.

Install and sign in to your preferred CLI separately. Folder pins and launch settings are stored locally on each Mac. Terminal configuration follows Ghostty's normal configuration files. This fork uses its own app ID and update feed.

**Check for Updates…** installs releases of this fork. New upstream Ghostty code is integrated and tested before it becomes a release here. A source commit alone does not trigger an app update.

## Development

Use `./script/build_and_run.sh` to build and run locally. See [RELEASING.md](RELEASING.md) for signed distribution. The current Ghostty source baseline is recorded in [release/upstream.json](release/upstream.json).

The upstream GitHub Actions workflows are disabled in this fork. Release signing runs on the maintainer's Mac; private signing keys are not stored in GitHub.

## License and attribution

Ghostty is created by Mitchell Hashimoto and the Ghostty contributors. This project retains the [MIT license](LICENSE) and copyright notice. It is not an official Ghostty release and is not affiliated with Anthropic, Cursor, or OpenAI. App icons are read from apps installed on the user's Mac.

The original Ghostty README is preserved in [README.upstream.md](README.upstream.md).

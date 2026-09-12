# Signed releases and updates

## Distribution

Public repository: https://github.com/mweisberg21/ghostty-quick-start

App ID: `com.markweisberg.ghostty.quickstart`

Update feed: https://github.com/mweisberg21/ghostty-quick-start/releases/latest/download/appcast.xml

Releases use Developer ID signing, hardened runtime, Apple notarization, and Sparkle EdDSA signatures. The main app uses the upstream distribution entitlements, without development debugging entitlements. The app and update archive retain the original Ghostty license.

The Sparkle private key is stored in the macOS Keychain under account `ghostty-quick-start`. Keep a secure backup before replacing the signing Mac. Never commit or publish the private key. The matching public key is in `macos/Ghostty-Info.plist`.

## Prepare a release

Requirements: Xcode, Zig 0.16.0, Nushell, a Developer ID Application certificate with its private key, an authenticated `asc` profile with Notary API access, an authenticated `gh` account, and the Sparkle Keychain key.

1. Run the relevant unit tests, build the app, and check the UI.
2. Add `release/release-notes-VERSION.md`.
3. Commit and push to the fork's `quick-start` branch.
4. Use a new version and an increasing integer build number:

```sh
./script/release.py prepare 0.1.1 --build 2
./script/release.py notarize 0.1.1
```

The prepare step builds both CPU architectures, stages the app under `dist/VERSION`, signs nested code and the app, verifies the signature, and creates a ZIP. It does not close running apps or install anything. Set `GHOSTTY_SIGNING_IDENTITY` if the Mac has more than one Developer ID identity.

The notarize step submits the ZIP through `asc` using its existing Keychain credentials. It saves the submission result in `dist/VERSION/notarization.json` so the same submission can be checked without uploading again.

Check the returned submission ID:

```sh
asc notarization status --id SUBMISSION_ID
```

When Apple reports `Accepted`:

```sh
./script/release.py finalize 0.1.1
./script/release.py publish 0.1.1
```

Finalize staples Apple's ticket, checks Gatekeeper, recreates the ZIP with the ticket, and creates and verifies a signed Sparkle appcast. Publish checks the finalized archive hash and creates a GitHub release with the ZIP, appcast, checksum, and source manifest.

Only a published release becomes an app update. Development builds keep updates disabled. Installed releases check this fork's feed; they never use the official Ghostty feed. Users can select **Check for Updates…** to check immediately. Automatic installation remains a user preference.

## Bring in a new Ghostty release

Track stable version tags in `ghostty-org/ghostty`. Ghostty's current stable source tag is `v1.3.1`; this fork began at a later `1.3.2-dev` source commit. Do not replace the current source with an older stable tag.

For the initial shallow checkout, fetch the full history once:

```sh
git fetch --unshallow upstream
```

Then, for a future tag:

```sh
git fetch upstream --tags
git switch -c integrate/UPSTREAM_VERSION quick-start
git merge UPSTREAM_VERSION
```

Resolve conflicts in the macOS sidebar, terminal controller, and update files. Keep this fork's bundle ID, Sparkle public key, and feed. Update `release/upstream.json` after review. Rebuild the Zig library if core code changed. Run the relevant tests and check pin persistence, CLI launch, tab switching, icons, and signed app launch. Merge the tested integration into `quick-start`, then publish a new fork version with the release commands above.

Do not automatically publish untested upstream code. The scheduled Codex monitor reports new stable tags for review. It does not merge or install them.

## Other Macs

Copy the notarized ZIP with AirDrop or download it from GitHub. Move the app into Applications. Install the desired CLI tools and sign in on each Mac. Pins are local; they do not sync. A configured folder must exist on that Mac.

The universal binary includes Intel support. Testing on Apple silicon does not prove operation on an Intel Mac; check an Intel Mac before claiming hardware validation there.

#!/usr/bin/env python3
"""Build, sign, notarize, and publish a Ghostty Quick Start release."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = 'mweisberg21/ghostty-quick-start'
ACCOUNT = 'ghostty-quick-start'
BUNDLE_ID = 'com.markweisberg.ghostty.quickstart'
FEED = f'https://github.com/{REPOSITORY}/releases/latest/download/appcast.xml'


def run(*args, capture=False):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True,
                            text=True, stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None


def sparkle_tool(name):
    override = os.environ.get('SPARKLE_BIN')
    if override:
        result = Path(override) / name
        if result.is_file():
            return result
    candidates = list((Path.home() / 'Library/Developer/Xcode/DerivedData').glob(
        f'Ghostty-*/SourcePackages/artifacts/sparkle/Sparkle/bin/{name}'))
    if not candidates:
        raise RuntimeError('Build the macOS app first, or set SPARKLE_BIN to the Sparkle bin folder.')
    return max(candidates, key=lambda path: path.stat().st_mtime)


def signing_identity():
    if os.environ.get('GHOSTTY_SIGNING_IDENTITY'):
        return os.environ['GHOSTTY_SIGNING_IDENTITY']
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning', capture=True)
    matches = re.findall(r'"(Developer ID Application: [^"]+)"', identities)
    if len(matches) != 1:
        raise RuntimeError('Set GHOSTTY_SIGNING_IDENTITY to the Developer ID Application identity to use.')
    return matches[0]


def prepare(args, directory, app, archive):
    if directory.exists():
        raise RuntimeError(f'{directory} already exists. Use a new version or inspect the existing release.')
    if run('git', 'status', '--porcelain', capture=True):
        raise RuntimeError('Commit the source changes before preparing a public release.')
    identity = signing_identity()
    run('zig', 'build', '-Doptimize=ReleaseFast', '-Demit-macos-app=false', '-Dxcframework-target=universal')
    run('macos/build.nu', '--configuration', 'Release')
    directory.mkdir(parents=True)
    run('ditto', ROOT / 'macos/build/Release/Ghostty.app', app)
    info_path = app / 'Contents/Info.plist'
    with info_path.open('rb') as handle:
        info = plistlib.load(handle)
    info.update(CFBundleIdentifier=BUNDLE_ID, CFBundleName='Ghostty Quick Start',
                CFBundleDisplayName='Ghostty Quick Start', CFBundleShortVersionString=args.version,
                CFBundleVersion=str(args.build), QuickStartSourceBuild=False,
                SUEnableAutomaticChecks=True, SUAutomaticallyUpdate=False, SUFeedURL=FEED)
    public_key = run(sparkle_tool('generate_keys'), '--account', ACCOUNT, '-p', capture=True)
    if info['SUPublicEDKey'] != public_key:
        raise RuntimeError('The release public key does not match the Keychain signing key.')
    with info_path.open('wb') as handle:
        plistlib.dump(info, handle)
    shutil.copy2(ROOT / 'LICENSE', app / 'Contents/Resources/LICENSE-Ghostty.txt')
    # Sign nested code from the inside out, as in Ghostty's release workflow.
    framework = app / 'Contents/Frameworks/Sparkle.framework'
    targets = [framework / 'Versions/B/XPCServices/Downloader.xpc',
               framework / 'Versions/B/XPCServices/Installer.xpc',
               framework / 'Versions/B/Autoupdate', framework / 'Versions/B/Updater.app',
               framework, app / 'Contents/PlugIns/DockTilePlugin.plugin']
    for target in targets:
        run('codesign', '--force', '--timestamp', '--options', 'runtime', '--sign', identity, target)
    run('codesign', '--force', '--timestamp', '--options', 'runtime', '--sign', identity,
        '--entitlements', ROOT / 'macos/Ghostty.entitlements', app)
    run('codesign', '--verify', '--deep', '--strict', '--verbose=2', app)
    architectures = run('lipo', '-archs', app / 'Contents/MacOS/ghostty', capture=True).split()
    if not {'arm64', 'x86_64'}.issubset(architectures):
        raise RuntimeError(f'The release must include Apple silicon and Intel code: {architectures}')
    run('ditto', '-c', '-k', '--keepParent', '--sequesterRsrc', app, archive)
    manifest = dict(version=args.version, build=args.build, sourceCommit=run('git', 'rev-parse', 'HEAD', capture=True),
                    upstream=json.loads((ROOT / 'release/upstream.json').read_text()), notarized=False)
    (directory / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Signed release prepared: {archive}')


def notarize(args, directory, app, archive):
    manifest_path = directory / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    submission_path = directory / 'notarization.json'
    if submission_path.exists():
        submission = json.loads(submission_path.read_text())
    else:
        response = json.loads(run('asc', 'notarization', 'submit', '--file', archive, capture=True))
        data = response.get('data', response)
        submission = {'id': data.get('id', response.get('id')),
                      'status': data.get('attributes', data).get('status', 'Submitted')}
        if not submission['id']:
            raise RuntimeError('Apple returned no submission ID. Check asc notarization list before retrying.')
        submission_path.write_text(json.dumps(submission, indent=2) + '\n')
    print(json.dumps(submission))
    print('Use asc notarization status --id <submission ID> to check Apple approval, then run finalize.')


def finalize(args, directory, app, archive):
    # Stapling only succeeds for an app with an accepted notarization ticket.
    run('xcrun', 'stapler', 'staple', app)
    run('xcrun', 'stapler', 'validate', app)
    run('codesign', '--verify', '--deep', '--strict', '--verbose=2', app)
    run('spctl', '--assess', '--type', 'execute', '--verbose=2', app)
    archive.unlink()
    run('ditto', '-c', '-k', '--keepParent', '--sequesterRsrc', app, archive)
    shutil.copy2(ROOT / f'release/release-notes-{args.version}.md', directory / f'{archive.stem}.md')
    run(sparkle_tool('generate_appcast'), '--account', ACCOUNT, '--maximum-deltas', '0',
        '--embed-release-notes', '--download-url-prefix',
        f'https://github.com/{REPOSITORY}/releases/download/v{args.version}/', directory)
    enclosure = ET.parse(directory / 'appcast.xml').find('./channel/item/enclosure')
    signature = enclosure.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature']
    run(sparkle_tool('sign_update'), '--account', ACCOUNT, '--verify', archive, signature)
    manifest_path = directory / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest.update(notarized=True, sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    (directory / 'SHA256SUMS.txt').write_text(f"{manifest['sha256']}  {archive.name}\n")
    print(f'Notarized release and signed update feed are ready in {directory}')


def publish(args, directory, app, archive):
    manifest = json.loads((directory / 'manifest.json').read_text())
    if not manifest['notarized'] or hashlib.sha256(archive.read_bytes()).hexdigest() != manifest['sha256']:
        raise RuntimeError('Finalize the release before publishing. The signed archive must not change.')
    run('xcrun', 'stapler', 'validate', app)
    run('gh', 'release', 'create', f'v{args.version}', '--repo', REPOSITORY,
        '--target', manifest['sourceCommit'], '--title', f'Ghostty Quick Start {args.version}',
        '--notes-file', ROOT / f'release/release-notes-{args.version}.md', '--latest',
        archive, directory / 'appcast.xml', directory / 'SHA256SUMS.txt', directory / 'manifest.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('step', choices=['prepare', 'notarize', 'finalize', 'publish'])
    parser.add_argument('version', help='Public app version, for example 0.1.0')
    parser.add_argument('--build', type=int, default=1, help='Increasing integer used by Sparkle')
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version) or args.build < 1:
        parser.error('Use a three-part version and a positive build number.')
    directory = ROOT / 'dist' / args.version
    app = directory / 'Ghostty Quick Start.app'
    archive = directory / f'Ghostty-Quick-Start-{args.version}.zip'
    globals()[args.step](args, directory, app, archive)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))

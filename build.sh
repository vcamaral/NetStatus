#!/bin/bash
# Usage: ./build.sh          -> builds build/NetStatus.app
#        ./build.sh install  -> builds, installs to ~/Applications and launches
#        ./build.sh release  -> builds build/NetStatus.app for distribution (scripts/make-dmg.sh), not tied to this clone
set -euo pipefail
cd "$(dirname "$0")"

./scripts/setup-signing.sh >/dev/null
swift build -c release

APP="build/NetStatus.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/NetStatus "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
# Lets the app update itself from this clone (git pull + rebuild). Release builds check GitHub Releases instead.
if [[ "${1:-}" != "release" ]]; then
    /usr/libexec/PlistBuddy -c "Add :NetStatusSourceDir string $PWD" "$APP/Contents/Info.plist"
fi
# The commit, shown in the popover.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-parse --short HEAD 2>/dev/null || echo dev)" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Sign with the stable local certificate so permissions survive rebuilds.
if security find-identity -p codesigning | grep -q "NetStatus Local Signing"; then
    codesign --force --sign "NetStatus Local Signing" "$APP"
else
    echo "Warning: 'NetStatus Local Signing' certificate not found, using ad-hoc signing."
    codesign --force --sign - "$APP"
fi
echo "OK: $APP"

if [[ "${1:-}" == "install" ]]; then
    # -a: also when the running app is the one calling this (self-update): pkill and pgrep skip their
    # own ancestors by default, so the app would never be quit.
    pkill -a -x NetStatus || true
    while pgrep -a -x NetStatus >/dev/null; do sleep 0.2; done
    mkdir -p ~/Applications
    rm -rf ~/Applications/NetStatus.app
    cp -R "$APP" ~/Applications/
    # LaunchServices sometimes refuses to open a bundle it hasn't registered yet (error -600): retry.
    for _ in 1 2 3 4 5; do open ~/Applications/NetStatus.app 2>/dev/null && break; sleep 1; done
    echo "Installed to ~/Applications/NetStatus.app"
fi

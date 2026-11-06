#!/bin/bash
# Installs NetStatus on this Mac, from this clone: ./install.sh
# Afterwards NetStatus keeps itself up to date from this clone's git remote.
set -euo pipefail
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
    echo "Apple's Command Line Tools are required. Opening the installer…"
    xcode-select --install || true
    echo "When the installation finishes, run ./install.sh again."
    exit 1
fi

./build.sh install

echo
echo "Done! NetStatus is in your menu bar."
echo "It updates itself from this folder's git remote, so keep this folder where it is."

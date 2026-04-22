#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUNDLE_DIR="build/Pitwall.app"
EXECUTABLE="${BUNDLE_DIR}/Contents/MacOS/PitwallApp"
INFO_PLIST="${BUNDLE_DIR}/Contents/Info.plist"

echo "==> smoke-install: building app bundle"
bash scripts/build-app-bundle.sh

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "error: executable not found or not executable at ${EXECUTABLE}" >&2
    exit 1
fi

INFO_PLIST_ABS="${REPO_ROOT}/${INFO_PLIST}"
SHORT_VERSION="$(defaults read "${INFO_PLIST_ABS%.plist}" CFBundleShortVersionString)"
if [[ ! "$SHORT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: CFBundleShortVersionString '${SHORT_VERSION}' does not match ^[0-9]+\.[0-9]+\.[0-9]+$" >&2
    exit 1
fi

BUILD_NUMBER="$(defaults read "${INFO_PLIST_ABS%.plist}" CFBundleVersion)"
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "error: CFBundleVersion '${BUILD_NUMBER}' does not match ^[0-9]+$" >&2
    exit 1
fi

echo "==> smoke-install: verifying codesign"
codesign --verify --verbose "$BUNDLE_DIR"

echo "smoke-install: OK"

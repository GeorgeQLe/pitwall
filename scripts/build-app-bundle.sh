#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Pitwall"
EXECUTABLE="PitwallApp"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_TEMPLATE="Sources/PitwallApp/Info.plist"
INFO_PLIST_OUT="${CONTENTS_DIR}/Info.plist"
VERSION_FILE="VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "error: VERSION file not found at ${VERSION_FILE}" >&2
    exit 1
fi

if [[ ! -f "$INFO_PLIST_TEMPLATE" ]]; then
    echo "error: Info.plist template not found at ${INFO_PLIST_TEMPLATE}" >&2
    exit 1
fi

SHORT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ -z "$SHORT_VERSION" ]]; then
    echo "error: VERSION file is empty" >&2
    exit 1
fi

BUILD_NUMBER="$(git rev-list --count HEAD)"
if [[ -z "$BUILD_NUMBER" ]]; then
    echo "error: git rev-list --count HEAD produced empty output" >&2
    exit 1
fi

echo "==> Building ${EXECUTABLE} (release)"
swift build --configuration release --product "$EXECUTABLE"

BUILT_BINARY="$(swift build --configuration release --product "$EXECUTABLE" --show-bin-path)/${EXECUTABLE}"
if [[ ! -f "$BUILT_BINARY" ]]; then
    echo "error: built binary not found at ${BUILT_BINARY}" >&2
    exit 1
fi

echo "==> Assembling ${BUNDLE_DIR}"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILT_BINARY" "${MACOS_DIR}/${EXECUTABLE}"
chmod +x "${MACOS_DIR}/${EXECUTABLE}"

echo "==> Expanding Info.plist (shortVersion=${SHORT_VERSION}, build=${BUILD_NUMBER})"
sed \
    -e "s|{{CFBundleShortVersionString}}|${SHORT_VERSION}|g" \
    -e "s|{{CFBundleVersion}}|${BUILD_NUMBER}|g" \
    "$INFO_PLIST_TEMPLATE" > "$INFO_PLIST_OUT"

if grep -q "{{CFBundle" "$INFO_PLIST_OUT"; then
    echo "error: unsubstituted placeholders remain in ${INFO_PLIST_OUT}" >&2
    exit 1
fi

echo "==> Ad-hoc signing ${BUNDLE_DIR}"
codesign --sign - --deep --force --options=runtime "$BUNDLE_DIR"

echo "==> Done: ${BUNDLE_DIR}"

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Pitwall"
EXECUTABLE="PitwallApp"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_TEMPLATE="Sources/PitwallApp/Info.plist"
INFO_PLIST_OUT="${CONTENTS_DIR}/Info.plist"
VERSION_FILE="VERSION"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-}"
SU_FEED_URL="${SU_FEED_URL:-}"
SU_PUBLIC_ED_KEY="${SU_PUBLIC_ED_KEY:-}"

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
BUILD_BIN_DIR="$(dirname "$BUILT_BINARY")"
SPARKLE_FRAMEWORK="${BUILD_BIN_DIR}/Sparkle.framework"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "error: Sparkle.framework not found at ${SPARKLE_FRAMEWORK}" >&2
    exit 1
fi

echo "==> Assembling ${BUNDLE_DIR}"
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"

cp "$BUILT_BINARY" "${MACOS_DIR}/${EXECUTABLE}"
chmod +x "${MACOS_DIR}/${EXECUTABLE}"
cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"
if ! otool -l "${MACOS_DIR}/${EXECUTABLE}" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${EXECUTABLE}"
fi

echo "==> Expanding Info.plist (shortVersion=${SHORT_VERSION}, build=${BUILD_NUMBER})"
sed \
    -e "s|{{CFBundleShortVersionString}}|${SHORT_VERSION}|g" \
    -e "s|{{CFBundleVersion}}|${BUILD_NUMBER}|g" \
    "$INFO_PLIST_TEMPLATE" > "$INFO_PLIST_OUT"

if grep -q "{{CFBundle" "$INFO_PLIST_OUT"; then
    echo "error: unsubstituted placeholders remain in ${INFO_PLIST_OUT}" >&2
    exit 1
fi

if [[ -n "$SU_FEED_URL" ]]; then
    sed -i '' "s|{{SUFeedURL}}|${SU_FEED_URL}|g" "$INFO_PLIST_OUT"
else
    sed -i '' '/SUFeedURL/{N;d;}' "$INFO_PLIST_OUT"
fi

if [[ -n "$SU_PUBLIC_ED_KEY" ]]; then
    sed -i '' "s|{{SUPublicEDKey}}|${SU_PUBLIC_ED_KEY}|g" "$INFO_PLIST_OUT"
else
    sed -i '' '/SUPublicEDKey/{N;d;}' "$INFO_PLIST_OUT"
fi

echo "==> Signing ${BUNDLE_DIR} (identity=${SIGNING_IDENTITY})"
CODESIGN_ARGS=(--sign "$SIGNING_IDENTITY" --deep --force)
FRAMEWORK_CODESIGN_ARGS=(--sign "$SIGNING_IDENTITY" --force)
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    CODESIGN_ARGS+=(--options=runtime --timestamp)
    FRAMEWORK_CODESIGN_ARGS+=(--options=runtime --timestamp)
fi
if [[ -n "$ENTITLEMENTS_PATH" ]]; then
    CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS_PATH")
fi
codesign "${FRAMEWORK_CODESIGN_ARGS[@]}" "${FRAMEWORKS_DIR}/Sparkle.framework"
codesign "${CODESIGN_ARGS[@]}" "$BUNDLE_DIR"

echo "==> Done: ${BUNDLE_DIR}"

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Pitwall"
APP_BUNDLE="build/${APP_NAME}.app"
VERSION="${VERSION:-}"
DRY_RUN=0
CONFIG_FILE="${RELEASE_CONFIG_FILE:-.release-config}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-Sources/PitwallApp/Pitwall.entitlements}"
NOTARY_PROFILE="${NOTARY_PROFILE:-pitwall-notary}"
SIGN_UPDATE_TOOL="${SIGN_UPDATE_TOOL:-./bin/sign_update}"
APPCAST_PATH="${APPCAST_PATH:-appcast.xml}"
APPCAST_PUBLISH_COMMAND="${APPCAST_PUBLISH_COMMAND:-}"
RELEASE_NOTES_FILE="build/release-notes.md"

usage() {
    cat <<USAGE
Usage: VERSION=x.y.z bash scripts/release.sh [--dry-run]
       bash scripts/release.sh x.y.z [--dry-run]

Environment:
  SU_FEED_URL                 Sparkle appcast URL.
  SU_PUBLIC_ED_KEY            Sparkle public EdDSA key.
  SIGNING_IDENTITY            codesign identity, defaults to "Developer ID Application".
  NOTARY_PROFILE              notarytool keychain profile, defaults to "pitwall-notary".
  SIGN_UPDATE_TOOL            Sparkle sign_update path, defaults to "./bin/sign_update".
  APPCAST_PUBLISH_COMMAND     Optional command run after appcast.xml is updated.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
                shift
            else
                echo "error: unexpected argument: $1" >&2
                usage >&2
                exit 2
            fi
            ;;
    esac
done

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

DMG_PATH="build/${APP_NAME}-${VERSION}.dmg"
RELEASE_TAG="v${VERSION}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: required command not found: $1" >&2
        exit 1
    fi
}

require_file() {
    if [[ ! -f "$1" ]]; then
        echo "error: required file not found: $1" >&2
        exit 1
    fi
}

require_env() {
    if [[ -z "${!1:-}" ]]; then
        echo "error: required environment value missing: $1" >&2
        exit 1
    fi
}

validate_inputs() {
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
        echo "error: VERSION must be semver-like, got: ${VERSION:-<empty>}" >&2
        exit 1
    fi

    if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
        echo "error: working tree must be clean before release" >&2
        exit 1
    fi

    require_command git
    require_command swift
    require_command codesign
    require_command spctl
    require_command hdiutil
    if [[ "$DRY_RUN" != "1" ]]; then
        require_command xcrun
        require_command gh
    fi
    require_file "$ENTITLEMENTS_PATH"
    require_env SU_FEED_URL
    require_env SU_PUBLIC_ED_KEY
}

write_release_notes() {
    mkdir -p build
    local previous_tag
    previous_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"

    {
        echo "# ${APP_NAME} ${VERSION}"
        echo
        if [[ -n "$previous_tag" ]]; then
            git log --pretty=format:"- %s" "${previous_tag}..HEAD"
        else
            git log --pretty=format:"- %s"
        fi
        echo
    } > "$RELEASE_NOTES_FILE"
}

build_signed_app() {
    echo "==> Building signed app bundle"
    SIGNING_IDENTITY="$SIGNING_IDENTITY" \
        ENTITLEMENTS_PATH="$ENTITLEMENTS_PATH" \
        SU_FEED_URL="$SU_FEED_URL" \
        SU_PUBLIC_ED_KEY="$SU_PUBLIC_ED_KEY" \
        bash scripts/build-app-bundle.sh

    echo "==> Verifying app signature"
    codesign --verify --verbose --deep "$APP_BUNDLE"
    spctl --assess --type execute "$APP_BUNDLE"
}

create_dmg() {
    echo "==> Creating DMG ${DMG_PATH}"
    rm -f "$DMG_PATH"
    hdiutil create \
        -volname "${APP_NAME} ${VERSION}" \
        -srcfolder "$APP_BUNDLE" \
        -ov \
        -format UDZO \
        "$DMG_PATH"
}

notarize_and_staple() {
    echo "==> Notarizing DMG"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

    echo "==> Stapling DMG"
    xcrun stapler staple "$DMG_PATH"
}

sparkle_signature() {
    require_file "$SIGN_UPDATE_TOOL"

    local output
    output="$("$SIGN_UPDATE_TOOL" "$DMG_PATH")"
    echo "$output"
}

append_appcast_item() {
    local signature_output="$1"
    require_file "$APPCAST_PATH"

    local ed_signature length
    ed_signature="$(printf '%s\n' "$signature_output" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | tail -n 1)"
    length="$(printf '%s\n' "$signature_output" | sed -n 's/.*length="\([^"]*\)".*/\1/p' | tail -n 1)"

    if [[ -z "$ed_signature" || -z "$length" ]]; then
        echo "error: could not parse Sparkle signature output" >&2
        exit 1
    fi

    local escaped_url escaped_signature
    escaped_url="${RELEASE_DOWNLOAD_URL:-https://github.com/GeorgeQLe/pitwall/releases/download/${RELEASE_TAG}/${APP_NAME}-${VERSION}.dmg}"
    escaped_signature="$ed_signature"

    local item
    item="$(mktemp)"
    cat > "$item" <<ITEM
        <item>
            <title>${APP_NAME} ${VERSION}</title>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <description><![CDATA[
$(sed 's/^/                /' "$RELEASE_NOTES_FILE")
            ]]></description>
            <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S %z")</pubDate>
            <enclosure url="${escaped_url}" sparkle:edSignature="${escaped_signature}" length="${length}" type="application/octet-stream"/>
        </item>
ITEM

    if ! grep -q '</channel>' "$APPCAST_PATH"; then
        echo "error: ${APPCAST_PATH} does not contain </channel>" >&2
        rm -f "$item"
        exit 1
    fi

    local next_appcast
    next_appcast="$(mktemp)"
    awk -v item_path="$item" '
        /<\/channel>/ {
            while ((getline line < item_path) > 0) {
                print line
            }
            close(item_path)
        }
        { print }
    ' "$APPCAST_PATH" > "$next_appcast"
    mv "$next_appcast" "$APPCAST_PATH"
    rm -f "$item"
}

create_github_release() {
    echo "==> Creating GitHub release ${RELEASE_TAG}"
    gh release create "$RELEASE_TAG" "$DMG_PATH" --title "${APP_NAME} ${VERSION}" --notes-file "$RELEASE_NOTES_FILE"
}

publish_appcast() {
    if [[ -z "$APPCAST_PUBLISH_COMMAND" ]]; then
        echo "error: APPCAST_PUBLISH_COMMAND is not configured; appcast hosting is a manual prerequisite" >&2
        exit 1
    fi

    echo "==> Publishing appcast"
    bash -c "$APPCAST_PUBLISH_COMMAND"
}

validate_inputs
write_release_notes
build_signed_app
create_dmg

if [[ "$DRY_RUN" == "1" ]]; then
    echo "==> Dry run complete; skipped notarization, Sparkle signing, GitHub release, and appcast publish"
    exit 0
fi

notarize_and_staple
signature_output="$(sparkle_signature)"
append_appcast_item "$signature_output"
create_github_release
publish_appcast

echo "==> Release complete: ${RELEASE_TAG}"

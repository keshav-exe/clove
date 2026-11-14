#!/bin/bash
# Installs or updates Clove from its GitHub release.
#
#   curl -fsSL https://github.com/keshav-exe/clove/releases/latest/download/install.sh | bash
#
# Options, after `bash -s --`:
#   --version 3.0   install that release instead of the latest
#   --dir PATH      install into PATH instead of /Applications
#   --no-open       don't open Clove afterwards
#   --uninstall     remove Clove from Applications (your settings and groups stay)
#
# Before anything is copied into Applications it checks the download against the
# release's checksums, that it is signed by Clove's Developer ID team, and that Apple
# notarized it. Files fetched with curl skip the Gatekeeper check a browser download
# gets, so this is that check, done here.
set -euo pipefail

REPO="keshav-exe/clove"
TEAM_ID="2FFZB6R6U8"
BUNDLE_ID="com.kshvbgde.clove"
VERSION=""
DEST=""
OPEN=1
UNINSTALL=0

while [ $# -gt 0 ]; do
    case "$1" in
        --version) VERSION="${2:?--version needs a version, for example 3.0}"; shift 2 ;;
        --dir) DEST="${2:?--dir needs a folder}"; shift 2 ;;
        --no-open) OPEN=0; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

say() { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Clove is a Mac app."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 26 ] || fail "Clove needs macOS 26 or later. This Mac has $(sw_vers -productVersion)."

# /Applications when it can be written to, as it can for any admin account, else ~/Applications.
if [ -z "$DEST" ]; then
    if [ -w /Applications ]; then DEST="/Applications"; else DEST="$HOME/Applications"; fi
fi
APP="$DEST/Clove.app"

# Quits the running copy only when it is the one at the given path, so installing
# elsewhere leaves it alone.
quit_running() {
    local target="$1"
    if pgrep -f "^$target/Contents/MacOS/Clove" >/dev/null 2>&1; then
        osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "^$target/Contents/MacOS/Clove" >/dev/null 2>&1 || break; sleep 0.3; done
        pkill -f "^$target/Contents/MacOS/Clove" 2>/dev/null || true
    fi
}

if [ "$UNINSTALL" = 1 ]; then
    FOUND=""
    for candidate in /Applications/Clove.app "$HOME/Applications/Clove.app"; do
        [ -d "$candidate" ] && FOUND="$candidate"
    done
    [ -n "$FOUND" ] || fail "Clove isn't in /Applications or ~/Applications."
    quit_running "$FOUND"
    rm -rf "$FOUND"
    say "Removed $FOUND."
    echo "Settings and groups are kept in ~/Library/Preferences/$BUNDLE_ID.plist and ~/Library/Application Support/Clove. Delete them to remove them too."
    exit 0
fi

# The latest release's tag, from where GitHub's "latest" link points. No API, so no rate limit.
if [ -z "$VERSION" ]; then
    LATEST="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")"
    VERSION="${LATEST##*/}"
fi
VERSION="${VERSION#v}"
case "$VERSION" in
    ''|*[!0-9A-Za-z.-]*) fail "Couldn't work out which version to install." ;;
esac
BASE="https://github.com/$REPO/releases/download/v$VERSION"
DMG_NAME="Clove-$VERSION.dmg"

WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
    [ -n "$MOUNT" ] && hdiutil detach -quiet "$MOUNT" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

say "Downloading Clove $VERSION"
curl -fL --progress-bar -o "$WORK/$DMG_NAME" "$BASE/$DMG_NAME" || fail "Couldn't download Clove $VERSION."
curl -fsSL -o "$WORK/checksums.txt" "$BASE/checksums.txt" || fail "Couldn't download the checksums for $VERSION."

EXPECTED="$(awk -v name="$DMG_NAME" '$2 == name { print $1 }' "$WORK/checksums.txt")"
ACTUAL="$(shasum -a 256 "$WORK/$DMG_NAME" | awk '{ print $1 }')"
[ -n "$EXPECTED" ] || fail "The release has no checksum for $DMG_NAME."
[ "$EXPECTED" = "$ACTUAL" ] || fail "The download doesn't match the release's checksum. Nothing was installed."

# Mounted read-only and out of sight, never opened in Finder.
MOUNT="$WORK/mount"
mkdir -p "$MOUNT"
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$WORK/$DMG_NAME" || fail "Couldn't open $DMG_NAME."
NEW="$MOUNT/Clove.app"
[ -d "$NEW" ] || fail "The download doesn't contain Clove.app."

say "Checking the signature"
codesign --verify --deep --strict "$NEW" 2>/dev/null || fail "Clove's signature doesn't check out. Nothing was installed."
TEAM="$(codesign -dvv "$NEW" 2>&1 | awk -F= '/^TeamIdentifier/ { print $2 }')"
[ "$TEAM" = "$TEAM_ID" ] || fail "Clove is signed by an unexpected team ($TEAM). Nothing was installed."
ASSESSMENT="$(spctl --assess --type execute -vv "$NEW" 2>&1 || true)"
case "$ASSESSMENT" in
    *"accepted"*"Notarized Developer ID"*) ;;
    *) fail "macOS doesn't accept this build as notarized. Nothing was installed." ;;
esac

WAS_RUNNING=0
pgrep -f "^$APP/Contents/MacOS/Clove" >/dev/null 2>&1 && WAS_RUNNING=1
quit_running "$APP"

mkdir -p "$DEST"
rm -rf "$APP"
ditto "$NEW" "$APP"

say "Installed Clove $VERSION in $DEST"
[ "$OPEN" = 1 ] || exit 0
open "$APP"
if [ "$WAS_RUNNING" = 0 ]; then
    echo "The first launch asks for your license key, then walks you through setup."
fi

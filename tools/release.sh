#!/usr/bin/env bash
set -euo pipefail

# Ships a Clove release from this Mac in one go:
# version bump, signed and notarized DMG, git tag, and a GitHub release with the
# DMG, its checksums, the signed Sparkle feed (appcast.xml), and install.sh.
# Clove reads appcast.xml from the latest release to update itself.
#
#   ./tools/release.sh 2.1                  notes written by GitHub from the commits
#   ./tools/release.sh 2.1 notes.md         notes from a file
#
# One-time setup:
#   brew install gh create-dmg && gh auth login
#   xcrun notarytool store-credentials AC_PASSWORD --apple-id YOU@EMAIL --team-id 2FFZB6R6U8
#     (asks for an app-specific password from account.apple.com)

VERSION="${1:-}"
NOTES="${2:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PROJECT="Clove.xcodeproj/project.pbxproj"
TAG="v$VERSION"
DMG="dist/Clove-$VERSION.dmg"

fail() { echo "x $*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || fail "Usage: ./tools/release.sh 2.1 [notes.md]"
[[ -z "$NOTES" || -f "$NOTES" ]] || fail "No notes file at $NOTES"
command -v gh >/dev/null || fail "Install the GitHub CLI: brew install gh"
gh auth status >/dev/null 2>&1 || fail "Sign in to GitHub first: gh auth login"
[[ -z "$(git status --porcelain)" ]] || fail "Commit or stash your changes first."
git rev-parse "$TAG" >/dev/null 2>&1 && fail "$TAG already exists."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "No notary profile \"$NOTARY_PROFILE\". See the one-time setup at the top of this script."

SIGN_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)"
[[ -n "$SIGN_ID" ]] || fail "No Developer ID Application certificate in your keychain."

echo "-> Clove $VERSION, signed as $SIGN_ID"

# Version bump: marketing version as given, build number up by one.
BUILD="$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/p' "$PROJECT" | head -1)"
NEXT_BUILD=$((BUILD + 1))
sed -i '' \
  -e "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/" \
  -e "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/" \
  "$PROJECT"
git commit -q -am "Release $VERSION" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
echo "-> Version $VERSION ($NEXT_BUILD) committed"

# Official builds need a license key; builds from source don't.
LICENSED=1 SIGN_ID="$SIGN_ID" NOTARIZE=1 NOTARY_PROFILE="$NOTARY_PROFILE" ./tools/MakeDMG.sh
[[ -f "$DMG" ]] || fail "Expected $DMG after the build."

# The update feed Clove reads through Sparkle, signed with the EdDSA key in this
# Mac's keychain (made once with `generate_keys --account clove`). Clove installs
# only updates that key signed. The notes come from the notes file, as HTML.
SPARKLE_BIN="$(find build/DerivedData/SourcePackages/artifacts -type d -path '*Sparkle/bin' | head -1)"
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || fail "Sparkle's tools weren't found after the build."
FEED_DIR="$(mktemp -d)"
cp "$DMG" "$FEED_DIR/"
if [[ -n "$NOTES" ]]; then
  python3 tools/notes-html.py "$NOTES" > "$FEED_DIR/Clove-$VERSION.html"
fi
"$SPARKLE_BIN/generate_appcast" --account clove --embed-release-notes \
  --download-url-prefix "https://github.com/keshav-exe/clove/releases/download/$TAG/" \
  --full-release-notes-url "https://clove.kshv.me/changelog" \
  -o dist/appcast.xml "$FEED_DIR"
grep -q "sparkle:edSignature" dist/appcast.xml || fail "The update feed isn't signed."

# What `curl ... install.sh | bash` checks the download against.
CHECKSUMS="dist/checksums.txt"
(cd dist && shasum -a 256 "$(basename "$DMG")") > "$CHECKSUMS"

git tag "$TAG"
git push -q origin HEAD "$TAG"

# Copies from 3.1 and earlier read this text in a small window that shows it
# raw, so it's the notes' first paragraph and a link. The full notes are in the
# update feed and on the changelog.
SHORT="Clove $VERSION is out. Full notes: https://clove.kshv.me/changelog"
[[ -n "$NOTES" ]] && SHORT="$(awk 'NF { print; exit }' "$NOTES") Full notes: https://clove.kshv.me/changelog"
gh release create "$TAG" "$DMG" "$CHECKSUMS" dist/appcast.xml tools/install.sh --title "Clove $VERSION" --notes "$SHORT"

echo ""
echo "ok Clove $VERSION is live. Every copy of Clove will offer it on its next check."

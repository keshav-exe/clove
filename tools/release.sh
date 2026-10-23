#!/usr/bin/env bash
set -euo pipefail

# Ships a Clove release from this Mac in one go:
# version bump, signed and notarized DMG, git tag, and a GitHub release.
# Clove reads the latest GitHub release to offer updates, so that's all it takes.
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

SIGN_ID="$SIGN_ID" NOTARIZE=1 NOTARY_PROFILE="$NOTARY_PROFILE" ./tools/MakeDMG.sh
[[ -f "$DMG" ]] || fail "Expected $DMG after the build."

git tag "$TAG"
git push -q origin HEAD "$TAG"

NOTE_ARGS=(--generate-notes)
[[ -n "$NOTES" ]] && NOTE_ARGS=(--notes-file "$NOTES")
gh release create "$TAG" "$DMG" --title "Clove $VERSION" "${NOTE_ARGS[@]}"

echo ""
echo "ok Clove $VERSION is live. Every copy of Clove will offer it on its next check."

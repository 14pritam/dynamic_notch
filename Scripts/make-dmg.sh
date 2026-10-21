#!/usr/bin/env bash
# Builds a universal release app and packages it as build/DynamicNotch-<version>.dmg.
#
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"   required for distribution
#   NOTARY_PROFILE=profile-name   a `xcrun notarytool store-credentials` profile; when set,
#                                 the DMG is notarized and stapled
#   VERSION=1.0.0 BUILD_NUMBER=1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
export VERSION
export UNIVERSAL=1
export CONFIG=release

"$ROOT/Scripts/build-app.sh"

APP="$ROOT/build/Dynamic Notch.app"
DMG="$ROOT/build/DynamicNotch-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "› Packaging $DMG…"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Dynamic Notch" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"

if [[ "${SIGN_IDENTITY:--}" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ "${SIGN_IDENTITY:--}" == "-" ]]; then
        echo "✗ Notarization needs a Developer ID SIGN_IDENTITY" >&2
        exit 1
    fi
    echo "› Notarizing (this can take a few minutes)…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi

echo "✓ $DMG"

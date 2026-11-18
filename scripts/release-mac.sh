#!/bin/bash
# Builds a signed, universal Lectern.app and wraps it in a signed DMG.
#
# Signing identity, in order of preference:
#   1. $SIGN_IDENTITY, if set
#   2. "Developer ID Application" (paid Apple Developer Program; required for notarization)
#   3. "Apple Development"
#   4. ad-hoc ("-")
#
# With a Developer ID identity and NOTARY_PROFILE set to a notarytool keychain
# profile (xcrun notarytool store-credentials), the DMG is notarized and stapled.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT=build/release
WORK="$OUT/mac-work"
rm -rf "$WORK" "$OUT"/Lectern-*.dmg
mkdir -p "$WORK"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    identities=$(security find-identity -v -p codesigning)
    if grep -q '"Developer ID Application' <<<"$identities"; then
        SIGN_IDENTITY="Developer ID Application"
    elif grep -q '"Apple Development' <<<"$identities"; then
        SIGN_IDENTITY="Apple Development"
    else
        SIGN_IDENTITY="-"
    fi
fi
echo "==> Signing with: $SIGN_IDENTITY"

timestamp_flag=()
[[ "$SIGN_IDENTITY" != "-" ]] && timestamp_flag=(--timestamp)

echo "==> Archiving"
(cd mac && xcodegen generate --quiet)
xcodebuild archive \
    -project mac/Lectern.xcodeproj \
    -scheme Lectern \
    -configuration Release \
    -archivePath "$WORK/Lectern.xcarchive" \
    -quiet \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    OTHER_CODE_SIGN_FLAGS="${timestamp_flag[*]:-}"

APP="$WORK/Lectern.app"
ditto "$WORK/Lectern.xcarchive/Products/Applications/Lectern.app" "$APP"
codesign --verify --strict --verbose=1 "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$OUT/Lectern-$VERSION.dmg"

echo "==> Building $DMG"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Lectern.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Lectern" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
# (Expansion form keeps macOS's bash 3.2 happy with an empty array under set -u.)
codesign --sign "$SIGN_IDENTITY" ${timestamp_flag[@]+"${timestamp_flag[@]}"} "$DMG"

if [[ "$SIGN_IDENTITY" == "Developer ID Application"* && -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Notarizing"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
else
    echo "warning: $DMG is signed but not notarized. On other Macs, approve it once in"
    echo "         System Settings > Privacy & Security > Open Anyway."
fi

echo "==> Done: $DMG"

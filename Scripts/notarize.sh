#!/bin/sh
# Notarizes and staples build/Clipstack.app, then packs it to share: a zip and a
# disk image, both in build/.
#
# Only needed when someone else installs it: on your own Mac the Developer ID
# signature from build-app.sh is enough.
#
# It reuses the notarytool credential Hippocampus already keeps in the Keychain
# (profile "hippocampus"). Set NOTARY_PROFILE for another one, or pass an App
# Store Connect API key in NOTARY_API_KEY, NOTARY_API_KEY_ID and NOTARY_API_ISSUER.
set -e
cd "$(dirname "$0")/.."

APP=build/Clipstack.app
PROFILE="${NOTARY_PROFILE:-hippocampus}"
[ -d "$APP" ] || { echo "run Scripts/build-app.sh first"; exit 1; }

if [ -n "$NOTARY_API_KEY" ] && [ -n "$NOTARY_API_KEY_ID" ] && [ -n "$NOTARY_API_ISSUER" ]; then
  set -- --key "$NOTARY_API_KEY" --key-id "$NOTARY_API_KEY_ID" --issuer "$NOTARY_API_ISSUER"
elif xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  set -- --keychain-profile "$PROFILE"
else
  echo "no notarytool credential \"$PROFILE\" in the Keychain; store one with:"
  echo "  xcrun notarytool store-credentials $PROFILE --apple-id YOU@EXAMPLE.COM --team-id YOURTEAM"
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
SUBMISSION=build/Clipstack-submission.zip
ZIP=build/Clipstack-$VERSION.zip

ditto -c -k --keepParent "$APP" "$SUBMISSION"
echo "==> submitting to Apple"
xcrun notarytool submit "$SUBMISSION" "$@" --wait
rm -f "$SUBMISSION"

xcrun stapler staple "$APP"
spctl -a -vvv -t exec "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> $ZIP"

# The disk image: the app beside a link to Applications, to drag it across. It is
# signed with the app's own identity and notarized as well, so Gatekeeper accepts
# the image itself and not only the app inside. Its name has no version, so
# releases/latest/download/Clipstack.dmg always gets the newest one.
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=\(Developer ID Application:.*\)$/\1/p')
[ -n "$IDENTITY" ] || { echo "the app isn't signed with a Developer ID, so there is no disk image"; exit 1; }
DMG=build/Clipstack.dmg
STAGE=$(mktemp -d)/Clipstack
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Clipstack.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname Clipstack -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
echo "==> submitting the disk image to Apple"
xcrun notarytool submit "$DMG" "$@" --wait
xcrun stapler staple "$DMG"
spctl -a -vvv -t open --context context:primary-signature "$DMG"
echo "==> $DMG"

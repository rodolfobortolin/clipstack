#!/bin/sh
# Notarizes and staples build/Clipstack.app, then packs it in a zip to share.
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

#!/bin/sh
# Builds build/Clipstack.app from the Swift package and signs it.
#
#   Scripts/build-app.sh            release build in build/
#   Scripts/build-app.sh --install  ...then copies it to /Applications and opens it
#   Scripts/build-app.sh --debug    debug build
#
# It signs with the Developer ID Application identity, like Speakly and
# Hippocampus. A stable identity matters here: macOS ties the Accessibility
# permission to the signature, and an ad-hoc signature changes on every build,
# which would ask for the permission again each time. Set SIGN_IDENTITY to use
# another one.
#
# iCloud sync needs two extra files that are not in the repository, because
# they come from the Apple Developer portal (see README):
#   Resources/Clipstack.entitlements, Resources/embedded.provisionprofile
set -e
cd "$(dirname "$0")/.."

APP_NAME=Clipstack
CONFIG=release
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG=debug ;;
    --install) INSTALL=1 ;;
    *) echo "unknown option: $arg"; exit 1 ;;
  esac
done

# Resources/AppIcon.png is the 1024-pixel picture the fallback .icns is made from.
if [ ! -f Resources/AppIcon.icns ] || [ Resources/AppIcon.png -nt Resources/AppIcon.icns ]; then
  echo "==> making AppIcon.icns"
  ICONSET=$(mktemp -d)/AppIcon.iconset
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"
BIN_DIR=$(swift build -c "$CONFIG" --show-bin-path)

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# The icon. Resources/AppIcon.icon is an Icon Composer icon: actool turns it
# into Assets.car, which macOS 26 draws in its own shape and glass, plus an
# .icns for older systems. Without it, the PNG-made .icns is used, which
# macOS 26 shows shrunk inside a gray square.
if [ -d Resources/AppIcon.icon ]; then
  echo "==> compiling AppIcon.icon"
  ICON_OUT=$(mktemp -d)
  xcrun actool "$PWD/Resources/AppIcon.icon" --compile "$ICON_OUT" --platform macosx --minimum-deployment-target 14.0 \
    --app-icon AppIcon --output-partial-info-plist "$ICON_OUT/partial.plist" >/dev/null
  cp "$ICON_OUT/Assets.car" "$ICON_OUT/AppIcon.icns" "$APP/Contents/Resources/"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon" "$APP/Contents/Info.plist"
else
  cp Resources/AppIcon.icns "$APP/Contents/Resources/"
fi

# English is the base language; the catalog becomes one .lproj per translation.
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources" >/dev/null
mkdir -p "$APP/Contents/Resources/en.lproj"

if [ -n "$SIGN_IDENTITY" ]; then
  IDENTITY=$SIGN_IDENTITY
else
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)
  [ -n "$IDENTITY" ] || IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)
fi

set --
if [ -f Resources/Clipstack.entitlements ] && [ -f Resources/embedded.provisionprofile ]; then
  cp Resources/embedded.provisionprofile "$APP/Contents/"
  set -- --entitlements Resources/Clipstack.entitlements
  echo "==> with iCloud entitlements"
fi

if [ -n "$IDENTITY" ]; then
  echo "==> signing as $IDENTITY"
  codesign --force --options runtime --timestamp "$@" --sign "$IDENTITY" "$APP"
else
  echo "==> no signing identity found, signing ad hoc"
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
echo "==> $APP"

if [ "$INSTALL" = 1 ]; then
  DEST=/Applications
  [ -w "$DEST" ] || DEST="$HOME/Applications"
  mkdir -p "$DEST"
  pkill -x "$APP_NAME" 2>/dev/null && sleep 0.5 || true
  rm -rf "$DEST/$APP_NAME.app"
  cp -R "$APP" "$DEST/"
  echo "==> installed in $DEST"
  open "$DEST/$APP_NAME.app"
fi

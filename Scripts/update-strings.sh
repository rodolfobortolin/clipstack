#!/bin/sh
# Adds new user-facing strings from the code to Resources/Localizable.xcstrings.
# The compiler records every LocalizedStringKey and String(localized:) it sees;
# xcstringstool merges them into the catalog, keeping existing translations.
# New keys show up untranslated: open the catalog in Xcode to translate them.
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swift build -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$OUT" >/dev/null
xcrun xcstringstool sync Resources/Localizable.xcstrings --stringsdata "$OUT"/*.stringsdata
rm -rf "$OUT"
echo "==> Resources/Localizable.xcstrings updated"

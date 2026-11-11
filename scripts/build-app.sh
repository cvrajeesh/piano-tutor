#!/bin/bash
# Builds "Middle C.app" into ./build using only the Swift toolchain
# (Xcode or the Xcode Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/Middle C.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/PianoTutor" "$APP/Contents/MacOS/PianoTutor"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Sources/PianoTutor/Resources/Bravura.otf "$APP/Contents/Resources/Bravura.otf"
cp Sources/PianoTutor/Resources/Bravura-LICENSE.txt "$APP/Contents/Resources/Bravura-LICENSE.txt"
# Translations: one folder per language (en.lproj, fr.lproj …). macOS picks the app's
# language from these, and Text("…") looks its strings up in them.
cp -R Sources/PianoTutor/Resources/*.lproj "$APP/Contents/Resources/"

# Ad-hoc signature so the app runs on Apple silicon.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Open it with:  open \"$APP\""

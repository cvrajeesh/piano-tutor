#!/bin/bash
# Renders the app icons from the SVG masters in Support/Icon:
#   Support/AppIcon.icns                                  macOS app bundle (SwiftPM build)
#   Support/macOS/Assets.xcassets/AppIcon.appiconset/*    Mac App Store build
#   Support/iOS/Assets.xcassets/AppIcon.appiconset/*.png  iPhone and iPad
# Needs librsvg and ImageMagick (brew install librsvg imagemagick) and, for the
# .icns, macOS's iconutil. The results are checked in; rerun after editing an SVG.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=Support/Icon
IOS=Support/iOS/Assets.xcassets/AppIcon.appiconset

# iOS: one 1024 px image per appearance, opaque (App Store rejects alpha).
ios() {
    rsvg-convert -w 1024 -h 1024 "$SRC/$1.svg" | magick png:- -alpha off -define png:color-type=2 "$IOS/$2.png"
}
ios icon AppIcon
ios icon-dark AppIcon-Dark
ios icon-tinted AppIcon-Tinted

# macOS: every size iconutil expects; 16 and 32 px use the simplified drawing.
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
mac() {
    local px=$1 name=$2 master=icon-macos
    if [ "$px" -le 32 ]; then master=icon-macos-small; fi
    rsvg-convert -w "$px" -h "$px" "$SRC/$master.svg" -o "$SET/icon_$name.png"
}
mac 16 16x16;      mac 32 16x16@2x
mac 32 32x32;      mac 64 32x32@2x
mac 128 128x128;   mac 256 128x128@2x
mac 256 256x256;   mac 512 256x256@2x
mac 512 512x512;   mac 1024 512x512@2x
iconutil -c icns "$SET" -o Support/AppIcon.icns
cp "$SET"/*.png Support/macOS/Assets.xcassets/AppIcon.appiconset/
rm -rf "$(dirname "$SET")"

echo "Wrote Support/AppIcon.icns, Support/macOS/Assets.xcassets and $IOS"

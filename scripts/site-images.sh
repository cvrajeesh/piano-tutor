#!/usr/bin/env bash
# Makes the website's images (site/images, the favicons) from the app icon and the
# screenshots in docs/screenshots. They aren't committed: the Website workflow runs
# this before every deploy, and you run it once before previewing the site locally.
# Needs cwebp and ImageMagick: brew install webp imagemagick (apt: webp imagemagick)
set -euo pipefail
cd "$(dirname "$0")/.."

# ImageMagick 7 is "magick"; version 6 (Ubuntu's package) is "convert".
if command -v magick >/dev/null; then im=magick; else im=convert; fi
magick() { command "$im" "$@"; }

shots=docs/screenshots
out=site/images
mkdir -p "$out"

webp() { # source, width, name
  cwebp -quiet -q 82 -resize "$2" 0 "$1" -o "$out/$3.webp"
}

webp "$shots/macos/lesson-practice.png"           1600 mac-practice
webp "$shots/macos/lesson-in-time.png"            1400 mac-in-time
webp "$shots/macos/learn.png"                     1400 mac-learn
webp "$shots/ipad/songs-landscape.png"            1400 ipad-songs
webp "$shots/ipad/song-landscape.png"             1400 ipad-song
webp "$shots/iphone/song-portrait.png"             640 iphone-song
webp "$shots/iphone/free-play-portrait.png"        640 iphone-free-play
webp "$shots/iphone/learn-portrait.png"            640 iphone-learn
webp "$shots/iphone/lesson-practice-portrait.png"  640 iphone-practice

# Icons: the SVG for browsers, PNGs for iOS home screens.
icon=Support/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png
cp Support/Icon/icon.svg site/favicon.svg
magick "$icon" -resize 180x180 site/apple-touch-icon.png
magick "$icon" -resize 256x256 "$out/icon-256.png"

# Link preview (1200x630): the practice screen on the app's background colour.
magick -size 1200x630 gradient:'#2A3350'-'#121724' \
  \( "$shots/macos/lesson-practice.png" -resize 1080x \) -gravity north -geometry +0+60 -composite \
  -quality 85 "$out/og-image.jpg"

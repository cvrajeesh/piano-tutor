# /// script
# requires-python = ">=3.9"
# dependencies = ["pillow>=10"]
# ///
"""Makes the website's images (site/images, the favicons) from the app icon and
the screenshots in docs/screenshots.

They aren't committed: the Website workflow runs this before every deploy, and you
run it once before previewing the site locally:

    uv run scripts/site-images.py
"""

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"
SITE = ROOT / "site"
OUT = SITE / "images"
ICON_PNG = ROOT / "Support/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
ICON_SVG = ROOT / "Support/Icon/icon.svg"

# (source in docs/screenshots, width in pixels, name in site/images)
SCREENSHOTS = [
    ("macos/lesson-practice.png", 1600, "mac-practice"),
    ("macos/lesson-in-time.png", 1400, "mac-in-time"),
    ("macos/learn.png", 1400, "mac-learn"),
    ("ipad/songs-landscape.png", 1400, "ipad-songs"),
    ("ipad/song-landscape.png", 1400, "ipad-song"),
    ("iphone/song-portrait.png", 640, "iphone-song"),
    ("iphone/free-play-portrait.png", 640, "iphone-free-play"),
    ("iphone/learn-portrait.png", 640, "iphone-learn"),
    ("iphone/lesson-practice-portrait.png", 640, "iphone-practice"),
]


def resized(path: Path, width: int) -> Image.Image:
    image = Image.open(path)
    image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
    height = round(image.height * width / image.width)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def hex_colour(value: str) -> tuple:
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def link_preview(path: Path) -> None:
    """1200x630: the practice screen on the app's background gradient."""
    size = (1200, 630)
    top = Image.new("RGB", size, hex_colour("#2A3350"))
    bottom = Image.new("RGB", size, hex_colour("#121724"))
    mask = Image.linear_gradient("L").resize(size)
    background = Image.composite(bottom, top, mask)
    shot = resized(SHOTS / "macos/lesson-practice.png", 1080)
    background.paste(shot, (60, 60), shot if shot.mode == "RGBA" else None)
    background.save(path, quality=85, optimize=True, progressive=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    for source, width, name in SCREENSHOTS:
        resized(SHOTS / source, width).save(OUT / f"{name}.webp", quality=82, method=6)

    shutil.copyfile(ICON_SVG, SITE / "favicon.svg")
    resized(ICON_PNG, 180).save(SITE / "apple-touch-icon.png", optimize=True)
    resized(ICON_PNG, 256).save(OUT / "icon-256.png", optimize=True)

    link_preview(OUT / "og-image.jpg")

    count = len(list(OUT.iterdir()))
    print(f"Wrote {count} images to {OUT.relative_to(ROOT)} and 2 icons to site/")


if __name__ == "__main__":
    main()

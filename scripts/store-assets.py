# /// script
# requires-python = ">=3.9"
# dependencies = ["pillow>=10"]
# ///
"""Checks the App Store text in fastlane/metadata and makes the App Store screenshots
in fastlane/screenshots from the captures in docs/screenshots.

    uv run scripts/store-assets.py            # check the text, then make the screenshots
    uv run scripts/store-assets.py --check    # only check the text

Each screenshot is a capture from docs/screenshots on the app's navy background, with
a caption above it, at a size App Store Connect accepts:

    fastlane/screenshots/ios/en-US   iPhone 6.9" (1320x2868) and iPad 13" (2752x2064)
    fastlane/screenshots/mac/en-US   Mac (2880x1800)

Apple scales these down for the smaller devices. The screenshots aren't committed: the
Release workflow runs this before it uploads them. It needs macOS for the San Francisco
font; elsewhere it falls back to a font Pillow can find, which is fine for a preview.
See docs/app-store-listing.md.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"
METADATA = ROOT / "fastlane" / "metadata"
OUT = ROOT / "fastlane" / "screenshots"

# Colours from the app and site/style.css.
BG_TOP = (0x2A, 0x33, 0x50)
BG_BOTTOM = (0x12, 0x17, 0x24)
TEXT = (0xF4, 0xF1, 0xEA)
TEXT_DIM = (0xA9, 0xAF, 0xC2)

# The story the screenshots tell, in order. The first two or three are the ones
# people see in search results, so they carry the main idea.
CAPTIONS = [
    ("lesson-practice", "Piano lessons that listen", "Plug in your keyboard. Middle C hears every note."),
    ("song", "The music waits for you", "The next key lights up, with the finger to use."),
    ("lesson-in-time", "Then play it in time", "A count-in, a moving staff, and every note judged."),
    ("learn", "27 short lessons", "From finding Middle C to chords in your left hand."),
    ("songs", "18 songs to learn", "Either hand or both, at 60%, 80% or full speed."),
    ("free-play", "See what you play", "Every note appears on the staff, with its name."),
]

# (folder in fastlane/screenshots, file prefix, folder in docs/screenshots,
#  suffix of the capture's name, canvas size, headline size, caption size,
#  corner radius as a fraction of the capture's width)
TARGETS = [
    ("ios", "iphone", "iphone", "-portrait", (1320, 2868), 100, 50, 0.12),
    ("ios", "ipad", "ipad", "-landscape", (2752, 2064), 112, 56, 0.025),
    ("mac", "mac", "macos", "", (2880, 1800), 96, 48, 0.012),
]

# Limits from App Store Connect. Keywords are counted in bytes.
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "keywords.txt": 100,
    "release_notes.txt": 4000,
}
REQUIRED = ["name.txt", "subtitle.txt", "description.txt", "keywords.txt",
            "support_url.txt", "privacy_url.txt"]
NOT_LOCALES = {"review_information"}


# --- Text ---------------------------------------------------------------------

def check_metadata() -> list:
    problems = []
    locales = [p for p in sorted(METADATA.iterdir()) if p.is_dir() and p.name not in NOT_LOCALES]
    if not locales:
        problems.append(f"No language folders in {METADATA.relative_to(ROOT)}")

    for locale in locales:
        for name in REQUIRED:
            path = locale / name
            if not path.exists() or not path.read_text(encoding="utf-8").strip():
                problems.append(f"{path.relative_to(ROOT)}: missing or empty")

        for name, limit in LIMITS.items():
            path = locale / name
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8").strip()
            length = len(text.encode("utf-8")) if name == "keywords.txt" else len(text)
            if length > limit:
                problems.append(f"{path.relative_to(ROOT)}: {length} characters, the limit is {limit}")

        keywords_path = locale / "keywords.txt"
        if keywords_path.exists():
            keywords = [k.strip() for k in keywords_path.read_text(encoding="utf-8").split(",")]
            if not all(keywords):
                problems.append(f"{keywords_path.relative_to(ROOT)}: empty keyword")
            # Words in the name and subtitle are already searchable; repeating them wastes space.
            title_words = set()
            for name in ("name.txt", "subtitle.txt"):
                if (locale / name).exists():
                    title_words |= set((locale / name).read_text(encoding="utf-8").lower().split())
            repeated = sorted(k for k in keywords if k.lower() in title_words)
            if repeated:
                problems.append(f"{keywords_path.relative_to(ROOT)}: already in the name or subtitle: {', '.join(repeated)}")

        for name in ("support_url.txt", "privacy_url.txt", "marketing_url.txt"):
            path = locale / name
            if path.exists() and not path.read_text(encoding="utf-8").strip().startswith("https://"):
                problems.append(f"{path.relative_to(ROOT)}: not an https:// URL")

    return problems


# --- Screenshots -------------------------------------------------------------

def font(size: int, bold: bool):
    try:
        face = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        face.set_variation_by_name("Bold" if bold else "Regular")
        return face
    except OSError:
        pass
    for name in (("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"), "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def wrap(draw: ImageDraw.ImageDraw, text: str, face, width: int) -> list:
    """Splits text into lines no wider than width, keeping the lines even."""
    words = text.split()
    lines, line = [], ""
    for word in words:
        candidate = f"{line} {word}".strip()
        if draw.textlength(candidate, font=face) <= width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    lines.append(line)
    # Avoid a single word on the last line.
    if len(lines) > 1 and " " not in lines[-1]:
        last_two = " ".join(lines[-2:]).split()
        middle = len(last_two) // 2 + 1
        first, second = " ".join(last_two[:middle]), " ".join(last_two[middle:])
        if second and draw.textlength(first, font=face) <= width:
            lines[-2:] = [first, second]
    return lines


def background(size: tuple) -> Image.Image:
    top = Image.new("RGB", size, BG_TOP)
    bottom = Image.new("RGB", size, BG_BOTTOM)
    mask = Image.linear_gradient("L").resize(size)
    return Image.composite(bottom, top, mask)


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def padding(size: tuple) -> int:
    return round(min(size) * 0.06)


def draw_caption(draw: ImageDraw.ImageDraw, size: tuple, headline: str, caption: str,
                 h1: int, h2: int) -> int:
    """Draws the caption centred at the top and returns the y where it ends."""
    width, pad = size[0], padding(size)
    head_face, sub_face = font(h1, True), font(h2, False)
    text_width = width - 2 * pad
    y = round(pad * 1.3)
    for line in wrap(draw, headline, head_face, text_width):
        draw.text((width / 2, y), line, font=head_face, fill=TEXT, anchor="ma")
        y += round(h1 * 1.18)
    y += round(h2 * 0.5)
    for line in wrap(draw, caption, sub_face, round(text_width * 0.9)):
        draw.text((width / 2, y), line, font=sub_face, fill=TEXT_DIM, anchor="ma")
        y += round(h2 * 1.3)
    return y


def caption_height(size: tuple, h1: int, h2: int) -> int:
    """The space the longest caption needs, so every capture in a set sits at the same place."""
    scratch = ImageDraw.Draw(Image.new("RGB", size))
    return max(draw_caption(scratch, size, headline, caption, h1, h2)
               for _, headline, caption in CAPTIONS)


def compose(source: Path, size: tuple, headline: str, caption: str,
            h1: int, h2: int, corner: float, caption_bottom: int) -> Image.Image:
    width, height = size
    pad = padding(size)
    canvas = background(size)
    draw_caption(ImageDraw.Draw(canvas), size, headline, caption, h1, h2)

    # The capture, as large as fits below the caption.
    top = caption_bottom + round(pad * 0.7)
    box_w, box_h = width - 2 * pad, height - top - pad
    shot = Image.open(source).convert("RGB")
    scale = min(box_w / shot.width, box_h / shot.height)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.Resampling.LANCZOS)
    radius = round(shot.width * corner)
    x = (width - shot.width) // 2
    top += (box_h - shot.height) // 2

    # A soft shadow and a hairline edge, so the dark capture stands off the background.
    shadow = Image.new("L", size, 0)
    blur = max(8, pad // 2)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x, top + blur // 2, x + shot.width, top + shot.height + blur // 2), radius, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", size, (0, 0, 0)), (0, 0), shadow)

    canvas.paste(rounded(shot, radius), (x, top), rounded(shot, radius))
    edge = max(2, round(width / 900))
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x - edge, top - edge, x + shot.width + edge - 1, top + shot.height + edge - 1),
        radius + edge, outline=(0x3A, 0x43, 0x60), width=edge)

    return canvas


def make_screenshots() -> int:
    count = 0
    for folder in {target[0] for target in TARGETS}:
        out = OUT / folder / "en-US"
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.png"):
            old.unlink()

    for folder, prefix, shots, suffix, size, h1, h2, corner in TARGETS:
        out = OUT / folder / "en-US"
        caption_bottom = caption_height(size, h1, h2)
        for index, (name, headline, caption) in enumerate(CAPTIONS, start=1):
            source = SHOTS / shots / f"{name}{suffix}.png"
            image = compose(source, size, headline, caption, h1, h2, corner, caption_bottom)
            # No alpha channel: App Store Connect rejects screenshots that have one.
            image.convert("RGB").save(out / f"{prefix}-{index:02d}-{name}.png", optimize=True)
            count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("--check", action="store_true", help="only check the text in fastlane/metadata")
    args = parser.parse_args()

    problems = check_metadata()
    for problem in problems:
        print(f"error: {problem}", file=sys.stderr)
    if problems:
        sys.exit(1)
    print("App Store text is within the limits")

    if not args.check:
        count = make_screenshots()
        print(f"Wrote {count} screenshots to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

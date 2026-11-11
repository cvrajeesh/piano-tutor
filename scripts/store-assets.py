# /// script
# requires-python = ">=3.9"
# dependencies = ["pillow>=10"]
# ///
"""Checks the App Store text in fastlane/metadata and makes the App Store screenshots
in fastlane/screenshots from the captures in docs/screenshots.

    uv run scripts/store-assets.py               # check the text, then make the screenshots
    uv run scripts/store-assets.py --check       # only check the text
    uv run scripts/store-assets.py --locale ja   # make one language's screenshots

Each screenshot is a capture from docs/screenshots on the app's navy background, with
a caption from fastlane/screenshot_captions.json above it, at a size App Store Connect
accepts. One set per language:

    fastlane/screenshots/ios/<locale>   iPhone 6.9" (1320x2868) and iPad 13" (2752x2064)
    fastlane/screenshots/mac/<locale>   Mac (2880x1800)

A language uses its own captures from docs/screenshots/<locale>/<device> when they
exist, and the English ones in docs/screenshots/<device> until then.

Apple scales these down for the smaller devices. The screenshots aren't committed: the
Release workflow runs this before it uploads them. It needs macOS for the San Francisco,
Hiragino and Apple SD Gothic Neo fonts; elsewhere it falls back to a font Pillow can
find, which is fine for checking the text but not for the store.
See docs/app-store-listing.md.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"
METADATA = ROOT / "fastlane" / "metadata"
CAPTIONS_FILE = ROOT / "fastlane" / "screenshot_captions.json"
OUT = ROOT / "fastlane" / "screenshots"

# Colours from the app and site/style.css.
BG_TOP = (0x2A, 0x33, 0x50)
BG_BOTTOM = (0x12, 0x17, 0x24)
TEXT = (0xF4, 0xF1, 0xEA)
TEXT_DIM = (0xA9, 0xAF, 0xC2)

# The screens, in store order, and each language's captions for them.
CAPTIONS = json.loads(CAPTIONS_FILE.read_text(encoding="utf-8"))
SCREENS = CAPTIONS["screens"]

# (folder in fastlane/screenshots, file prefix, folder in docs/screenshots,
#  suffix of the capture's name, canvas size, headline size, caption size,
#  corner radius as a fraction of the capture's width)
TARGETS = [
    ("ios", "iphone", "iphone", "-portrait", (1320, 2868), 100, 50, 0.12),
    ("ios", "ipad", "ipad", "-landscape", (2752, 2064), 112, 56, 0.025),
    ("mac", "mac", "macos", "", (2880, 1800), 96, 48, 0.012),
]

# Fonts for the languages San Francisco doesn't cover: (bold, regular), each a
# (file, index in the collection). Their Latin letters and digits are close enough.
SYSTEM_FONTS = Path("/System/Library/Fonts")
CJK_FONTS = {
    "ja": (("ヒラギノ角ゴシック W6.ttc", 0), ("ヒラギノ角ゴシック W3.ttc", 0)),
    "ko": (("AppleSDGothicNeo.ttc", 6), ("AppleSDGothicNeo.ttc", 0)),
    "zh-Hans": (("Hiragino Sans GB.ttc", 2), ("Hiragino Sans GB.ttc", 0)),
}
# Languages written without spaces between words, which wrap between characters.
NO_SPACES = {"ja", "zh-Hans", "zh-Hant"}
# The app's name, which a caption never splits across two lines.
KEEP_TOGETHER = "Middle C"
# Characters that mustn't start a line in Chinese and Japanese.
NO_LINE_START = set("、。，．・：；？！）」』】〉》”’%％ー々ぁぃぅぇぉっゃゅょァィゥェォッャュョ")

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

    # Every language on the store has screenshot captions, and the other way round.
    captions_file = CAPTIONS_FILE.relative_to(ROOT)
    store_locales = {p.name for p in locales}
    for locale in sorted(store_locales - CAPTIONS["captions"].keys()):
        problems.append(f"{captions_file}: no captions for {locale}")
    for locale, captions in sorted(CAPTIONS["captions"].items()):
        if locale not in store_locales:
            problems.append(f"{captions_file}: {locale} has captions but no fastlane/metadata/{locale}")
        for screen in SCREENS:
            pair = captions.get(screen)
            if not (isinstance(pair, list) and len(pair) == 2 and all(t.strip() for t in pair)):
                problems.append(f"{captions_file}: {locale} needs a headline and a caption for {screen}")
        for screen in sorted(captions.keys() - set(SCREENS)):
            problems.append(f"{captions_file}: {locale} has a caption for {screen}, which isn't in screens")

    return problems


# --- Screenshots -------------------------------------------------------------

def font(locale: str, size: int, bold: bool):
    try:
        if locale in CJK_FONTS:
            name, index = CJK_FONTS[locale][0 if bold else 1]
            return ImageFont.truetype(str(SYSTEM_FONTS / name), size, index=index)
        face = ImageFont.truetype(str(SYSTEM_FONTS / "SFNS.ttf"), size)
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


def characters(text: str) -> list:
    """Splits text without spaces into the characters a line may break between."""
    pieces = []
    for char in text:
        # Keep closing punctuation with the character before it, and Latin words and
        # numbers ("Middle C", "60%") in one piece.
        if pieces and (char in NO_LINE_START or char == " "
                       or (char.isascii() and pieces[-1][-1:].isascii())):
            pieces[-1] += char
        else:
            pieces.append(char)
    return pieces


def units(draw: ImageDraw.ImageDraw, text: str, locale: str, face, width: int) -> tuple:
    """The pieces a line may break between, and what joins them back together.

    Languages with spaces break between words, and never inside "Middle C". Chinese
    and Japanese break where the caption has a "|", which isn't drawn; a piece too
    long for a line breaks between characters as a last resort.
    """
    if locale not in NO_SPACES:
        text = text.replace("|", "").replace(KEEP_TOGETHER, KEEP_TOGETHER.replace(" ", "\0"))
        return [word.replace("\0", " ") for word in text.split()], " "
    pieces = []
    for piece in text.split("|"):
        if draw.textlength(piece, font=face) <= width:
            pieces.append(piece)
        else:
            pieces.extend(characters(piece))
    return pieces, ""


def greedy(draw: ImageDraw.ImageDraw, pieces: list, joiner: str, face, width: float) -> list:
    lines, line = [], ""
    for piece in pieces:
        candidate = f"{line}{joiner}{piece}" if line else piece
        if draw.textlength(candidate.strip(), font=face) <= width or not line:
            line = candidate
        else:
            lines.append(line.strip())
            line = piece
    lines.append(line.strip())
    return lines


def wrap(draw: ImageDraw.ImageDraw, text: str, locale: str, face, width: int) -> list:
    """Splits text into as few lines as fit in width, as even in length as they can be."""
    pieces, joiner = units(draw, text, locale, face, width)
    lines = greedy(draw, pieces, joiner, face, width)
    # The narrowest width that still needs no more lines balances them.
    low, high = width / len(lines), width
    while high - low > 4:
        middle = (low + high) / 2
        if len(greedy(draw, pieces, joiner, face, middle)) <= len(lines):
            high = middle
        else:
            low = middle
    return greedy(draw, pieces, joiner, face, high)


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


def draw_caption(draw: ImageDraw.ImageDraw, size: tuple, locale: str, headline: str,
                 caption: str, h1: int, h2: int) -> int:
    """Draws the caption centred at the top and returns the y where it ends."""
    width, pad = size[0], padding(size)
    head_face, sub_face = font(locale, h1, True), font(locale, h2, False)
    text_width = width - 2 * pad
    y = round(pad * 1.3)
    for line in wrap(draw, headline, locale, head_face, text_width):
        draw.text((width / 2, y), line, font=head_face, fill=TEXT, anchor="ma")
        y += round(h1 * 1.18)
    y += round(h2 * 0.5)
    for line in wrap(draw, caption, locale, sub_face, round(text_width * 0.9)):
        draw.text((width / 2, y), line, font=sub_face, fill=TEXT_DIM, anchor="ma")
        y += round(h2 * 1.3)
    return y


def caption_height(size: tuple, locale: str, h1: int, h2: int) -> int:
    """The space the longest caption needs, so every capture in a set sits at the same place."""
    scratch = ImageDraw.Draw(Image.new("RGB", size))
    return max(draw_caption(scratch, size, locale, headline, caption, h1, h2)
               for headline, caption in CAPTIONS["captions"][locale].values())


def capture(locale: str, device: str, name: str) -> Path:
    """The language's own capture of a screen if there is one, otherwise the English one."""
    localised = SHOTS / locale / device / name
    return localised if localised.exists() else SHOTS / device / name


def compose(source: Path, size: tuple, locale: str, headline: str, caption: str,
            h1: int, h2: int, corner: float, caption_bottom: int) -> Image.Image:
    width, height = size
    pad = padding(size)
    canvas = background(size)
    draw_caption(ImageDraw.Draw(canvas), size, locale, headline, caption, h1, h2)

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


def make_screenshots(locales: list) -> int:
    count = 0
    for locale in locales:
        # Start each language afresh, so a screen taken out of the list doesn't linger.
        for folder in {target[0] for target in TARGETS}:
            shutil.rmtree(OUT / folder / locale, ignore_errors=True)
            (OUT / folder / locale).mkdir(parents=True)

        for folder, prefix, device, suffix, size, h1, h2, corner in TARGETS:
            out = OUT / folder / locale
            caption_bottom = caption_height(size, locale, h1, h2)
            for index, name in enumerate(SCREENS, start=1):
                headline, caption = CAPTIONS["captions"][locale][name]
                source = capture(locale, device, f"{name}{suffix}.png")
                image = compose(source, size, locale, headline, caption, h1, h2, corner, caption_bottom)
                # No alpha channel: App Store Connect rejects screenshots that have one.
                image.convert("RGB").save(out / f"{prefix}-{index:02d}-{name}.png", optimize=True)
                count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("--check", action="store_true", help="only check the text in fastlane/metadata")
    parser.add_argument("--locale", action="append", help="only make this language's screenshots (repeatable)")
    args = parser.parse_args()

    problems = check_metadata()
    for problem in problems:
        print(f"error: {problem}", file=sys.stderr)
    if problems:
        sys.exit(1)
    print("App Store text is within the limits")

    if not args.check:
        locales = args.locale or sorted(CAPTIONS["captions"])
        unknown = [locale for locale in locales if locale not in CAPTIONS["captions"]]
        if unknown:
            sys.exit(f"error: no captions for {', '.join(unknown)} in {CAPTIONS_FILE.relative_to(ROOT)}")
        count = make_screenshots(locales)
        print(f"Wrote {count} screenshots in {len(locales)} languages to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

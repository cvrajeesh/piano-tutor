# /// script
# requires-python = ">=3.9"
# dependencies = ["jinja2>=3.1"]
# ///
"""Builds the website, in every language, into build/site.

The pages are Jinja templates in site/templates; their text is in site/locales/<language>.json,
one file per language. Unit titles, song names and song level headings come from the app's own
translations (Sources/PianoTutor/Resources/<language>.lproj), so the site always matches the
app. Everything else in site/ (style.css, images, CNAME, robots.txt) is copied as it is.

English is served at the root (/, /support.html) and every other language under its own
folder (/fr/, /pt-br/), each page linking to its translations with hreflang. Nothing redirects
by language; a page only offers a link when the browser prefers another language we have.

    uv run scripts/site-images.py     # once, for the images
    uv run scripts/build-site.py
    python3 -m http.server -d build/site

While translating, `uv run scripts/build-site.py en fr` builds only the languages named.

The build fails if a language misses a key, or a page links to a file that doesn't exist.
See docs/localization.md.
"""

import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any, Callable
from xml.sax.saxutils import escape as xml_escape

from jinja2 import Environment, FileSystemLoader, StrictUndefined
from markupsafe import Markup, escape

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
OUT = ROOT / "build" / "site"
APP_STRINGS = ROOT / "Sources" / "PianoTutor" / "Resources"
BASE_URL = "https://middlec.liskovlabs.com/"

# code: the locale file and .lproj folder; path: the folder the pages live in;
# hreflang/html: the language tag; og: the Open Graph locale; name: in its own language.
LANGUAGES = [
    {"code": "en", "path": "", "tag": "en", "og": "en_GB", "name": "English"},
    {"code": "es", "path": "es/", "tag": "es", "og": "es_ES", "name": "Español"},
    {"code": "fr", "path": "fr/", "tag": "fr", "og": "fr_FR", "name": "Français"},
    {"code": "de", "path": "de/", "tag": "de", "og": "de_DE", "name": "Deutsch"},
    {"code": "it", "path": "it/", "tag": "it", "og": "it_IT", "name": "Italiano"},
    {"code": "pt-BR", "path": "pt-br/", "tag": "pt-BR", "og": "pt_BR", "name": "Português (Brasil)"},
    {"code": "ja", "path": "ja/", "tag": "ja", "og": "ja_JP", "name": "日本語"},
    {"code": "zh-Hans", "path": "zh-hans/", "tag": "zh-Hans", "og": "zh_CN", "name": "简体中文"},
    {"code": "ko", "path": "ko/", "tag": "ko", "og": "ko_KR", "name": "한국어"},
]
ENGLISH = LANGUAGES[0]
PAGES = ["index.html", "support.html", "privacy.html"]

# The course units and songs, by their English text, which is the key of their translation
# in Course.strings. They must match Sources/PianoTutorCore; the build fails if one is missing.
UNITS = [
    ("Meet the Keys", "Find your way around the keyboard and play your first notes.", 3),
    ("Feel the Beat", "Play in time: quarter, half and whole notes, and rests.", 4),
    ("Read the Staff", "Learn to read notes without the letter names.", 4),
    ("The Left Hand", "A second hand and a second clef.", 3),
    ("Hands Together", "Play a tune in one hand over long notes in the other.", 3),
    ("Quicker Notes", "Eighth notes and dotted rhythms.", 3),
    ("Beyond Five Notes", "Stretch, move, and use the black keys.", 4),
    ("Chords", "Play several notes at once and accompany a tune.", 3),
]
SONG_LEVELS = [
    ("First tunes", [
        ("Hot Cross Buns", "English traditional"),
        ("Mary Had a Little Lamb", "Traditional"),
        ("Lightly Row", "German traditional"),
        ("Go Tell Aunt Rhody", "Traditional"),
        ("Au Clair de la Lune", "French traditional"),
    ]),
    ("Getting going", [
        ("Ode to Joy", "Ludwig van Beethoven"),
        ("Largo from the \"New World\" Symphony", "Antonín Dvořák"),
        ("Twinkle, Twinkle, Little Star", "French melody, 18th century"),
        ("Jingle Bells", "James Pierpont"),
        ("Long, Long Ago", "Thomas Haynes Bayly"),
        ("Frère Jacques", "French traditional"),
        ("London Bridge", "English traditional"),
        ("Old MacDonald", "Traditional"),
        ("Oh! Susanna", "Stephen Foster"),
        ("Yankee Doodle", "Traditional"),
    ]),
    ("A challenge", [
        ("Amazing Grace", "Traditional"),
        ("Minuet in G", "Christian Petzold"),
        ("Für Elise (opening)", "Ludwig van Beethoven"),
    ]),
]


class BuildError(Exception):
    pass


def read_strings(path: Path) -> dict:
    """Parses an Apple .strings file: "key" = "value"; with /* */ and // comments."""
    text = path.read_text(encoding="utf-8")
    result, i, n = {}, 0, len(text)

    def skip() -> None:
        nonlocal i
        while i < n:
            if text[i].isspace():
                i += 1
            elif text.startswith("/*", i):
                end = text.find("*/", i + 2)
                if end < 0:
                    raise BuildError(f"{path}: unclosed comment")
                i = end + 2
            elif text.startswith("//", i):
                end = text.find("\n", i)
                i = n if end < 0 else end + 1
            else:
                return

    def quoted() -> str:
        nonlocal i
        if i >= n or text[i] != '"':
            raise BuildError(f"{path}: expected a quoted string at offset {i}")
        i += 1
        out = []
        while i < n and text[i] != '"':
            if text[i] == "\\":
                i += 1
                c = text[i]
                if c == "n":
                    out.append("\n")
                elif c == "t":
                    out.append("\t")
                elif c in "Uu":
                    out.append(chr(int(text[i + 1:i + 5], 16)))
                    i += 4
                else:
                    out.append(c)
            else:
                out.append(text[i])
            i += 1
        i += 1
        return "".join(out)

    def expect(char: str) -> None:
        nonlocal i
        skip()
        if i >= n or text[i] != char:
            raise BuildError(f"{path}: expected '{char}' at offset {i}")
        i += 1

    while True:
        skip()
        if i >= n:
            return result
        key = quoted()
        expect("=")
        skip()
        result[key] = quoted()
        expect(";")


def flatten(data: dict, prefix: str = "") -> dict:
    out = {}
    for key, value in data.items():
        if key.startswith("_"):
            continue
        if isinstance(value, dict):
            out.update(flatten(value, f"{prefix}{key}."))
        else:
            out[prefix + key] = value
    return out


def load_locale(language: dict, english_keys: set) -> Any:
    path = SITE / "locales" / f"{language['code']}.json"
    if not path.exists():
        raise BuildError(f"Missing {path.relative_to(ROOT)}")
    data = json.loads(path.read_text(encoding="utf-8"))
    keys = set(flatten(data))
    missing = sorted(english_keys - keys)
    if missing:
        raise BuildError(f"{path.relative_to(ROOT)} is missing: {', '.join(missing)}")

    def wrap(value: Any) -> Any:
        # Locale text is ours and may contain HTML, so it is trusted markup.
        if isinstance(value, dict):
            return {k: wrap(v) for k, v in value.items() if not k.startswith("_")}
        return Markup(value)

    return wrap(data)


def app_text(language: dict) -> Callable[..., str]:
    """Looks up text in the app's own translations (Course and Localizable tables)."""
    folder = APP_STRINGS / f"{language['code']}.lproj"
    tables = {name: read_strings(folder / f"{name}.strings") for name in ("Course", "Localizable")}

    def lookup(key: str, table: str = "Course") -> str:
        if key not in tables[table]:
            raise BuildError(f"{folder.relative_to(ROOT)}/{table}.strings has no translation of {key!r}")
        return tables[table][key]

    return lookup


def page_url(language: dict, page: str) -> str:
    return BASE_URL + language["path"] + ("" if page == "index.html" else page)


def plain(value) -> Markup:
    """Text for an attribute: tags removed, everything escaped."""
    return escape(Markup(value).striptags())


def suggestions(page: str, current: dict) -> list:
    """What the language banner offers, in each other language, for this page."""
    result = []
    for language in LANGUAGES:
        if language is current:
            continue
        locale = json.loads((SITE / "locales" / f"{language['code']}.json").read_text(encoding="utf-8"))
        href = ("../" if current["path"] else "") + language["path"] + ("" if page == "index.html" else page)
        result.append({
            "tag": language["tag"],
            "href": href or "./",
            "text": locale["common"]["suggest_link"],
            "close": locale["common"]["suggest_close"],
        })
    return result


def check_links(folder: Path) -> list:
    problems = []
    for page in folder.rglob("*.html"):
        html = page.read_text(encoding="utf-8")
        for ref in re.findall(r'(?:src|href)="([^"#:?]+)(?=["#?])', html):
            target = folder / ref.lstrip("/") if ref.startswith("/") else page.parent / ref
            if not target.exists():
                problems.append(f"{page.relative_to(folder)}: missing {ref}")
    return problems


def build() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    shutil.copytree(SITE, OUT, ignore=shutil.ignore_patterns("templates", "locales", ".DS_Store"))

    english_keys = set(flatten(json.loads((SITE / "locales" / "en.json").read_text(encoding="utf-8"))))
    env = Environment(
        loader=FileSystemLoader(SITE / "templates"),
        autoescape=True,
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
    )
    env.filters["plain"] = plain
    env.filters["n"] = lambda text, number: Markup(str(text).replace("{n}", str(number)))
    env.globals.update(languages=LANGUAGES, english=ENGLISH, url=page_url)

    for language in LANGUAGES:
        t = load_locale(language, english_keys)
        text = app_text(language)
        units = [
            {"title": text(title), "summary": text(summary), "lessons": count}
            for title, summary, count in UNITS
        ]
        levels = [
            {"name": text(level, "Localizable"), "songs": [{"title": text(s), "credit": text(c)} for s, c in songs]}
            for level, songs in SONG_LEVELS
        ]
        folder = OUT / language["path"]
        folder.mkdir(parents=True, exist_ok=True)
        for page in PAGES:
            html = env.get_template(page).render(
                t=t,
                lang=language,
                page=page,
                root="../" if language["path"] else "",
                units=units,
                levels=levels,
                suggestions=suggestions(page, language),
            )
            (folder / page).write_text(html, encoding="utf-8")

    # GitHub Pages serves one 404 page for the whole site; it picks its language in the browser.
    not_found = {}
    for language in LANGUAGES:
        locale = json.loads((SITE / "locales" / f"{language['code']}.json").read_text(encoding="utf-8"))
        not_found[language["tag"]] = {**locale["notfound"], "path": language["path"]}
    t = load_locale(ENGLISH, english_keys)
    (OUT / "404.html").write_text(env.get_template("404.html").render(t=t, lang=ENGLISH, strings=not_found), encoding="utf-8")

    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for page in PAGES:
        for language in LANGUAGES:
            lines.append(f"  <url>\n    <loc>{xml_escape(page_url(language, page))}</loc>")
            for alternate in LANGUAGES:
                lines.append(f'    <xhtml:link rel="alternate" hreflang="{alternate["tag"]}" href="{xml_escape(page_url(alternate, page))}"/>')
            lines.append(f'    <xhtml:link rel="alternate" hreflang="x-default" href="{xml_escape(page_url(ENGLISH, page))}"/>')
            lines.append("  </url>")
    lines.append("</urlset>")
    (OUT / "sitemap.xml").write_text("\n".join(lines) + "\n", encoding="utf-8")

    problems = check_links(OUT)
    if problems:
        raise BuildError("Broken links:\n  " + "\n  ".join(problems))
    print(f"Built {len(LANGUAGES)} languages × {len(PAGES)} pages into {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        LANGUAGES[:] = [language for language in LANGUAGES if language["code"] in sys.argv[1:] or language is ENGLISH]
    try:
        build()
    except BuildError as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)

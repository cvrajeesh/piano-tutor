#!/usr/bin/env python3
"""Checks translations against the English source files, for the app and the website.

    python3 scripts/check-translations.py          # every language
    python3 scripts/check-translations.py fr de    # just these

For each language it checks that the app's .strings and .stringsdict files and the
website's locales/<language>.json have every English key and no others, that no
translation is empty, and that placeholders (%@, %lld, %1$@, {n}) and HTML tags are kept.
`swift test` runs the same checks on the app's files. See docs/localization.md.
"""

import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "Sources/PianoTutor/Resources"
LOCALES = ROOT / "site/locales"
LANGUAGES = ["es", "fr", "de", "it", "pt-BR", "ja", "zh-Hans", "ko"]
TABLES = ["Localizable", "Course", "InfoPlist"]


def strings(path: Path) -> dict:
    """Reads a .strings file with plutil, which accepts exactly what the system accepts."""
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)], capture_output=True, text=True)
    if out.returncode != 0:
        raise ValueError(out.stderr.strip() or out.stdout.strip())
    return json.loads(out.stdout)


def printf_specs(text: str) -> list:
    return sorted(m for m in re.findall(r"%(?:\d+\$)?(lld|ld|d|@|f)", text))


def braces(text: str) -> list:
    return sorted(re.findall(r"\{[a-z]+\}", text))


def tags(text: str) -> list:
    return sorted(re.findall(r"</?[a-z]+\b[^>]*>", text))


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


def check(language: str) -> list:
    problems = []
    for table in TABLES:
        path = RES / f"{language}.lproj/{table}.strings"
        try:
            english = strings(RES / f"en.lproj/{table}.strings")
            translated = strings(path)
        except (ValueError, FileNotFoundError) as error:
            problems.append(f"{path.relative_to(ROOT)}: {error}")
            continue
        for key in sorted(set(english) - set(translated)):
            problems.append(f"{table}: missing {key!r}")
        for key in sorted(set(translated) - set(english)):
            problems.append(f"{table}: unknown key {key!r}")
        for key, value in translated.items():
            if not value.strip():
                problems.append(f"{table}: empty {key!r}")
            if key in english and printf_specs(value) != printf_specs(english[key]):
                problems.append(f"{table}: placeholders differ in {key!r}")
            if len(printf_specs(value)) > 1 and re.search(r"%(lld|@)", value):
                problems.append(f"{table}: number the placeholders (%1$@, %2$lld) in {key!r}")

    path = RES / f"{language}.lproj/Localizable.stringsdict"
    try:
        english = plistlib.loads((RES / "en.lproj/Localizable.stringsdict").read_bytes())
        plurals = plistlib.loads(path.read_bytes())
        if set(plurals) != set(english):
            problems.append(f"Localizable.stringsdict: keys differ from English")
        for key, entry in plurals.items():
            for rule in entry.values():
                if isinstance(rule, dict) and "other" not in rule:
                    problems.append(f"Localizable.stringsdict: {key!r} has no 'other' form")
    except Exception as error:  # noqa: BLE001 - report any parse problem
        problems.append(f"{path.relative_to(ROOT)}: {error}")

    path = LOCALES / f"{language}.json"
    try:
        english = flatten(json.loads((LOCALES / "en.json").read_text()))
        translated = flatten(json.loads(path.read_text()))
    except (ValueError, FileNotFoundError) as error:
        problems.append(f"{path.relative_to(ROOT)}: {error}")
        return problems
    for key in sorted(set(english) - set(translated)):
        problems.append(f"site: missing {key}")
    for key in sorted(set(translated) - set(english)):
        problems.append(f"site: unknown key {key}")
    for key, value in translated.items():
        if key not in english:
            continue
        if not value.strip() and english[key].strip():
            problems.append(f"site: empty {key}")
        if braces(value) != braces(english[key]) and key != "privacy.translation_note":
            problems.append(f"site: placeholders differ in {key}")
        if tags(value) != tags(english[key]) and key != "privacy.translation_note":
            problems.append(f"site: HTML tags differ in {key}")
    if not translated.get("privacy.translation_note", "").strip():
        problems.append("site: privacy.translation_note is needed in every translation")
    return problems


def main() -> int:
    languages = sys.argv[1:] or LANGUAGES
    failed = False
    for language in languages:
        problems = check(language)
        print(f"{language}: {'OK' if not problems else f'{len(problems)} problem(s)'}")
        for problem in problems:
            print(f"  {problem}")
        failed = failed or bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

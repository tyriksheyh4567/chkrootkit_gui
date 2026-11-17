"""Validate the requested release version and extract its changelog section."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def release_notes(version: str, pubspec: str, changelog: str) -> str:
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?', version):
        raise ValueError('Version must be a semantic version without a v prefix.')
    match = re.search(r'^version:\s*([^+\s]+)', pubspec, re.M)
    if not match or match[1] != version:
        raise ValueError('Version does not match pubspec.yaml.')
    match = re.search(r'^## \[' + re.escape(version) + r'\][^\n]*\n(.*?)(?=^## \[|\Z)', changelog, re.M | re.S)
    if not match or not match[1].strip():
        raise ValueError('No nonempty changelog section for this version.')
    return match[1].strip() + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('version')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/release-notes.md')
    args = parser.parse_args()
    try:
        notes = release_notes(args.version, (ROOT / 'pubspec.yaml').read_text(), (ROOT / 'CHANGELOG.md').read_text())
    except ValueError as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(notes)

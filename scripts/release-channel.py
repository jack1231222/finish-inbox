#!/usr/bin/env python3
"""Fail closed before building historical source for a release tag."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
LEGACY_TAG = re.compile(r"v(0\.1\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?)\Z")


def validate(tag: str, root: Path = ROOT) -> str:
    if '-free' in tag or not (match := LEGACY_TAG.fullmatch(tag)):
        raise ValueError('Only historical v0.1.* source tags are allowed; Free releases are binary-only.')
    version = match.group(1)
    source = (root / 'Sources/FinishInbox/Version.swift').read_text()
    declared = re.findall(r'^\s*static let current = "([^"]+)"\s*$', source, re.MULTILINE)
    if declared != [version]:
        raise ValueError('Tag version must exactly match the historical source version; never relabel old source as Free.')
    if not (root / 'docs/releases' / (tag + '.md')).is_file():
        raise ValueError('Historical release notes must exist before building.')
    return version


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('Usage: release-channel.py <tag>')
        print(validate(sys.argv[1]))
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)

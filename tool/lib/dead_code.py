#!/usr/bin/env python3
"""List declarations in lib/ that nothing references.

Dead code is not a style problem, it is a reading problem: every file is a
place a future change has to look, and a widget that is never instantiated
cannot be distinguished from one that is, by anything except grepping for it.
On a tree this size that is several hundred searches nobody will do.

What counts as a reference, precisely:

  * A use in any file under lib/ or test/.
  * The declaration line and the constructor signature are NOT uses.
    Otherwise every class references itself and the report is empty.

Extensions are deliberately excluded. `extension AppColorsX` is reached as
`context.someGetter` — the extension's own name never appears at the call
site, so counting name occurrences reports every extension in the project as
dead. That false positive made the first version of this script useless, and
it would be worse in CI than no script at all.

Usage:
    python3 tool/lib/dead_code.py            # human-readable report
    python3 tool/lib/dead_code.py --paths    # tab-separated, for diffing
"""

from __future__ import annotations

import os
import re
import sys

DECL = re.compile(r"^\s*(?:abstract\s+)?(class|enum|mixin)\s+([A-Z][A-Za-z0-9_]*)\b")


def _sources() -> dict[str, str]:
    src: dict[str, str] = {}
    for base in ("lib", "test"):
        for root, dirs, files in os.walk(base):
            if "generated" in root:
                continue
            for name in files:
                if name.endswith(".dart"):
                    path = os.path.join(root, name)
                    with open(path, encoding="utf-8") as handle:
                        src[path] = handle.read()
    return src


def _not_a_use(line: str, name: str) -> bool:
    """True for the declaration line and the constructor signature."""
    escaped = re.escape(name)
    decl = re.match(r"^\s*(?:abstract\s+)?(?:class|enum|mixin)\s+" + escaped + r"\b", line)
    ctor = re.match(r"^\s*(?:const\s+|factory\s+)" + escaped + r"\s*[.(]", line)
    return bool(decl or ctor)


def main(argv: list[str]) -> int:
    paths_only = "--paths" in argv[1:]
    src = _sources()

    dead: list[tuple[str, str, str]] = []
    for path, text in src.items():
        if not path.startswith("lib"):
            continue
        for line in text.splitlines():
            match = DECL.match(line)
            if not match:
                continue
            kind, name = match.group(1), match.group(2)
            word = re.compile(r"\b" + re.escape(name) + r"\b")
            uses = 0
            for other, other_text in src.items():
                for other_line in other_text.splitlines():
                    if not word.search(other_line):
                        continue
                    if other == path and _not_a_use(other_line, name):
                        continue
                    uses += 1
            if uses == 0:
                dead.append((path, kind, name))

    dead.sort()
    if paths_only:
        for path, _, name in dead:
            print(f"{path}\t{name}")
    else:
        for path, kind, name in dead:
            print(f"{path}\t{kind} {name}")
        print(f"--- {len(dead)} declaration(s) with zero references ---")
        if dead:
            print(
                "Extensions are not scanned; see the module docstring for why.\n"
                "Deleting any of these is safe with respect to the build — a\n"
                "file nothing imports cannot break anything — but it is still a\n"
                "decision about whether the component is wanted back."
            )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
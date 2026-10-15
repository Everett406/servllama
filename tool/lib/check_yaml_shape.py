#!/usr/bin/env python3
"""A narrow structural check for the hand-edited workflow files.

This is not a YAML parser and does not pretend to be one. Full YAML needs a
library, and this machine cannot install one. What it does check is the set
of mistakes that actually happen when someone inserts a step into a workflow
by hand, because every one of them has bitten a real pipeline at some point:

  tab-indent    YAML forbids tabs for indentation, and the error it raises
                names a line that has nothing to do with the real cause.
  duplicate-key Two identical keys inside one mapping. The second silently
                wins, so a step can disappear without a trace.

Two mapping-level rules, and both need the real nesting rather than the
indentation width: a step's `uses` sits at indent 6 while its `with:` sits at
8, and the *next* step's `uses:` is back at 6. Grouping by width alone makes
every key in the file look like a sibling of every other key at the same
width, which reports dozens of false positives and is worse than no checker.

Calibration: a clean report on the workflows already in the tree is evidence
this checker understands the files it reads. It is not evidence they are
correct.

Usage:
    python3 tool/lib/check_yaml_shape.py
"""

from __future__ import annotations

import os
import re
import sys

WORKFLOWS = ".github/workflows"
# A mapping key: optionally preceded by a sequence dash, then a bare name.
KEY = re.compile(r"^\s*(?:-\s+)?([A-Za-z0-9_.\-]+)\s*:(?:\s|$)")
# A step list marker on its own.
DASH = re.compile(r"^\s*-\s*(?=\S)")
# `run: |` and friends introduce a literal block: indentation inside it is
# content, not structure, and must not be interpreted as keys.
BLOCK = re.compile(r"^\s*(?:-\s+)?[A-Za-z0-9_.\-]+\s*:\s*[|>][-+]?\s*$")


class Frame:
    __slots__ = ("indent", "keys")

    def __init__(self, indent: int) -> None:
        self.indent = indent
        self.keys: set[str] = set()


def check(path: str) -> list[str]:
    problems: list[str] = []
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    stack: list[Frame] = []
    in_block = False
    block_indent = 0

    for number, raw in enumerate(lines, start=1):
        if raw[: len(raw) - len(raw.lstrip())].count("\t"):
            problems.append(f"{path}:{number}: tab used for indentation")
            continue

        if not raw.strip() or raw.lstrip().startswith("#"):
            # A blank or comment line inside a literal block is content; it
            # must not end the block. Only a less-indented line does.
            continue

        indent = len(raw) - len(raw.lstrip(" "))

        if in_block:
            if indent > block_indent:
                continue
            in_block = False

        dash = DASH.search(raw)
        if dash:
            # A sequence item opens a new mapping. Two steps at the same
            # indentation each have their own `name:`, `run:`, `with:` — if
            # they shared a frame, every multi-step workflow would report
            # each of its steps as duplicating the previous one. The item's
            # content starts after the dash, and that is where its keys live.
            content_indent = dash.end()
            while stack and stack[-1].indent >= content_indent:
                stack.pop()
            stack.append(Frame(content_indent))
        else:
            # Pop only *deeper* frames. Popping at `>=` would discard the
            # frame at this exact indentation, and with it the set of
            # siblings that makes duplicate detection work.
            while stack and stack[-1].indent > indent:
                stack.pop()
            if not stack or stack[-1].indent != indent:
                stack.append(Frame(indent))
        frame = stack[-1]

        if BLOCK.match(raw):
            in_block = True
            block_indent = indent
            continue

        if DASH.match(raw):
            # A sequence item is a value, not a mapping key, unless the key
            # regex matches it, which is handled below.
            pass

        match = KEY.match(raw)
        if not match:
            continue
        key = match.group(1)
        if key in frame.keys:
            problems.append(
                f"{path}:{number}: duplicate key '{key}' in the same mapping "
                f"(indent {indent})"
            )
        frame.keys.add(key)

    return problems


def main() -> int:
    if not os.path.isdir(WORKFLOWS):
        print(f"{WORKFLOWS} not found; nothing to check")
        return 0
    found: list[str] = []
    checked = 0
    for name in sorted(os.listdir(WORKFLOWS)):
        if not name.endswith((".yml", ".yaml")):
            continue
        checked += 1
        found.extend(check(os.path.join(WORKFLOWS, name)))
    for problem in found:
        print(problem)
    print(f"--- checked {checked} workflow file(s), {len(found)} problem(s) ---")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
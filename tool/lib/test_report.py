#!/usr/bin/env python3
"""Turn `flutter test --reporter=json` output into a per-file failure count.

Why a separate step at all: the number that matters is not "how many tests
failed" but "how many failures are new". HANDOFF records 21 pre-existing
failures spread over four files; a run that produces 21 again is not a run
that broke anything, and a run that produces 22 is. Comparing the total
cannot tell those apart, so the report is keyed by file.

Emits `path<TAB>count` lines, sorted, for `known_test_failures.txt`.

Usage:
    flutter test --reporter=json | python3 tool/lib/test_report.py
"""

from __future__ import annotations

import json
import os
import sys
from collections import defaultdict

# The root the JSON `url` fields are absolute under. Anything that cannot be
# made relative to it is reported under its raw path rather than dropped: a
# failure nobody can attribute is worse than an ugly path.
def _repo_root() -> str:
    # tool/lib/test_report.py -> tool/lib -> tool -> repo root
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _relative(url: str) -> str:
    if url.startswith("file://"):
        url = url[len("file://"):]
    # Anchored on the `test/` segment rather than on the repository root.
    # The root that `__file__` resolves to and the root baked into the
    # reporter's URLs disagree whenever the checkout sits behind a symlink,
    # a bind mount or a CI workspace path, and a prefix match then silently
    # yields `some/absolute/path/test/foo_test.dart` as the key — which
    # compares unequal to the baseline entry for the very same file. Test
    # files always live under `test/`, so that segment is the stable one.
    marker = "/test/"
    index = url.rfind(marker)
    if index != -1:
        return url[index + 1:]
    if url.startswith("test/"):
        return url
    root = _repo_root()
    if url.startswith(root + os.sep):
        return url[len(root) + 1:]
    return url.lstrip("/")


def main() -> int:
    failures: dict[str, int] = defaultdict(int)
    # testID -> (name, relative url). The `testStart` event for a failing
    # test is not guaranteed to arrive before we care about it, so the whole
    # stream is read before anything is counted.
    started: dict[int, tuple[str, str]] = {}

    for line in sys.stdin:
        line = line.strip()
        if not line.startswith("{"):
            # `flutter test` mixes human-readable lines into stdout even in
            # json mode. Skip them rather than dying on one.
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        kind = event.get("type")
        if kind == "testStart":
            test = event.get("test") or {}
            test_id = test.get("id")
            if test_id is None:
                continue
            started[test_id] = (
                test.get("name", ""),
                _relative(test.get("url", "")),
            )
        elif kind == "testDone":
            if event.get("result") != "failure":
                continue
            # `hidden` is the implicit per-file loading suite. It is not a
            # test a human wrote and it does not fail on its own.
            if event.get("hidden"):
                continue
            test_id = event.get("testID")
            name, url = started.get(test_id, ("<unknown>", "<unknown>"))
            if not url or url == "<unknown>":
                # A failure we cannot attribute to a file still has to fail
                # the run. Counting it under a sentinel keeps it visible
                # instead of silently disappearing from the count.
                url = "<unattributed>"
            del name
            failures[url] += 1

    for path in sorted(failures):
        print(f"{path}\t{failures[path]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
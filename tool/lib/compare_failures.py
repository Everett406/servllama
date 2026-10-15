#!/usr/bin/env python3
"""Compare a test_report.py run against the known-failure baseline.

Three outcomes matter, and they are deliberately not the same verdict:

  * a file that fails more than the baseline allows  -> REGRESSION
  * a file that is not in the baseline at all         -> NEW
  * a file that fails *less* than the baseline        -> IMPROVED

"Less" is reported but does not fail the run. That asymmetry is the point: a
suite getting healthier must not require editing the baseline in the same
commit as the code, or the habit forms of editing the baseline whenever the
suite is inconvenient.

Usage:
    compare_failures.py <report> <baseline>
    compare_failures.py <report> <baseline> --update
"""

from __future__ import annotations

import sys


def read_baseline(path: str) -> dict[str, int]:
    baseline: dict[str, int] = {}
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t") if "\t" in line else line.split()
            if len(parts) != 2:
                continue
            try:
                baseline[parts[0]] = int(parts[1])
            except ValueError:
                continue
    return baseline


def read_report(path: str) -> dict[str, int]:
    report: dict[str, int] = {}
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            parts = line.split("\t") if "\t" in line else line.split()
            if len(parts) != 2:
                continue
            try:
                report[parts[0]] = int(parts[1])
            except ValueError:
                continue
    return report


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if a != "--update"]
    update = "--update" in argv[1:]
    if len(args) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    report_path, baseline_path = args
    baseline = read_baseline(baseline_path)
    report = read_report(report_path)

    regressions: list[str] = []
    fresh: list[str] = []
    improved: list[str] = []

    for path in sorted(report):
        count = report[path]
        if path not in baseline:
            fresh.append(f"  NEW       {path} ({count} failing)")
        elif count > baseline[path]:
            regressions.append(
                f"  REGRESSED {path} ({count} failing, baseline allows {baseline[path]})"
            )
        elif count < baseline[path]:
            improved.append(
                f"  IMPROVED  {path} ({count} failing, baseline had {baseline[path]})"
            )

    for path in sorted(set(baseline) - set(report)):
        improved.append(f"  FIXED     {path} (baseline had {baseline[path]}, now 0)")

    if update:
        with open(baseline_path, "w", encoding="utf-8") as handle:
            for path in sorted(report):
                handle.write(f"{path}\t{report[path]}\n")
        print("baseline rewritten from this run")
        for line in improved:
            print(line)
        return 0

    total_report = sum(report.values())
    total_baseline = sum(baseline.values())
    print(f"failing now: {total_report}   baseline: {total_baseline}")

    for line in regressions:
        print(line)
    for line in fresh:
        print(line)
    for line in improved:
        print(line)

    if regressions or fresh:
        print(
            "\nFAIL — the suite is worse than it was. A count above the "
            "baseline is a regression until proven otherwise; check whether "
            "the test or the code moved before touching the baseline."
        )
        return 1

    if improved:
        print(
            "\nPass, and better than the baseline. Refresh it with "
            "`tool/verify.sh --update` so the next run compares against "
            "reality rather than against history."
        )
        return 0

    print("\nPASS — same failures as the baseline, nothing new.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
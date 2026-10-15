#!/usr/bin/env bash
# Layering and single-source-of-truth guards, as plain grep.
#
# AGENTS.md states these rules as prose, which means they were true of whoever
# last read them and of nobody else. A rule nobody can run is a comment. These
# are the ones that are cheap to check and expensive to discover you broke:
#
#   pages-no-io      A page doing its own I/O is the layering violation
#                    AGENTS.md calls out first, and the one that turns a
#                    widget change into an Android-permission problem.
#   core-no-features lib/core/ is meant to be shared foundation. It importing
#                    a feature inverts the dependency direction, and once one
#                    file does it the whole "core is foundational" claim
#                    stops meaning anything.
#   shared-no-features
#                    lib/shared/ holding feature logic is how a "reusable"
#                    component stops being reusable.
#   version-single-source
#                    pubspec.yaml is the only place a version may live.
#                    A literal in android/ is a second source that will
#                    disagree with the first.
#
# Output is `path<TAB>count`, the same shape as test_report.py, so the same
# comparator checks it. Existing violations are baselined rather than
# forbidden: the point is to catch the *next* one, not to pretend the codebase
# has never had any.
#
# Usage:
#   tool/check_architecture.sh                    # compare against the baseline
#   tool/check_architecture.sh --all              # raw list, baselined ones too
#   tool/check_architecture.sh --emit-report FILE # write `path<TAB>count`
#
# Default is the comparison, not the raw list. A guard that exits non-zero for
# problems this repository has knowingly kept for six months is a guard
# everyone learns to ignore, and then it catches nothing.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

emit_report=false
show_all=false
for arg in "$@"; do
  case "$arg" in
    --emit-report) emit_report=true ;;
    --all) show_all=true ;;
  esac
done

violations=""

# Adds "<path>\t<count>" once per file that has at least one match.
record() {
  local rule_label="$1" file="$2" count="$3"
  [ "$count" -eq 0 ] && return 0
  # Echo to the caller through stdout; bash cannot return strings.
  echo "$file	$count"
}

# --- pages-no-io -----------------------------------------------------------
# lib/app/ is included: a route or scaffold that opens a file is the same
# violation wearing a different hat.
while IFS= read -r file; do
  n=$(grep -c "^import 'dart:io';" "$file" 2>/dev/null || true)
  [ "${n:-0}" -gt 0 ] && violations+=$(record pages-no-io "$file" "$n")$'\n'
done < <(find lib/features/*/pages lib/app -name '*.dart' 2>/dev/null | sort)

# --- core-no-features ------------------------------------------------------
while IFS= read -r file; do
  n=$(grep -cE "^import 'package:servllama/(features|app)/" "$file" 2>/dev/null || true)
  [ "${n:-0}" -gt 0 ] && violations+=$(record core-no-features "$file" "$n")$'\n'
done < <(find lib/core -name '*.dart' 2>/dev/null | sort)

# --- shared-no-features ---------------------------------------------------
while IFS= read -r file; do
  n=$(grep -cE "^import 'package:servllama/features/" "$file" 2>/dev/null || true)
  [ "${n:-0}" -gt 0 ] && violations+=$(record shared-no-features "$file" "$n")$'\n'
done < <(find lib/shared -name '*.dart' 2>/dev/null | sort)

# --- version-single-source -------------------------------------------------
# `versionCode = flutter.versionCode` is the correct form and is not matched:
# the pattern below requires a bare integer or string literal on the right.
while IFS= read -r file; do
  n=$(grep -cE "version(Code|Name)[[:space:]]*=[[:space:]]*[0-9]" "$file" 2>/dev/null || true)
  [ "${n:-0}" -gt 0 ] && violations+=$(record version-single-source "$file" "$n")$'\n'
done < <(find android -name '*.kts' -o -name '*.gradle' 2>/dev/null | sort)

if $emit_report; then
  next_arg=0
  for arg in "$@"; do
    if [ "$next_arg" = 1 ]; then report_path="$arg"; break; fi
    [ "$arg" = "--emit-report" ] && next_arg=1
  done
  printf '%s' "$violations" | grep -v '^$' | sort > "$report_path"
  exit 0
fi

current="$(printf '%s' "$violations" | grep -v '^$' | sort)"

if [ -z "${current//[$'\n' ]/}" ]; then
  echo "architecture: no violations at all"
  exit 0
fi

if $show_all; then
  echo "$current"
  exit 1
fi

# Default: judge against the baseline, and keep the known ones visible but
# clearly marked, so "2 known" never reads like "2 problems".
report="$(mktemp)"
printf '%s\n' "$current" > "$report"
trap 'rm -f "$report"' EXIT

echo "known, baselined in tool/known_architecture_violations.txt:"
grep -F -x -f tool/known_architecture_violations.txt "$report" | sed 's/^/  /' || true

known_count=$(grep -cF -x -f tool/known_architecture_violations.txt "$report" 2>/dev/null || echo 0)

fresh="$(grep -F -x -v -f tool/known_architecture_violations.txt "$report" 2>/dev/null || true)"
if [ -n "${fresh//[$'\n' ]/}" ]; then
  echo
  echo "NEW — not in the baseline:"
  printf '%s\n' "$fresh" | sed 's/^/  /'
  echo
  echo "architecture: FAILED. Move the code, or accept the violation and add"
  echo "it to tool/known_architecture_violations.txt with a reason."
  exit 1
fi

echo
echo "architecture: ${known_count} known violation(s), nothing new."
exit 0
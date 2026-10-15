#!/usr/bin/env bash
# The one command that answers "is this safe to ship?".
#
# Before this existed the answer was: run flutter analyze, run flutter test,
# eyeball the list of failures against a number you remember from a document,
# and hope. The eyeballing is the weak link — 21 failures and 23 failures look
# identical unless you read every line, and the person most likely to introduce
# the 22nd is the person who is also the one running the suite at midnight.
#
# So: two machine checks, each compared against a baseline of what is already
# known, each failing only on what is NEW.
#
#   1. flutter analyze must report zero issues.
#   2. flutter test must fail no more than the baseline allows, per file.
#   3. The layering guards in check_architecture.sh must not have regressed.
#
# Usage:
#   tool/verify.sh              full check
#   tool/verify.sh --fast       skip the test suite, run 1 and 3
#   tool/verify.sh --update     rewrite the baselines from this run
#   tool/verify.sh --no-tests   alias for --fast, for muscle memory
#
# Exit code is 0 only when every check passed.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

UPDATE=false
RUN_TESTS=true
for arg in "$@"; do
  case "$arg" in
    --update) UPDATE=true ;;
    --fast|--no-tests) RUN_TESTS=false ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

failures=0
note() { printf '\n=== %s ===\n' "$1"; }
record_failure() { failures=$((failures + 1)); }

command -v flutter > /dev/null 2>&1 || {
  cat >&2 <<'EOF'
flutter is not on PATH.

That is expected in a container that only has the source tree. The parts of
this that do not need Flutter still run:

    tool/check_architecture.sh
EOF
  exit 127
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- 0. workflow shape ----------------------------------------------------
# Before anything else, because a malformed workflow is the one failure that
# stops every other check from running at all.
note "workflow shape"
python3 tool/lib/check_yaml_shape.py || record_failure

# --- 1. analyze ------------------------------------------------------------
note "flutter analyze"
analyze_out="$WORK/analyze.txt"
if flutter analyze > "$analyze_out" 2>&1; then
  # `flutter analyze` exits 0 on "no issues" *and* on some warning-only
  # configurations, so the text is checked rather than trusted.
  if grep -qE '^[[:space:]]*(No issues found|.*0 (issue|problem)s? found)' "$analyze_out"; then
    echo "clean"
  elif [ -s "$analyze_out" ] && ! grep -qE '(info|warning|error)' "$analyze_out"; then
    echo "clean"
  else
    cat "$analyze_out"
    record_failure
  fi
else
  cat "$analyze_out"
  record_failure
fi

# --- 2. tests --------------------------------------------------------------
if $RUN_TESTS; then
  note "flutter test vs known_test_failures.txt"
  echo "this is the slow one; --fast skips it"
  raw="$WORK/test.jsonl"
  # --reporter=json because the human-readable reporter does not say which
  # *file* a failure belongs to, and per-file is the whole basis of the
  # comparison. Continue-on-error so one failing file does not hide the rest.
  if flutter test --reporter=json --concurrency=4 > "$raw" 2>"$WORK/test.err"; then
    :
  else
    # Non-zero is expected: the suite has known failures. The report is what
    # gets judged, not the exit code.
    echo "(test run exited non-zero, which is the documented state)"
  fi

  report="$WORK/report.tsv"
  python3 tool/lib/test_report.py < "$raw" > "$report"

  if python3 tool/lib/compare_failures.py "$report" \
      tool/known_test_failures.txt $([ "$UPDATE" = true ] && echo --update); then
    :
  else
    [ "$UPDATE" = true ] || record_failure
  fi
else
  note "flutter test"
  echo "skipped (--fast)"
fi

# --- 3. layering -----------------------------------------------------------
note "layering guards"
arch_report="$WORK/arch.tsv"
./tool/check_architecture.sh --emit-report "$arch_report" > /dev/null

if [ "$UPDATE" = true ]; then
  cp "$arch_report" /tmp/arch.new
  grep -v '^$' /tmp/arch.new > tool/known_architecture_violations.txt
  echo "architecture baseline rewritten"
else
  if python3 tool/lib/compare_failures.py "$arch_report" \
      tool/known_architecture_violations.txt; then
    :
  else
    record_failure
  fi
fi

# --- verdict --------------------------------------------------------------
note "result"
if [ "$failures" -eq 0 ]; then
  echo "all checks passed"
  exit 0
fi
echo "$failures check(s) failed"
exit 1
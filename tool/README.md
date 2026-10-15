# tool/

Machine checks for the things this repository currently only asks people to
remember.

## Why these exist

Every rule below was, until now, a sentence in `AGENTS.md` or `HANDOFF.md`.
That is a real way to hold a convention and a terrible way to hold a
constraint: it is true of whoever read it most recently, it is checked by
nobody, and the person most likely to break it is usually the person who is
already busy. The specific failure that motivated this directory is in
`HANDOFF.md` under *Recurring traps* — a correct layer tested one step short
of the screen it was supposed to reach. Nothing in the build could have said
so.

So each check takes a claim that used to live in prose and gives it an exit
code.

## Running everything

```bash
tool/verify.sh            # analyze + tests + layering + workflow shape
tool/verify.sh --fast     # skip the test suite
tool/verify.sh --update   # rewrite the baselines from this run
```

Runs in CI on every push and pull request (`.github/workflows/verify.yml`),
and again inside the release pipeline *before* the APK is built
(`.github/workflows/release.yml`). The release gate is the one that matters:
until now the pipeline built, signed and published an APK without ever
running the analyzer or the test suite.

## The baselines

Two files record what is already broken, so that each check is green today
and turns red only on something **new**:

| File | Holds |
| --- | --- |
| `known_test_failures.txt` | per-file failure counts, from `HANDOFF.md` at v1.27.0 |
| `known_architecture_violations.txt` | existing layering violations, measured |

Both are compared per file, never on the total. "21 failures" looks identical
whether nothing regressed or one file got worse while another got better;
counting by file distinguishes those two cases.

A file failing **less** than its baseline passes, and says so. It does not
require the baseline to be edited in the same commit as the code — that
asymmetry is deliberate, because a baseline you must update whenever the suite
is inconvenient is a baseline that gets rubber-stamped.

Removing a baselined violation is a win: delete its line in the same commit.

## The pieces

| File | Does |
| --- | --- |
| `verify.sh` | the entry point; needs `flutter` on PATH for the first and second checks |
| `lib/test_report.py` | `flutter test --reporter=json` → `path<TAB>count` |
| `lib/compare_failures.py` | a report against a baseline; same shape works for both baselines |
| `check_architecture.sh` | the layering guards, as plain grep |
| `lib/dead_code.py` | declarations in `lib/` that nothing references |
| `lib/check_yaml_shape.py` | structural check on `.github/workflows/*.yml` |

### Notes on the fiddly parts

**`test_report.py` anchors on `test/`, not on the repository root.** The root
that `__file__` resolves to and the root baked into the reporter's URLs
disagree whenever the checkout sits behind a symlink, a bind mount or a CI
workspace path. A prefix match then yields `some/absolute/path/test/foo.dart`
as the key, which compares unequal to the baseline entry for the same file —
the check silently stops meaning anything.

**`dead_code.py` skips extensions.** `extension AppColorsX` is reached as
`context.someGetter`; the extension's own name never appears at a call site.
Counting name occurrences reports every extension in the project as dead,
which is what the first version of this script did.

**`check_yaml_shape.py` is not a YAML parser** and does not claim to be. Full
YAML needs a library this machine cannot install. It checks the mistakes that
happen when a step is inserted by hand: tab indentation, and a duplicate key
inside one mapping. Both of those need real nesting rather than indentation
width — a step's `uses` sits at indent 6 while its `with:` sits at 8 — so
grouping by width alone reports dozens of false positives.

A clean report on the workflows already in the tree is evidence these checks
understand what they read. It is not evidence the files are correct.

## Without Flutter

`verify.sh` exits 127 if `flutter` is not on PATH, and says so. Everything
else runs:

```bash
tool/check_architecture.sh
python3 tool/lib/dead_code.py
python3 tool/lib/check_yaml_shape.py
```
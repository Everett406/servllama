# HANDOFF

What the state of this project actually is, as of **v1.27.0**.

This file exists so that whoever picks this up does not have to rediscover what was
verified and what was not — and, more importantly, does not claim something works when it
was never run on hardware.

Read `AGENTS.md` first for architecture and the rules changes are expected to follow.

---

## Where things stand

- **Latest release:** `v1.27.0` — https://github.com/Everett406/servllama/releases/tag/v1.27.0
- **Signed APK, 49,729 KB**, published by GitHub Actions after the native-library,
  signature and manifest gates pass.
- **`flutter analyze`: clean.** Zero issues.
- **Tests: 568 passing, 21 failing.** All 21 are pre-existing — see below.
- 183 Dart files, ~50,500 lines under `lib/`, 81 test files.
- 28 changelog entries, 55 git tags.

---

## The 21 known failures

All are stale tests, not live bugs. None were introduced by recent work.

| File | Count | Why |
| --- | --- | --- |
| `test/features/chat/pages/chat_page_test.dart` | 18 | Finds widgets by `Icons.menu` and asserts old copy like `选一个模型开始`. The UI was rewritten to `ClaudeIcons` and new copy back in v1.9.0 and the tests were never updated. |
| `test/core/services/server_launch_args_builder_test.dart` | 1 | — |
| `test/features/about/pages/about_page_test.dart` | 1 | — |
| `test/features/server/pages/server_page_test.dart` | 1 | — |

**This is undecided.** Fixing the `chat_page_test` file means rewriting assertions about
UI that was *deliberately* changed — one of them asserts an empty state that Vela
intentionally removed. Turning a stale assertion into a passing one by asserting the new
behaviour is fine; doing it silently would quietly ratify a design decision nobody made
deliberately. Ask before touching it.

---

## Unverified on hardware

### OpenCL and Hexagon — **no conclusion may be drawn**

Two accelerators are compiled and offered in the UI. Neither has been verified working on a
real device.

The blocking problem is that the release APK could never be downloaded intact. Every
attempt returned a truncated file (~2.6 MB, `BadZipFile`), so `lib/arm64-v8a/` has never
been unpacked and it has never been confirmed whether the shipped APK contains an NDK stub
`libOpenCL.so` instead of the real driver.

What is known, from a OnePlus Turbo 6 (Adreno 825):

- OpenCL: `ggml_opencl: platform IDs not available.`
- Hexagon: `/vendor/lib64/libcdsprpc.so: undefined symbol: android::binder2os::get_trace_enabled_tags()`

Both point at the same class of problem — a missing or mismatched vendor driver — but
that is an inference from two log lines, not a measurement.

**To close this out:** get the APK onto a device (sideload, or fetch it in a browser that
survives the download), then:

```bash
unzip -o vela.apk 'lib/arm64-v8a/*' -d extracted/
ls -la extracted/lib/arm64-v8a/
```

Look for `libOpenCL.so` and check whether it is the NDK stub (a few KB) or the real driver.

Until then, do not write in a README, a release note or a commit message that OpenCL or
Hexagon works, or that it does not.

### Everything else also wants a real device

The unit and widget tests are necessary and not sufficient. Specifically unverified on a
phone:

- Chinese per-character text reveal
- LaTeX rendering
- Table rounding and horizontal scroll
- The table placeholder not flickering
- The three tool switches, end to end
- The knowledge base: pick an embedding model from the library, import, index, retrieve

`flutter analyze` and `flutter test` do not catch tree-shaking problems. `IconData` built
at runtime is the classic example — 31 call sites silently rendered nothing and no test
failed.

---

## Deliberately not done

### Documents are `.md` and `.txt` only

PDF and DOCX parsing would pull in a heavy dependency and a lot of failure modes — scanned
PDFs, layout tables, encoding. Not worth it until someone asks for it.

### The calculator is not JavaScript

The user asked for a "JavaScript calculation tool". It is a **safe recursive-descent
interpreter with JS-shaped syntax**: `**` and `^` are right-associative, `let`/`const`/`var`
declare variables, `Math.sin()` and bare `sin()` both work, decimals and scientific notation
parse.

It is not `eval`. There is no object model, no property chain, no `require`, no
`globalThis`, no host method reachable. An unknown name is an error, never `0`. This was a
deliberate reading of the request: the *shape* of JavaScript, not the surface area of a
scripting host inside the app's process.

### Model capability labels do not filter tools

A model with no "supports tools" badge still gets offered `tools`. Whether it can call them
is the server's answer, not a label's. The label was wrong often enough to be useless.

### Tool loop capped at 4 rounds

A model that only calls tools and never answers is a bad outcome; the cap converts it into a
visible failure instead of an infinite loop.

---

## Recurring traps

Things that have actually cost time on this project.

**A correct layer above a disconnected layer.** v1.26.0 fixed the model-library scan,
wrote four passing unit tests, released, and reported the embedding picker as working. The
page never called the function it had tested. The tests were real; they just stopped one
layer short of the screen. When a user says a tap does nothing or a list is empty, check
that the data reaches the widget before assuming the widget is wrong.

**Text classification from a growing buffer is rarely monotone.** Judging "is this table
finished?" from the text flips twenty times over a reply, and each flip is a visible blink.
The splitter's close test was `endsWithNewline && end < lines.length` — and
`'a\n'.split('\n')` is `['a', '']`, so the newline being typed right then always looked like
the blank line that closes a table. Count settled *prefix length*, never block index; block
indices shift when blocks merge and split.

**`copyWith` methods read fields, not parameters.** `copyWith({bool? x})` whose body says
`x ?? this.x` is correct; a bare `x` inside the method body can silently read the field.
`ModelDescriptor` uses an `_unset` sentinel for this reason.

**`Transform.scale` anchors at the centre** by default, which moves an anchored menu. Pass
the anchor explicitly.

**A permanent `post-frame` loop never settles**, so `pumpAndSettle` hangs. This cost one
10-minute test timeout.

**`pubspec.yaml` is the only version source.** `versionCode`/`versionName` come from it.

**Do not upgrade an API just because a newer version is in the pub cache.** The version
constraint and the lock file are a contract. `gpt_markdown` is vendored at 1.3.0 rather
than 1.3.4 because 1.3.4 pulls `val_latex_flutter`, whose `SemanticsService.sendAnnouncement`
does not compile against Flutter 3.35.

**`FocusScope.of(context).unfocus()` is not enough for a `TextField`.** Use
`FocusManager.instance.primaryFocus?.unfocus()`.

---

## Two open questions

**1. The 18 stale `chat_page_test` failures.** Described above. Needs a decision.

**2. `AGENTS.md` is out of date in one place.** It says OpenCL is "compiled but not
offered". All three backends are in `ServerLaunchSettings.supportedLlamaCppBackends` as of
v1.27.0. Left alone deliberately: OpenCL's actual behaviour on hardware is unverified, and
editing the doc would imply the question was settled.

---

## Release checklist

1. Bump `version:` in `pubspec.yaml` — it is the only place.
2. Add a `CHANGELOG.md` entry written for the user, not the diff.
3. `flutter analyze` must be clean.
4. `flutter test` — only the 21 known failures above.
5. Commit, tag `vX.Y.Z`, push branch and tag.
6. Confirm the workflow reaches `completed / success`.
7. Confirm the release has both `servllama-X.Y.Z-release.apk` and `SHA256SUMS.txt`.

Release signing setup: `docs/SIGNING.md`.
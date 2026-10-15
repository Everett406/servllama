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
- **`flutter analyze`: clean.** Zero issues — as of whoever last ran it locally.
  Nothing ran it in CI until now; see "Nothing was checking any of this".
- **Tests: 568 passing, 21 failing.** All 21 are pre-existing — see below.
- 183 Dart files, ~50,500 lines under `lib/`, 81 test files.
- 28 changelog entries, 55 git tags.

### Uncommitted work in the tree

Three fixes and the `tool/` directory. **None of the code changes have been run
through `flutter analyze` or `flutter test`** — the machine they were written on
has no Flutter toolchain — so they are described here as what they are: read,
not verified.

- **Knowledge base could never index anything.** `EmbeddingServer` started its
  llama-server with `--pooling none` and then called `/v1/embeddings`, which the
  project's own vendored `llama-server-README.md` states "requires that the model
  uses a pooling different than type `none`". Every request was answered `400`,
  and the raw `DioException` was rendered as the document's subtitle. Now
  `--pooling mean`.
- **Two waiting indicators drew at once.** `PrefillOrb` and `ThinkingLine` both
  rendered during the prefill window. The comment justifying the orb said the
  thinking line "has nothing to put on screen in that window", which stopped
  being true when `ThinkingLine` gained its own waiting state. `prefill_orb.dart`
  deleted.
- **The breathing dot did not breathe.** `GenerationActivityDot` read
  `_scale.value` in `build` with no `AnimatedBuilder`, so a State that never
  rebuilds on a tick only changed size when something else forced one — roughly
  every few streamed characters. Read as a stutter between two sizes.

---

## The 21 known failures

All are stale tests, not live bugs. None were introduced by recent work.

They are now recorded in `tool/known_test_failures.txt` and compared
per-file by `tool/verify.sh`, so the count is no longer a number somebody has
to remember and eyeball against. See "Nothing was checking any of this" below.

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

**The last three are a weaker claim than they look.** The "why" column is empty for
them, which means nobody recorded why they fail. `server_launch_args_builder_test.dart`
was read line by line against `server_launch_args_builder.dart` and `server_launch_settings.dart`
— `defaultCpuThreads`, `defaultLlamaCppGpuLayers`, the `GPUOpenCL`/`HTP0` fallbacks all
match what the code produces. That failure cannot be explained as a stale assertion,
and it has not been run since. "All 21 are stale" is therefore established for 18 of
them and assumed for 3. One of those three may be a live bug.

---

## Nothing was checking any of this

Until this was added, **no workflow ran `flutter analyze` or `flutter test`**. The
release pipeline built, signed and published an APK without either. Everything the
release checklist above asks for was a promise made by a person to this document.

That is not a criticism of the pipeline — it was written to build an APK, and it does
that — but it means the numbers in this file were a snapshot from whenever someone last
ran a suite locally, with nothing keeping them true. It also means the *shape* of the
worst bug in *Recurring traps* was invisible: a unit test four layers from the screen
goes green, the release goes green, and the user still sees an empty list.

`tool/` now holds the checks, `verify.yml` runs them on every push, and `release.yml`
runs them before it builds. What is enforced:

- analyze must report zero issues
- no test file may fail more than its baseline allows, per file
- the layering rules in `AGENTS.md` that are cheap to check — pages not doing I/O,
  `core/` not importing `features/`, `shared/` not importing `features/`,
  `pubspec.yaml` being the only version source

Existing violations are baselined rather than forbidden, so the checks are green today
and red only on something new. Two exist:

| File | Violations | What it is |
| --- | --- | --- |
| `lib/core/providers/knowledge_base_provider.dart` | 7 | Lives in `core/` but owns the whole knowledge feature — `EmbeddingServer` (a child process), the store, the service, the index — plus chat's `builtin_tools`. AGENTS.md says `core/` is shared foundation and that the state layer must not own low-level resources. Both are false here. |
| `lib/shared/l10n/runtime_labels.dart` | 5 | Localisation labels built from downloads models and services. Means `lib/shared/` is not independent of a feature, so anything shared can acquire a downloads dependency transitively. |

Neither was fixed: both are refactors too large to verify without a Flutter toolchain,
and an unverifiable refactor is exactly the failure mode this project keeps paying for.

`python3 tool/lib/dead_code.py` also reports 12 declarations in `lib/` that nothing
references. Deleting any of them is safe with respect to the build — a file nothing
imports cannot break anything — but whether a superseded component is wanted back is a
judgement call, so they are listed rather than removed.

---

## Unverified on hardware

### OpenCL and Hexagon — the packaging question is now **answered**; the device question is not

**The APK was never unpacked because the download kept timing out.** Nothing truncated
the file: the egress path runs at 4–27 KB/s, so a 48.6 MB asset takes between half an hour
and three hours, and anyone who waited a few minutes got a partial file that failed to
unzip. That was read as a corrupt release.

`inspect-release-apk.yml` now answers it on a GitHub runner, where the download is fast.
Run against `v1.27.0`, it verified the asset against its published `SHA256SUMS.txt`, then
confirmed every extracted library against the CRC-32 in the archive manifest. **So what
follows is measured, not inferred.**

`lib/arm64-v8a/` contains 25 libraries. The accelerator ones:

| File | Bytes | What it is |
| --- | ---: | --- |
| `libggml-opencl.so` | 3,578,176 | ELF 64-bit ARM aarch64, stripped, BuildID `8e71cc44…` |
| `libggml-hexagon.so` | 899,240 | ELF 64-bit ARM aarch64, stripped |
| `libggml-htp-v73.so` | 769,620 | ELF 32-bit QUALCOMM DSP6 |
| `libggml-htp-v75.so` | 831,060 | ELF 32-bit QUALCOMM DSP6 |
| `libggml-htp-v79.so` | 851,612 | ELF 32-bit QUALCOMM DSP6 |
| `libggml-htp-v81.so` | 847,520 | ELF 32-bit QUALCOMM DSP6 |

**They are not NDK stubs.** A stub is a few kilobytes; these are hundreds of kilobytes to
megabytes, they are real ELF files, and the HTP kernels are genuinely Qualcomm DSP
binaries rather than arm64 objects. The question HANDOFF could not answer — stub or real
driver — is closed.

Two further facts that reframe the device failures:

- **`libOpenCL.so` is not in the APK, and should not be.** `libggml-opencl.so` lists it
  in `DT_NEEDED`, so it is resolved at load time, and the app puts `/vendor/lib64` and
  `/odm/lib64` on `LD_LIBRARY_PATH`. On Android the ICD is a vendor system library; apps
  do not bundle it. Its absence is correct, not a packaging gap.
- **`libllama-server.so` does not list any accelerator in `DT_NEEDED`.** The backends are
  loaded at runtime, so a device without them still starts a working CPU server.

What this does **not** establish: whether OpenCL or Hexagon works on any given phone.
That is hardware, and it is still open.

### The device failures are probably not Vela's fault

From a OnePlus Turbo 6 (Adreno 825):

- OpenCL: `ggml_opencl: platform IDs not available.`
- Hexagon: `/vendor/lib64/libcdsprpc.so: undefined symbol: android::binder2os::get_trace_enabled_tags()`

That first string is compiled **into the shipped `libggml-opencl.so`** — it is this
project's own backend reporting it. And it rules out one hypothesis: if `libOpenCL.so` were
missing or unloadable, the linker would fail on `DT_NEEDED` and the symptom would be a
`dlopen` error naming the library, not a message printed *after* `clGetPlatformIDs`
returned zero. So on that device the vendor ICD loaded and reported no platforms. That
points at the vendor OpenCL stack, not at what Vela ships.

The Hexagon line is a *vendor* library failing to load on a device whose vendor build does
not match the platform — a well-known class of Qualcomm/OnePlus problem, and again
nothing Vela packages.

Both readings are inferences from evidence, not measurements. To settle them, capture
`logcat` while starting the server on a device whose vendor stack is known-good, and read
what ggml_opencl actually enumerates.

### Fetching the APK elsewhere

Parallel `Range:` requests work, but **verify the SHA256, and do not trust the file
size.** A range fetcher that appends without checking that the response was `206` and
that `Content-Range` matches will produce an APK of *exactly* the advertised length whose
contents are wrong; its central directory still parses and still prints a completely
convincing library inventory. Two such files were produced here before the check was
added. Use `inspect-release-apk.yml` instead.

Both point at the same class of problem — a missing or mismatched vendor driver — but
that is an inference from two log lines, not a measurement. An NDK stub `libOpenCL.so`
is one candidate that unpacking the APK would settle.

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

## Open questions

**1. The 18 stale `chat_page_test` failures.** Described above. Needs a decision.

**2. A stale claim about `AGENTS.md` that was itself wrong.** This file used to say
`AGENTS.md` was out of date because it describes OpenCL as "compiled but not offered".
`AGENTS.md` says no such thing — it states that `supportedLlamaCppBackends` "currently
lists CPU, OpenCL and Hexagon", which is true. The note was kept for versions because the
hardware behaviour was unverified and editing the doc would imply the question was
settled; the actual question was settled differently, and the AGENTS.md text was already
correct. Corrected in both files.

**3. `EmbeddingClient.currentEmbeddingModelId` is never assigned.** Declared at
`knowledge_base_service.dart:82`, read once at line 39, written nowhere in `lib/` or
`test/`. Every `/v1/embeddings` request therefore sends `"model": ""`. It is almost
certainly not what caused the 400 described above — `embedding_server.dart` documents
that llama-server ignores the `model` field in single-model mode, and the README's own
example sends a model name (`GPT-4`) that certainly is not the loaded GGUF. But a field
that exists to carry a value and never does is a landmine: the day the server does
validate it, indexing stops for a reason nobody will remember. Left alone rather than
deleted, because which of the three fixes is right — assign it from `/v1/models`, send
the model path, or drop the field — depends on behaviour that has not been observed.

**4. The document error string is a raw `DioException`.** `addText` stores
`error: '$error'`, and the documents page renders it verbatim, which is why a 400 fills
the screen with `DioException [bad response] ... Read more about status codes at
https://developer.mozilla.org/...`. `knowledgeDocumentFailed` ("索引失败") exists in
both ARB files and is referenced by nothing, so the page never falls back to it. Not
fixed here because the surrounding module has six hard-coded English error strings that
violate the AGENTS.md rule about ARB, and fixing one line while leaving the pattern is
worse than fixing the pattern.

**5. `KnowledgeBaseProvider` is in the wrong layer.** `lib/core/providers/` importing
seven files from `lib/features/knowledge/` is baselined in
`tool/known_architecture_violations.txt` rather than fixed. Moving it under
`lib/features/knowledge/` is the obvious direction and is a large refactor; it was
deferred because it could not be checked without a Flutter toolchain.

---

## Release checklist

1. Run `tool/verify.sh`. Analyze must be clean and the test suite must fail no
   more than `tool/known_test_failures.txt` allows, per file. This is now the
   same command CI runs, and the release pipeline runs it before it builds.
2. Bump `version:` in `pubspec.yaml` — it is the only place.
3. Add a `CHANGELOG.md` entry written for the user, not the diff.
4. Commit, tag `vX.Y.Z`, push branch and tag.
5. Confirm the workflow reaches `completed / success`.
6. Confirm the release has both `servllama-X.Y.Z-release.apk` and `SHA256SUMS.txt`.

Steps 3–6 used to start at "run flutter analyze and read the failure list
against a number in this file". That step was the one most often skipped,
because eyeballing twenty-one failures to decide whether twenty-two is a
regression is not a thing anyone reliably does at midnight. `tool/verify.sh`
does it by comparison instead. See `tool/README.md`.

Release signing setup: `docs/SIGNING.md`.
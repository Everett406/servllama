# Changelog

All notable changes to this project are documented here.

This file is maintained from `1.3.0` onward. Releases before that are
tracked in the upstream repository's tag history; see
[Upstream](#upstream) for the fork relationship.

## Versioning

`pubspec.yaml` holds the single source of truth:

```yaml
version: 1.6.3+32
#        │ │    └─ build number, must strictly increase across releases
#        │ └────── semantic version, shown to users
#        └──────── major
```

`android/app/build.gradle.kts` reads `flutter.versionCode` and
`flutter.versionName`, so editing `pubspec.yaml` is enough — never touch
`versionCode`/`versionName` in the Gradle file directly.

Rules:

- **Major** — incompatible changes to the data model (Hive `typeId`
  values, persisted preference keys, the chat session format). A major
  bump means existing installs cannot upgrade in place.
- **Minor** — visible behaviour or appearance changes that keep stored
  data readable.
- **Patch** — fixes and internal work with no user-visible change.
- **Build number** — increments on every release, including rebuilds of
  the same version. Android refuses to install over an equal or lower
  one, so it must always go up.

Tags are `vX.Y.Z` (the `v` prefix is new in `1.3.0`; earlier tags omit
it). Tags and commits on `main` are SSH-signed — see
[Verifying a release](#verifying-a-release).

## [1.3.2] - 2026-10-11

### Fixed

- The release workflow failed to parse: a bare `grep SHA256:` was read as
  a YAML mapping key, and a column-0 heredoc terminator truncated the
  surrounding block scalar.
- The release build no longer uses `--split-per-abi`. The app pins
  `ndk.abiFilters` to `arm64-v8a` because the llama-server binaries are
  arm64-only, and Gradle rejects a split whose ABIs overlap an explicit
  filter.

## [1.3.1] - 2026-10-11

### Added

- Signed release workflow (`.github/workflows/release.yml`) that builds
  per-ABI APKs and attaches them to the GitHub release. Signing material
  lives in repository secrets and is materialised only for the build.

### Changed

- **The app now has its own identity.** `applicationId` moved from
  `com.arkanefans.servllama` to `com.everett406.servllama`, and the
  release is signed with a project-owned keystore rather than anything
  associated with the upstream project. Both the Android `namespace` and
  the three native method-channel names were moved with it — the Kotlin
  and Dart sides have to agree on those strings or every platform call
  silently fails.
- Release builds no longer fall back to debug signing when
  `android/key.properties` is absent; the workflow fails loudly instead.

## [1.3.0] - 2026-10-11

Complete UI rework onto a Claude-inspired design language. The engine
runtime, model storage, download queue and chat pipeline are unchanged.

### Added

- Design token layer (`lib/app/design/tokens.dart`): warm-neutral
  palette, single brick-orange accent, type scale, radius and motion
  scales.
- Shared page scaffold giving every secondary page the same title
  treatment and reading width.
- Session list grouped by recency (today / yesterday / 7 days / 30 days /
  older) shared by the sidebar and the history page.
- Collapsible chain-of-thought block in the transcript.

### Changed

- Sidebar rebuilt as flat text rows with a runtime status strip,
  replacing the boxed menu tiles.
- Chat transcript: assistant turns no longer sit in bubbles, so the
  answer reads as continuous prose.
- Composer reports its blocked state through the hint itself, which is
  also the recovery action.
- History entry moved from the sidebar to the chat context bar, so it
  stays reachable when the sidebar is a closed overlay.
- Settings groups restyled; row weight lowered from bold to medium.
- Segmented control replaced with a flat pill group.

### Fixed

- The session overflow button no longer appears only on hover, which
  made it unreachable on touch devices.
- `gpt_markdown` pinned to `1.3.0`. From `1.3.1` it depends on
  `val_latex_flutter`, which calls the removed
  `SemanticsService.sendAnnouncement` and therefore fails to compile on
  current Flutter. `flutter analyze` does not detect this.

### Known issues

- `test/features/chat/pages/chat_page_test.dart` still asserts the
  pre-`1.3.0` widget tree and is expected to fail until it is rewritten
  against the new surfaces.
- An Android build cannot be produced from this repository alone: the
  `libllama-server.so` binaries under `jniLibs/arm64-v8a` are untracked
  upstream and must be supplied from a Snapdragon build or a release
  bundle. See `patches/llama.cpp/README.md`.

## Upstream

This is a fork of [ArkaneFans/servllama](https://github.com/ArkaneFans/servllama),
which is licensed under AGPL-3.0. `1.2.2` and earlier correspond to
upstream releases; see the upstream repository for their changelogs.

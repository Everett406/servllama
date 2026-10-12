## [1.9.0] - 2026-10-12

阶段 1：修回归与明显缺陷。

### Fixed

- **设置页整页没图标**（v1.8.0 引入的回归）。31 处调用点把 Material 的
  `IconData` 交给了 Keyline painter，codepoint 撞不上表里的任何一项，
  于是全部落进一句 `return` 静默什么都不画。已全部映射到 Keyline 同义图标，
  图标集从 26 个扩到 43 个。`draw()` 里未知 codepoint 现在有
  `assert`，debug 下会炸而不是安静地留白；再加一个测试扫源码，
  保证任何 `ClaudeIcons.xxx` 都有对应图形。
- 引用块竖线贴着正文。`padding: EdgeInsets.zero` 把正文离竖线的距离一起
  干掉了——控制填充的是 `backgroundColor`，不是它。
- 「选择模型」行没有上下居中。副标题传的是 `Text('')` 而不是 null，
  `ListTile` 只在 subtitle 缺席时才收成一行，空字符串照样算存在，
  于是多留了两行高度把标题顶上去。
- 系统提示词行不再展开全文，副标题统一截断到两行加省略号。
- 顶栏胶囊从 42 放大到 50，图标同步 19 → 23。42 低于 48dp 的触摸目标线。
- 顶部补回渐隐。上一轮我把它整个删掉是改错了方向：用户要的不是没有渐隐，
  是渐隐要挪到胶囊下面那一段。胶囊实心且后画，不受影响。

### 查清不是问题

- 之前记为「豆腐块 □」的那个方框，是**「口」这个字本身**（U+53E3）。
  「服务器监听端**口**」「上下文窗**口**」都是正常文案，字形就是个空心方框。
  没有缺失字形。是我看见方框就当成渲染故障，白记了一条。


## [1.8.0] - 2026-10-12

### Icons

- Every icon is now drawn from Keyline, an open set of 1,366 drawings on one
  24x24 grid built around 2px strokes with round caps and joins (MIT).
  It has packages for React, React Native, Iconify, Figma and an MCP server
  but no Flutter one, and turning stroked artwork into a font means
  flattening every stroke to an outline first. So the drawings stay as path
  data and are stroked onto the canvas at paint time: same weight and
  terminals as drawn, no new dependency, no APK growth.
- All 26 icons come through the one abstraction the app already had, so no
  call site changed.

### Fixed

- The header pills float. They were a row in the page column, which reserved
  a full-width opaque strip above the transcript; the transcript now runs up
  behind them.
- A short turn of your own was drifting to the middle of the measure. The
  row wrapper used `Center` to cap the reading width, and Center also
  centres — so a long turn filled the measure and looked right-aligned by
  accident while a short one came out narrow and got parked in the middle.
  The measure is now pinned and alignment is the item's own decision again.
- The thought sheet follows the thought. Its reasoning came from a
  projection handed down from the list, but only on the branch that builds a
  streaming item, so a sheet opened from the other branch listened to
  nothing and showed its opening snapshot until closed. The item owns it now.
- Tokens per second under a reply. The sample was closed by the one call
  that could mark it finished — a call made from the streaming builder that
  the list detaches the moment the stream ends. The rate could never appear.


# Changelog

All notable changes to this project are documented here.

This file is maintained from `1.3.0` onward. Releases before that are
tracked in the upstream repository's tag history; see
[Upstream](#upstream) for the fork relationship.

## Versioning

`pubspec.yaml` holds the single source of truth:

```yaml
version: 1.7.0+33
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

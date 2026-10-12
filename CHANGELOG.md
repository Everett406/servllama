## [1.10.1] - 2026-10-12

Markdown 两个问题，都不是"再调一点 padding"。

### Fixed

- **表格塌成一列字**。样式表里写了 `columnWidth: FlexColumnWidth()`，
  它按比例平分可用宽度而且完全不测量内容。手机上五列分 360dp，
  每列就剩一个字宽，于是汉字竖着叠在一起，表格高度撑到四百多 dp。
  去掉这一行之后，包会按内容测量每一列，表格比视口宽，
  由它自带的 `_TableViewport` 横向滚动。
- **标题间距一刀切**。`HeadingStyle.padding` 对所有级别用同一个值，
  所以紧跟在 h1 下面的 h2 照样吃 22dp 顶部间距，看着像两个独立章节。
  改成走 `headingBuilder` 按级别给：h1 26、h2 18、h3 13，往下递减。
  这也是包唯一提供按级别控制的入口。

### 依赖版本上踩了一下

`TableOverflow` 是 `gpt_markdown` 1.3.4 才有的，而 lock 里的 1.3.0 没有——
写上去 analyze 就报未定义。查了 1.3.0 的源码确认它已经有带横向
ScrollController 的 `_TableViewport`，所以根本不需要那个参数。
**CI 跑的是 lock，不是 pub cache 里恰好存在的版本。**


## [1.10.0] - 2026-10-12

阶段 3：滚动手感与吐字。

### Fixed

- **吐字时自动滚动改成缓动跟随**。之前每来一个 token 就
  `correctPixels` 瞬移一次，流式每秒触发好几次，正文是一格一格跳下去的，
  和「跟随」正好相反。现在按位移量算一个 90–320ms 的缓动，
  动画没跑完就重新定位，不会排队。
- 吐字真的变成吐字了。`charactersPerSecond` 是 900，比模型自己吐字快太多，
  一整段在**一帧之内**就全部显示出来，所以看起来是「整体淡入」。
  调到 180，逐字渐入的尾巴也拉长到 0.38s。
- 逐行到达：块动画从 `growIn` 换成 `fadeIn`，时长 200 → 340ms。
  原来 `growIn` 快到读不出「一行到达」这个动作，三行是一个手势。
- 过冲回弹：新增 `VelaScrollPhysics`。跟 `BouncingScrollPhysics` 的两点区别——
  边缘跟手而不是硬停；**回弹不继承甩动的动量**（`carriedMomentum` 返回 0）。
  继承动量会让回弹几乎瞬间弹回，读起来像「拒绝移动」上面盖了一段回弹动画。
  摩擦系数取 iOS 的 0.135 而不是 Android 的 0.015，长对话不至于像在糖浆里拖。

### 一个自己写的 bug

`smoothFollow` 最初把目标写成 `pixels.clamp(min, max)`——pixels 本来就在范围内，
所以它恒等于「什么都不做」，而这恰恰是它唯一存在的场景：
坐在旧底部、内容长过它的时候。测试直接把它抓出来了。


## [1.9.1] - 2026-10-12

阶段 2：焦点与键盘。

### Fixed

- **键盘自己弹回来**。焦点和键盘是两件事，之前当成了同一件：
  系统返回手势只是隐藏输入法，并不取消焦点，于是输入框仍然是 focus 状态而
  键盘不在。任何重新布局都会把输入连接重新挂上，键盘就自己回来了——
  发完消息点「重试」足够触发，全程没有任何代码要求它弹出来。
- 消息列表加了一层点击收键盘。之前点空白处什么都不发生，焦点一直留着。
- 新增 `KeyboardStateRestorer`：离开页面前记下键盘状态，返回后照原样还原。
  这修掉了另一半——从子页面返回时键盘自己冒出来。现在两条导航
  （发现模型、引擎设置）都走同一个 `_pushAndRestore`，不会再漏。

### 一点说明

`FocusScope.of(context).unfocus()` 对 TextField 无效，`EditableText` 持有
自己的节点并会把焦点抢回去，必须走 `FocusManager.instance.primaryFocus`。

写测试时在夹具上浪费了一小时：`Column` 里的 `Expanded` + `ColoredBox`
宽度是 0，tap 落在框外，回调根本没触发，看起来像实现是坏的。
是测试写坏了。


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

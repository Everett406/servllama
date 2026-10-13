## 1.20.0

模型能调工具了。

- OpenAI 风格的 `tools` / `tool_calls` / `role: tool` 全链路打通。
- **总是**在请求里声明工具，不按"支持工具调用"这类静态标签过滤下载下来的模型。
  标签是猜测；实际会不会调由服务端说了算。真能调用的模型本来就会调，
  哪怕 UI 不相信它能。
- 内置三个工具：**当前时间**、**计算器**、**知识库检索**。
- 执行循环：模型停下来要工具 → 跑 → 把结果按 `role: tool` 喂回去 → 继续生成。
  上限 4 轮，否则一个不停要工具的模型永远给不出答案。**顺序执行**：它们跑在手机上，
  并行除了让两次写撞进同一个草稿之外没有任何好处。
  每个结果落地就显示，慢的检索不会看着像卡死。
- 工具行各占一行，可展开看参数和结果。**没有并进思考行**：工具调用是模型**做了什么**，
  思考行是模型**在想什么**，混在一起等于在说"它想了想要查一下"，而实际发生的是它查了。
- 工具结果存在消息上（`@HiveField(10)`/`(11)`，存 JSON 字符串），重开会话还能看到用了什么，
  后续轮次的 prompt 里也还在——模型看不见结果的工具调用，它只会再调一次。

**计算器是手写递归下降解析器，不是 eval。** 特征：白名单只放 `0-9 + - * / % ^ ( ) .` 和空格，
字母/引号/分号/`&&`/`$var`/`0x10` 一律在进解析器之前就被拒；长度上限 200；
除零返回错误而不是 `inf`（`inf` 顺着模型回到用户眼前读起来像故障）。
幂运算用 `dart:math.pow`，不手写 exp/ln 级数。

**顺带修掉一个真 bug：解析器不认小数。** `_parseAtom` 只吞整数，`3.5` 会在尾部检查上
失败，表现成"计算器不支持小数"。之前所有测试用例恰好都是整数，所以没人发现。
现在有专门的小数用例。

新增 20 个工具测试 + 3 个端到端协议测试（对着真实本地 HTTP 服务器验证：
请求里确实带了三个 `tools`、`tool_choice` 是 `auto`、
`tool_calls` 分片能按 index 拼回合法 JSON、`role: tool` 回合能原样发回去）。

全量测试 500 通过，3 个失败是既有的。

## 1.19.0

流式期间未闭合的表格不再边吐边长。

- 正在生成的表格块渲染成占位（"正在生成表格 · 已完成 N 行"），块闭合后一次性渲染真表格。
- 要澄清一点：这**不是**表格渲染坏了。gpt_markdown 本来就会把半截行 hold 住，
  表格不会在半行上成形。真正的问题是它在**长**——每落一行，上面所有行都要重新回流，
  你正在读的那几行永远在动。调列宽只能治叠字，治不了这个。
- 只有**末尾**的块可能是未闭合的。模型已经走过去的块按定义就是完成的，
  所以从尾部扫一遍就够，不需要在流中间找"打开的块"。
- 没有分隔行的 `a | b` 不是表格，只是恰好带竖线的文字——它照样渲染。
  否则普通内容会被占位吃掉。
- 占位显示已完成的行数，而不是干巴巴转圈：读者至少能看见它在推进。

新增 12 个测试。除 chat_page 外的全量测试 477 通过，3 个失败是既有的。

## 1.18.0

会话标题不再是你第一句话的截断了。

- **标题生成**：第一条回复结束后，用模型生成一个不超过几个词的标题。
  原来的做法是把用户第一句话截到 18 个字，那是以截断冒充标题——"你能帮我看看这段代码吗…"
  这种句子当标题毫无信息量。
- 标题是**第二次独立请求**，三条理由写进代码里了：
  - 在第一条回复**结束之后**才跑，绝不并行。两个流打同一个 llama-server 就是两个解码循环
    抢同一份上下文和内存，而用户正在等的是那条答案。
  - fire-and-forget。标题是加分项，为它弹错误提示比留着默认标题更糟。
  - 用户自己改过的标题绝不会被覆盖——请求回来后会再比一次标题没变才写。
- 可以指定**专用的标题模型**，也可以关掉。默认复用当前运行的模型：加载着的大模型
  给几个词取名是浪费，但省掉一次模型切换更值。
- 清理生成结果：引号、列表符号、行尾句号、多余解释、以及 "Here is a title:" /
  "标题：" 这类引导语。只在多行里取第一行是不够的——那样会把会话归档在
  "Here is a title:" 名下。截断按**码点**算，不会切在 3 字节字符中间变成乱码。

- **预填充小球**：模型还什么都没说的时候（既没有正文也没有思考内容）显示呼吸小球，
  填补 `ThinkingLine` 无内容可显示的那段空窗。用球不用转圈是因为这期间并没有在
  "计算"什么可命名的进度，只是在等第一个 token；转圈暗示有进度，慢呼吸不暗示。

新增 8 个标题清理测试。除 chat_page 外的全量测试 465 通过，3 个失败是既有的。

## 1.17.0

生成参数页，而且参数是真的发出去的。

- 设置里多了「生成参数」页：温度、Top P、Top K、重复惩罚、最大 token 数。
- 参数**走请求体**，不是服务器启动参数。llama-server 每请求都接受，所以改完下一条消息
  就生效，不用重启——这正是不把它和上下文长度放在一起的原因。
- 每个参数默认**留空 = 由模型决定**，请求体里直接**不带这个 key**。发 null 和不发不等价：
  有的服务器把显式 null 当成「用启动默认值」，有的直接报错，没道理去赌是哪一种。
  一个一打开就带着"合理默认值"的设置页，会在你没察觉的时候改变模型行为。
- 越界的值在发送前夹到服务器能接受的范围（温度 0–2、top_p 0–1、top_k 1–200、
  重复惩罚 0.5–2）。`max_tokens` 小于 1 直接丢掉而不是发出去——那会让每条回复
  在第一个 token 之前就被截断，比不设上限更糟。
- 参数存成一个 JSON blob 而不是五个 key：它们总是一起写一起读，五个偏好被写坏一半
  比"整份文档要么在要么不在"难处理得多。读不出来时退回默认值，而不是让应用起不来。
- `ChatGenerationController` 读参数用的是**函数**而不是构造时抓的副本——否则改设置
  要等 provider 重建才生效。

测试 11 个单元 + 2 个端到端，后者对着真实的本地 HTTP 服务器断言请求体里确实有
`temperature`/`top_p`/`top_k`/`repeat_penalty`/`max_tokens`，以及留空时这些 key 确实不存在。
一个只画得好看却什么都没发的页面，和真正能用的页面看起来一模一样。

除 chat_page 外的全量测试 457 通过，3 个失败是既有的。

## 1.16.0

模型可以只改显示名了。

- 模型卡上多一个改名按钮，改的是**显示名**，不是模型本身。
  `ModelDescriptor.displayName`（`@HiveField(12)`，旧数据缺失读作无别名）只影响界面，
  `modelName`、文件路径、目录、以及服务器启动时用的 `runtimeId` 全部原样不动。
  设了别名的卡片会在标题下面用小字补一行真实文件名——服务器确实是按那个名字启动的，
  藏起来就找不到了。
- 独立于真正的重命名：`LocalModelRepository.setDisplayName` 只改 Hive 里那一个字段，
  不碰磁盘。`renameLibraryModel` 会重命名文件，两条路径刻意不互相调用。
- 别名也**不走名字协调器**。两个模型完全可以显示成同一个名字，因为真正被叫那个名字的
  只有一个——拿来去重反而是错的。
- 显示名可以清回真名（卡片按钮在有别名时变成「恢复真名」）。
- 模型列表、服务器页、聊天页的模型 chip 一律显示别名。

新增 11 个测试锁住契约：`copyWith` 真的生效（无限定名在方法体里读的是字段，不是参数）、
别名可清空、别名不影响 `runtimeId`/`name`/路径、两个模型可以有相同显示名。

除 chat_page 外的全量测试 444 通过，3 个失败是既有的。

## 1.15.0

吐字动画现在是真逐字了。

- **中文逐字模糊淡入。** 根因是 `gpt_markdown` 的 reveal 只在**空白字符**处分组，
  而中文没有空格——所以一整段中文是一个 reveal group，其中所有字符共用**第一个字符**的
  进度：段落糊一次，然后整段同时变清晰，之后每段都是已落定的字。这就是"只有段落开头才有模糊"。
- 把 `gpt_markdown` vendor 进 `packages/gpt_markdown`（path 依赖）并打了补丁：
  `_groupEnd` 遇到 CJK 字符就在其后断开，`_wordStart` 遇到 CJK 边界就停下。
  表意文字没有 kerning、连字和字宽问题——这正是上游坚持拉丁文按词的原因——所以逐字切分
  在排版上不付代价，却换来了真正的逐字进场。**英文、URL、中英混排的分组行为完全不变。**
- 补了 `revealGroupEnd` / `revealGroupStart` 两个 `@visibleForTesting` 出口，
  以及 9 个测试把「中文逐字、英文按词」这个契约锁住。
- 调了 reveal 参数：`charactersPerSecond` 150 → 45，`revealFadeSeconds` 0.62 → 0.16。
  尾巴长度是两者相乘：原来 150×0.62 意味着**同时有 93 个字是糊的**，
  那是一道涂抹而不是逐字进场；现在留一道短促的波峰。
- `analysis_options.yaml` 排除 `packages/**`——vendor 进来的上游代码里那些
  deprecation 提示不是本仓库该修的，而且会把我们自己的淹掉。

vendor 的是 1.3.0 而不是 1.3.4：1.3.4 的依赖换成了 `val_latex_flutter`，
而它调用的 `SemanticsService.sendAnnouncement` 在 Flutter 3.35 里已经不存在，编译不过。

除 chat_page 外的全量测试 433 通过，3 个失败是既有的。

## 1.14.0

会话可以置顶了，侧边栏也按 Z2–Z6 重排过一遍。

- 会话新增置顶：菜单里可置顶/取消置顶，列表里带星标，排序把置顶的排在前面。
  新字段 `ChatSessionRecord.pinned` 用 `@HiveField(5)`，读旧数据时缺失即为 `false`，
  不用重建缓存。
- 侧边栏改成「标题 + 右上新建胶囊 / 标题下运行状态 / 中部会话列表上下渐隐 /
  左下搜索胶囊 / 右下模型库与设置图标胶囊」。原先单列到底的导航行没了，
  图标项只留图标，名字交给 tooltip 和语义标签。
- 会话三点菜单改为锚定浮层（抽屉内），跟随锚点、不受键盘影响。
  历史页仍在 `ListView` 里，行的 render object 会解析成 sliver，锚定浮层取不到矩形，
  所以那里保留原来的底部弹窗作为回退——菜单能开，不做无动作的按钮。
- 移除了菜单弹出前那 150ms 延迟。锚定浮层没有需要等完的进场动画，
  那段等待只会让按钮显得慢，而且是靠定时器而不是靠点击打开的。
- 锚点矩形解析不再用 `as RenderBox?`：列表里可能是 sliver，强转会连带把菜单一起拖垮，
  现在是安全判断后跳过。

`flutter analyze` 干净；除 chat_page 外的全量测试 424 通过，3 个失败是阶段 A 之前就存在的。

## [1.13.1] - 2026-10-13

阶段 A：锚定菜单跟随 + 思考计时器。

### 锚定菜单：三处

**1. 面板整个跑到屏幕外**（引擎按钮）
翻转逻辑两个分支不对称：向上偏好的能回退，向下偏好的不能。
引擎按钮在 composer 最底部，`prefer: down` 时下方没空间却还是往下开，
面板落在 899..1099，屏幕高 900——一像素没露出来，所以「点不动」。

**2. 位置是快照，不跟随**
面板位置取的是打开那一刻胶囊的 `Rect`。两张截图相隔 10 秒、
同一个页面，菜单一个在屏幕中间一个贴胶囊——键盘一收放布局变了，
面板还停在旧位置。

改成 `CompositedTransformFollower` 活链接。中间踩了一个坑值得记：
**follower 的子节点必须是面板本身，不能是包着面板的全屏盒子**——
`followerAnchor` 指的是子节点自己矩形的角点，给它 900 高的屏幕盒子，
`topLeft` 就是屏幕左上角，于是整个盒子被推下去 846px。

**3. 锚点对调了**
往上弹应该是「面板的左下」对「胶囊的左上」，我一开始写成了
「面板的左上」对「胶囊的左下」，等于把面板挂在胶囊下面。

### 思考计时器归零

三个独立的 bug 叠在一起：

1. **思考结束时什么都不记录。** 冻结挂在 `live` 标志上，而思考结束的那一刻
   `live` 还是 true。所以 `_elapsed` 在它刚刚成为答案的时刻被丢掉了。
2. **回退值算错。** `answeredAt - promptedAt` 里，`answeredAt` 是占位消息
   **创建**的时间（发请求时就建了），不是首个 token 的时间。差值≈0，
   所以重建后显示 0s。而它要求 `span.inSeconds > 0`，未满一秒的一律归零。
3. **冻结后计时器还在跑。** `Timer.periodic` 从没被取消，继续往冻结值上写真实
   经过时间。`_restartTicker` 只在 `live && !answerStarted` 时才被调用，
   而答案一开始它就再也没被调用过。

按你说的换了实现：**折叠行和思考弹窗原本是两套计时逻辑**，现在收敛成
`ThinkingTimings.clockFor(messageId)` 一个数据源，两边都读它，没有可对不齐的余地。

### 测试

新增 15 个：锚定面板在键盘关闭时必须在屏内、布局移动后必须仍贴着触发器、
胶囊从中间到最右（含小箭头位置）都可点；计时器四项。
**其中面板出屏、跟随、锚点方向、计时器四项一开始全是红的**，
都是被测试抓出来而不是我推出来的。

沙箱里 `DateTime.now()` 走真实时钟，`pump()` 推进不了，所以计时器的测试
断言的是契约（同一个 notifier、冻结后不倒退、冻结幂等）而不是秒数。


## [1.13.0] - 2026-10-13

服务器配置页：先让溢出可测，再修溢出。

### 这次先做了一件事：把探针变成可信的

上一轮我跑了个「找超出屏幕宽度的盒子」的探针，输出 0，就写进结论了。
但那个过滤器换了三轮、中途删了测试重写、最后一次 grep 是空的——
**我根本没确认断言跑过**。笔记 S4 里记着这个教训，这次把 canary 一起提交：

```dart
testWidgets('the overflow probe still detects an overflow', ...) {
  // 故意塞一个超宽的子节点，探针必须抓到它
  expect(_escapes(tester, window: phone), isNotEmpty);
}
```

探针一旦不再匹配就会红，而不是安静地报一个干净的页面。

### 真正的两处溢出

**1. Slider 的数值气泡（scale 1.0 就有）**
`_RenderValueIndicator` 按整条轨道的宽度算尺寸——卡片满宽 360 时，
气泡从 x=20 铺到 x=380，**超出屏幕右边 20px**。
它在 scale 1.0 就存在，但只在**手指按下时**出现，所以之前每次检查都测不到。
直接关掉：旁边的输入框本来就显示数值，气泡是多余的。

**2. 文本框内部（scale 1.3 起）**
`_RenderEditableCustomPaint` 在 x=280 宽 88，到 368。
这条**不是真溢出**——Flutter 会把 editable 按内容撑大然后由输入框裁掉，
外面看不见。探针因此加了一条：祖先里有裁剪就不算逃逸。
**不然我就会去追一个根本看不见的幽灵。**

### 顺带

探针现在会滚遍整页而不是只看静止位置——你截图里那个溢出在滚动中段。


## [1.12.0] - 2026-10-12

阶段 4 剩余 + 阶段 6 的一部分：锚定浮层、引擎按钮、空状态。

### 锚定浮层菜单

`VelaAnchor` + 锚定菜单，模型选择器和引擎选择器都从底部弹窗改成挂在
胶囊正上方的浮层。

**最容易漏的一条**是缩放原点朝向锚点，所以视觉上是「从胶囊里长出来」，
不是从屏幕中央淡入。这条不写出来下次一定会重犯。

踩了两个坑：
- 一开始用 `Positioned(top:)` 定位，面板高度得提前知道，可思考弹窗会变高、
  模型列表会滚动。改成**锚定靠触发器的那条边**（上开锚底、下开锚顶），
  高度交给布局，位置不会漂。
- 翻转策略一开始写成「哪边空间大开哪边」，结果屏幕正中的胶囊也会往下开，
  和要的效果正好相反。改成**只在首选方向真的没空间时才翻**。

### 引擎按钮按状态分支（U3）

```
未运行    [启动 llama.cpp] [启动 MNN]
llama.cpp [✓ llama.cpp · 运行中] [切换到 MNN] [停止]
MNN      [✓ MNN · 运行中] [切换到 llama.cpp] [停止]
```
之前是三种不同的行为：空状态一个大按钮、点开一个选择弹窗、已经在跑的时候
点一下直接停掉。按钮的含义会随状态变，而状态得先读才知道。
现在**任何状态都开同一个菜单**，菜单内容告诉你要什么就有什么。

切换引擎按你确认的：**先停再起**，不做并行。运行中右上角加了一个状态点。

### 空状态（V）

- 文案换成「只差一阵风 / 帆已经挂好了。它只在这台设备上走，不去别处。」
  之前那版是在**报状态**（「模型准备好了」「还差最后一步」），
  而空状态该做的是邀请。
- **删掉那个大按钮**。composer 的模型胶囊和引擎按钮都是一次点击，
  空状态再放第三个是重复。
- 整块内容下移到大致居中略偏上（`-0.236` → `-0.08`）。

### 测试

新增 5 个锚定定位测试：面板贴着触发器而不是屏幕中央、高处往下开、
低处往上开、248 宽 18 圆角、点外面关闭。**其中三个一开始就红了，
是它们把上面那两个定位 bug 抓出来的。**


## [1.11.0] - 2026-10-12

阶段 4 起步：统一弹窗。吐字动画的模糊查清了一件事，写在下面。

### 统一弹窗

新增 `showVelaSheet`，19 个散落的 `showModalBottomSheet` 全部迁过来。
四件以前每处都要各自搞一遍的事，现在只有一处：

- **是卡片不是抽屉**：四周留边、四角全圆、清开导航条。默认的底部弹窗
  贴边、两个直角、零留边。
- **去黑遮罩**：暖白页面上压一层黑色会把整页变灰，改成阴影色的淡washes。
- **非对称弹簧**：进场过冲一下再稳住，退场不过冲。对称弹簧会让关闭显得不情愿，
  而关闭恰恰是唯一一个用户不过脑子的动作。
- **把手只拖把手**。这里踩了个坑：`showModalBottomSheet` 自带
  `enableDrag: true`，**整个 sheet 都能拖下去**，我做的把手等于摆设。
  关掉之后 sheet 内的列表才不会再和路由的手势打架。

### 吐字动画：模糊为什么看不见

**你观察得对，而且这是包的硬设定，不是没调好。**

```dart
// gpt_markdown/lib/streaming/reveal_effect.dart:65
bool get animatesPerCharacter => this == GptMarkdownAnimation.wave;
```

只有 `wave` 是逐字的。`blurIn` **按块播放**，所以模糊只出现在换行的行上——
正好是你看到的样子。包里根本没有"逐字 + 模糊"这个组合。

再看曲线：
```
alpha = t
sigma = 3 * (1 - easeOut(t)) = 3 * (1 - t)^2
```
**两条曲线在开头是反相关的**：t=0 时模糊最强（sigma=3）但完全不透明。
等到 sigma 掉到 1.0 以下时，文字才只有 42% 不透明度。
也就是说，**从来没有一个时刻是「文字看得清、同时明显模糊」的**——
这就是渐显明显而模糊看不见的原因。

唯一的杠杆是窗口长度，所以这次：
- `revealFadeSeconds` 0.38 → 0.62（模糊可见时长从 ~160ms 提到 ~260ms）
- `blockAnimationDuration` 340 → 520ms
- `charactersPerSecond` 180 → 150

真要做到「逐字带模糊」，只能 fork 这个包（17k 行 / 53 文件）换掉
`revealStyleFor` 一个函数。没有这么做——代价太大，而且会让上游升级变麻烦。
如果你觉得按行的效果还不够，这条可以再议。


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

<div align="center">
  <img src="assets/app_icon.svg" alt="Vela 图标" width="112" />
  <h1>Vela</h1>
  <p><strong>你的手机就是服务器，数据不离开设备</strong></p>

  <p>
    <a href="https://gitee.com/Everett5678/servllama/releases/tag/v1.27.0">
      <img alt="下载最新版本" src="https://img.shields.io/badge/%E4%B8%8B%E8%BD%BD%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
    </a>
  </p>

<p align="center">
  <a href="./README.md">English</a> |
  <strong>中文</strong> |
  <a href="./HANDOFF.md">交接说明</a>
</p>

<p align="center">
  <table>
    <tr>
      <td><img src="docs/Screenshot1.jpg" width="280"></td>
      <td><img src="docs/Screenshot2.jpg" width="280"></td>
      <td><img src="docs/Screenshot3.jpg" width="280"></td>
      <td><img src="docs/Screenshot4.jpg" width="280"></td>
    </tr>
  </table>
</p>

</div>

## Vela 是什么

Vela 把一台 Android 手机变成自给自足的本地大模型服务器。推理在设备上跑，对外提供 OpenAI 兼容
API，同一台手机或同一局域网里的其他应用都能调用。

它是 [ArkaneFans/servllama](https://github.com/ArkaneFans/servllama) 的 fork。**推理内核是上游
的，没有动过** —— `libllama-server.so`、模型目录、下载逻辑都是 ArkaneFans 的工作。这个 fork
负责的是界面、发布流水线、Android 身份，以及下面
[这个 fork 加了什么](#这个-fork-加了什么) 里列的每一项。

*Vela*，八十八星座里最亮的一颗，在拉丁语里也是一片帆——本地模型正是这样：你给它风，它把它变成
动力，而它哪儿也不去。

---

## 这个 fork 加了什么

这里列的都是在上游之上做的，不是重写。

### 界面

- **Claude 风格设计系统。** 暖白底、砖橙强调色、低对比灰阶、大圆角。间距、圆角、墨色统一由
  `lib/app/design/tokens.dart` 提供。全应用都是圆角，直角就是 bug。
- **中文逐字吐字。** 上游 `gpt_markdown` 按空白字符分组切分，而中文没有空白——整段变成一组，
  整段一起糊一次再一起变清晰。已 vendor 并打补丁，在 CJK 边界断开。
- **公式真的渲染。** `useDollarSignsForLatex` 一直是上游默认的 `false`，所以 `$x^2$`——模型最
  顺手的写法——原样显示成源码。现在开了。
- **表格会滚动，不塌缩。** `FlexColumnWidth` 按比例分宽度且完全不测量内容；五列挤在 360dp
  屏上就是每行一个字。现在按内容测量，表格超出视口横向滚动（本来就有）。有圆角，流式时还有
  占位符，避免半张表每敲一个字就把上面的行挤动一次。

### 功能

- **完整的工具调用链路。** OpenAI 风格的 `tools` / `tool_calls` / `role: tool`。三个内置工具
  ——当前时间、计算器、知识库检索——在设置里各自独立开关。计算器是安全的递归下降解释器，
  语法像 JS（`**`、`Math.sin()`、`let`），但不是 `eval`：它只有一张数字符号表，够不到对象、
  属性链、`require`、`globalThis`，也够不到任何宿主方法。
- **真正跑得起来的知识库。** 嵌入向量来自**第二个** `libllama-server.so` 进程，跑在 8099
  端口，只加载嵌入 GGUF。对话服务器供不出来：`llama-server --model` 是单模型模式，会忽略请求里
  的 `model` 字段。嵌入模型直接从**和对话页同一个模型库**里选——没有预置，没有第二个模型世界。
  文档索引成 JSON；四个检索参数（结果数、相似度下限、总字符数、每段字符数）配三个预设，因为
  给三段和给八段的差别，是一句答案和一句"我不知道"的差别。
- **生成参数**走请求体，不走服务器启动参数。没设的值直接省略整个 key，不发 `null`。
- **标题生成。** 第一条回复结束后单独发一次请求，绝不并行。你手动改过的标题不会被覆盖。
- **模型显示别名。** 只改界面上的名字，不动文件、不动目录。
- **锚定菜单和浮动弹窗。** 模型、引擎、会话菜单跟随触发器，键盘变化时不会停在旧位置；底部弹窗
  四面留边、四角圆、软遮罩，只有把手能拖拽关闭。

---

## 运行要求

- Android 9（API 28）及以上
- 64 位 ARM 设备（`arm64-v8a`）
- 足够的存储和内存

速度和内存占用取决于模型、量化、上下文长度和设备。不确定的话先从小的开始。

---

## 快速开始

1. 从 [GitHub Releases](https://gitee.com/Everett5678/servllama/releases/tag/v1.27.0) 装最新的 APK。
2. 打开模型库。从 Hugging Face 或 ModelScope 下载，或导入本地 GGUF / MNN 模型。
3. 在对话页或服务器页选引擎和模型。
4. 启动服务器。在 Vela 里聊，或者把地址给别的客户端。
5. 要让别的设备访问：服务器配置里选 **Listen on all**，并设一个 API key。

默认地址 `http://127.0.0.1:8080`，只有本机能访问。

### 知识库

1. 把**嵌入** GGUF（比如 `Qwen3-Embedding-0.6B-Q8_0.gguf`）下载或导入模型库，和普通对话模型一样。
2. 知识库 → **嵌入模型** → 从模型库里选它。
3. 文档 → 导入 `.md` 或 `.txt`。
4. 建立索引，然后打开**允许对话检索**。

换嵌入模型会让已存的向量失效，页面会直说，从同一页重建。

---

## API

```bash
curl http://<device-ip>:8080/v1/models
```

```bash
curl -N http://<device-ip>:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-id",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

配了 API key 的话加 `-H "Authorization: Bearer <api-key>"`。同机客户端用 `127.0.0.1`。

---

## 推理引擎

| 引擎 | 模型格式 | 说明 |
| --- | --- | --- |
| llama.cpp | 单个 `.gguf`，视觉另加 `mmproj` | 社区实际在用的格式。Hugging Face 上大多数模型都有现成的量化 GGUF。 |
| MNN | MNN 模型 | 阿里的移动端运行时，ARM CPU/GPU 优化好；必须走 MNN 转换工具链。 |

两个引擎启动前都要先选模型。**同一时间只跑一个**并占用端口。切换是先停当前引擎再起下一个，
不会并行。

llama.cpp 的后端是 CPU、OpenCL、Hexagon（`ServerLaunchSettings.supportedLlamaCppBackends`）。
OpenCL 和 Hexagon 在具体设备上到底能不能用，是另一个问题，而且**本项目没有在真机上验证
过** —— 见 `HANDOFF.md`。

> `AGENTS.md` 里还写着 OpenCL"编译了但不提供"。这句已经过时：v1.27.0 起三个后端都在提供列表
> 里。这个文件需要同步改。

---

## 从源码构建

Flutter（Dart 3.9）、Android SDK、JDK 17。

```bash
git clone https://gitee.com/Everett5678/servllama.git
cd servllama
flutter pub get
flutter build apk --release
```

**`llama-server` 的二进制不在 git 里。** 把 `.so` 文件复制到
`android/app/src/main/jniLibs/arm64-v8a/`，来源是 release extra、GitHub Actions 产物，或本地
WSL 构建。见 `patches/llama.cpp/README.md`。

两条容易踩坏的约束：

- `android/app/build.gradle.kts` 里保留 `packaging.jniLibs.useLegacyPackaging = true`。
  服务器是子进程，必须作为真实文件存在于磁盘上。
- `ndk.abiFilters += "arm64-v8a"`。

每个打包的文件都必须以 `lib*.so` 命名，否则 AGP 会静默把它从 APK 里丢掉。

发布流水线会在推送前校验 arm64 原生库、签名、`extractNativeLibs(0x010104ea)=true` 和 APK 内容。

### 版本号

`pubspec.yaml` 是唯一来源，`versionCode` 和 `versionName` 都从它读。别在别处改。

---

## 注意事项

- **Listen on all** 会把服务器暴露到当前的 Wi-Fi、热点和 VPN 网段。请设 API key，并只在可信
  网络上使用。
- 部分 Android 厂商限制长时后台服务。如果切到后台后请求就停了，允许 Vela 自启动和后台运行，
  并把它从电池优化里排除。
- 模型会占用数 GB 存储和内存，选你的设备扛得动的。

---

## 文档

| 文件 | 是什么 |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | 架构和改动要遵守的规则。**先读这个。** |
| [`HANDOFF.md`](HANDOFF.md) | 当前状态、哪些没验证、哪些是故意不做的。 |
| [`CHANGELOG.md`](CHANGELOG.md) | 每个版本，按用户能看懂的话写。 |
| [`docs/SIGNING.md`](docs/SIGNING.md) | 发布签名配置。 |
| [`llama-server-README.md`](llama-server-README.md) | 上游关于内置服务器的说明。 |

---

## 相关项目

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [MNN](https://github.com/alibaba/MNN)
- [mnn_engine](https://pub.dev/packages/mnn_engine)
- [ArkaneFans/servllama](https://github.com/ArkaneFans/servllama) —— 上游

---

## 许可证

GNU Affero General Public License v3.0，继承自上游 ServLlama。

推理内核、模型目录和下载逻辑是 ArkaneFans 的。`lib/app/` 和 `lib/features/chat/widgets/`
下的一切是这个 fork 在其之上的工作。

AGPL-3.0 要求：任何通过网络提供本软件的人，必须同时发布对应的源码，包括你的修改。

---

致谢 [`Linux DO 社区`](https://linux.do/)。
---

> [!NOTE]
> **本仓库已迁移至 Gitee**：<https://gitee.com/Everett5678/servllama>
> GitHub 端仅作只读归档，新代码请推送到 Gitee。

<div align="center">
  <img src="assets/app_icon.svg" alt="Vela icon" width="112" />
  <h1>Vela</h1>
  <p><strong>Your phone is the server. Nothing leaves the device.</strong></p>

  <p>
    <a href="https://github.com/Everett406/servllama/releases/latest">
      <img alt="Download the latest release" src="https://img.shields.io/badge/Download-Latest_Release-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
    </a>
  </p>

<p align="center">
  <strong>English</strong> |
  <a href="./README_ZH.md">简体中文</a> |
  <a href="./HANDOFF.md">Handoff notes</a>
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

## What Vela is

Vela turns an Android phone into a self-contained local LLM server. It runs the inference
itself, serves an OpenAI-compatible API, and other apps on the same phone or local network
can call it.

It is a fork of [ArkaneFans/servllama](https://github.com/ArkaneFans/servllama). **The
inference kernel is upstream's and stays untouched** — `libllama-server.so`, the model
catalog, and the download logic are ArkaneFans's work. What this fork owns is the interface,
the release pipeline, the Android identity, and everything listed under
[What this fork added](#what-this-fork-added).

Named after *Vela*, the brightest of the eighty-eight constellations and a sail in Latin —
which is what a local model is: it turns the wind you give it into motion, and it goes
nowhere on its own.

---

## What this fork added

Everything here is work on top of upstream, not a rewrite of it.

### Interface

- **Claude-inspired design system.** Warm off-white canvas, brick-orange accent, low-contrast
  greys, generous radii. `lib/app/design/tokens.dart` is the single source for spacing,
  radius and ink colour. The whole app is rounded; a square corner is a bug.
- **Per-character Chinese text reveal.** Upstream's `gpt_markdown` breaks reveal groups on
  whitespace, and Chinese has none — so an entire paragraph was one group and blurred once
  then snapped sharp together. Vendored and patched to break on CJK boundaries.
- **Real LaTeX.** `useDollarSignsForLatex` was left at its upstream default of `false`, so
  `$x^2$` — the spelling a model reaches for first — rendered as literal source. Now on.
- **Tables that scroll instead of collapsing.** A `FlexColumnWidth` divides available width
  proportionally and measures nothing; five columns on a 360dp screen is one glyph per line.
  Columns are measured to their content and the table exceeds the viewport, which already
  scrolls. Rounded, and a stream-time placeholder so a half-written table does not reflow
  the rows above it on every keystroke.

### Features

- **Tool calling, end to end.** OpenAI-style `tools` / `tool_calls` / `role: tool`. Three
  built-ins — current time, calculator, knowledge search — each with its own switch in
  settings. The calculator is a safe recursive-descent interpreter with JS-shaped syntax
  (`**`, `Math.sin()`, `let`), not an `eval`: it has a numeric symbol table and no object,
  property chain, `require`, `globalThis` or host method reachable.
- **A knowledge base that actually runs.** Embeddings come from a **second**
  `libllama-server.so` process on port 8099 loading an embedding GGUF. The chat server
  cannot supply them: `llama-server --model` is single-model mode and ignores the `model`
  field of a request. The embedding model is picked from the **same model library** the chat
  page uses — no presets, no second model world. Documents are indexed to a JSON file;
  four retrieval knobs (result count, similarity floor, total and per-passage character
  budget) with three presets, because three passages and eight is the difference between an
  answer and a shrug.
- **Generation parameters** that go into the request body, not the server's launch flags. An
  unset value omits its key entirely rather than sending `null`.
- **Title generation.** A separate request after the first reply completes, never in
  parallel with it. A title you edited by hand is never overwritten.
- **Model display aliases.** Rename what a model is called in the UI without moving a file
  or a directory.
- **Anchored menus and floating sheets.** Model, engine and session menus follow their
  trigger through keyboard changes; bottom sheets float with margins on all four sides, a
  soft scrim, and drag-to-dismiss from the handle only.

---

## Requirements

- Android 9 (API 28) or later
- 64-bit ARM device (`arm64-v8a`)
- Enough free storage and memory for the model

Speed and memory depend on the model, quantization, context length and device. Start with a
smaller model if unsure.

---

## Quick start

1. Install the latest APK from
   [GitHub Releases](https://github.com/Everett406/servllama/releases/latest).
2. Open the model library. Download from Hugging Face or ModelScope, or import a local GGUF
   or MNN model.
3. Pick an engine and a model from the Chat or Server page.
4. Start the server. Chat inside Vela, or point another client at it.
5. For other devices: **Listen on all** in the server config, and set an API key.

Default address is `http://127.0.0.1:8080` — reachable from the phone only.

### Knowledge base

1. Download or import an **embedding** GGUF (for example `Qwen3-Embedding-0.6B-Q8_0.gguf`)
   into the model library, the same as any chat model.
2. Knowledge base → **Embedding model** → pick it from the library.
3. Documents → import `.md` or `.txt`.
4. Index, then turn on **Allow chat search**.

Swapping the embedding model invalidates the stored vectors and says so; rebuild from the
same page.

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

With an API key configured, add `-H "Authorization: Bearer <api-key>"`. Same-device clients
use `127.0.0.1`.

---

## Inference engines

| Engine | Model format | Notes |
| --- | --- | --- |
| llama.cpp | one `.gguf`, optional `mmproj` for vision | The format the community ships in. Most models on Hugging Face have ready-made quantized GGUF builds. |
| MNN | MNN model | Alibaba's mobile-optimised runtime. Strong on ARM CPU/GPU; must go through the MNN conversion toolchain. |

Both need a model selected before startup. **One engine runs at a time** and owns the port.
Switching stops the current engine before starting the next — they are never parallel.

llama.cpp backends are CPU, OpenCL and Hexagon
(`ServerLaunchSettings.supportedLlamaCppBackends`). Whether OpenCL or Hexagon actually works
on a given device is a separate question this project has **not** verified on hardware — see
`HANDOFF.md`.

> `AGENTS.md` still says OpenCL is compiled but not offered. That is out of date: all three
> are in the offered list as of v1.27.0. The file needs the same edit.

---

## Build from source

Flutter with Dart 3.9, Android SDK, JDK 17.

```bash
git clone https://github.com/Everett406/servllama.git
cd servllama
flutter pub get
flutter build apk --release
```

**The `llama-server` binaries are not in git.** Copy the `.so` files into
`android/app/src/main/jniLibs/arm64-v8a/` from a release extra, the GitHub Actions artifact,
or a local WSL build. See `patches/llama.cpp/README.md`.

Two constraints that are easy to break:

- `packaging.jniLibs.useLegacyPackaging = true` in `android/app/build.gradle.kts`. The server
  is a child process and must exist as a real file on disk.
- `ndk.abiFilters += "arm64-v8a"`.

Every bundled file must be named `lib*.so`, or AGP silently drops it from the APK.

The release workflow verifies the arm64 native libraries, the signature,
`extractNativeLibs(0x010104ea)=true` and the APK contents before publishing.

### Version numbers

`pubspec.yaml` is the only source. `versionCode` and `versionName` are read from it. Do not
edit them anywhere else.

---

## Notes

- **Listen on all** exposes the server to the current Wi-Fi, hotspot and VPN networks. Use an
  API key on a network you trust.
- Some Android vendors restrict long-running background services. If requests stop after
  backgrounding, allow auto-start and exempt Vela from battery optimisation.
- Models take gigabytes of storage and memory.

---

## Documentation

| File | What it is |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | Architecture and the rules a change is expected to follow. Read this first. |
| [`HANDOFF.md`](HANDOFF.md) | Current state, what is unverified, and what is deliberately not done. |
| [`CHANGELOG.md`](CHANGELOG.md) | Every version, in the user's terms. |
| [`docs/SIGNING.md`](docs/SIGNING.md) | Release signing setup. |
| [`llama-server-README.md`](llama-server-README.md) | Upstream's notes on the bundled server. |

---

## Related projects

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [MNN](https://github.com/alibaba/MNN)
- [mnn_engine](https://pub.dev/packages/mnn_engine)
- [ArkaneFans/servllama](https://github.com/ArkaneFans/servllama) — upstream

---

## License

GNU Affero General Public License v3.0, inherited from upstream ServLlama.

The inference kernel, model catalog and download logic are ArkaneFans's. Everything under
`lib/app/` and `lib/features/chat/widgets/` is this fork's work on top of them.

AGPL-3.0 requires that anyone offering this over a network releases the corresponding
source, including your modifications.

---

Acknowledgements [`Linux DO Community`](https://linux.do/).
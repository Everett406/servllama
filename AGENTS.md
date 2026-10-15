# ServLlama AGENTS Guide

> **The app is Vela.** `ServLlama` is the upstream project name and the Flutter package
> name; the user-facing name, the repository and the Android identity are Vela.
>
> Read `HANDOFF.md` before starting: it records which parts are verified on hardware,
> which are not, and which are deliberately not done.

## Project Overview

- `ServLlama` is a Flutter application for managing and using local LLM inference API services powered by `llama-server`.
- The project follows a feature-first structure.

## Tech Stack

- Language: `Dart 3`
- Framework: `Flutter`
- UI: `Material 3`
- Platform: currently focused on `Android`, with bundled `llama-server` binaries
- Persistence: `Hive` + `SharedPreferences`
- State management: `provider`
- Networking: `dio`
- Dependencies: `path_provider`, `file_picker`, and others (see `pubspec.yaml`)

## llama-server Integration

- This project bundles and manages `llama-server` as its local inference backend.
- The Flutter app does not implement model inference directly; it communicates with `llama-server` over HTTP APIs.
- `llama-server` is responsible for model loading, inference execution, request handling, and the core inference lifecycle.
- The Flutter app is responsible for service startup orchestration, parameter configuration, status presentation, error handling, and user interaction.
- When making changes related to `llama-server`, clarify the boundary first:
  - whether the change belongs to service process management
  - whether it belongs to API parameter adaptation
  - whether it belongs to model discovery and path management
  - whether it belongs to Flutter UI presentation and interaction logic
- If you need to adjust `llama-server` startup arguments, port, model path, context length, thread count, or similar settings, encapsulate them in the service or repository layer first. Do not scatter these details across page-level code.
- For detailed `llama-server` usage, see `llama-server-README.md`.

### Binary Maintenance

- `llama-server` binaries ship as jniLibs (`android/app/src/main/jniLibs/arm64-v8a/`). The `.so` files are **not** tracked in git; copy them from a Snapdragon WSL build or a release bundle. See `patches/llama.cpp/README.md`.
- The server executable is packaged as `libllama-server.so` and executed from `nativeLibraryDir`, with `LD_LIBRARY_PATH` and `ADSP_LIBRARY_PATH` pointing at that directory (plus vendor OpenCL / FastRPC paths).
- Every bundled file must be named `lib*.so`, otherwise AGP silently excludes it from the APK.
- Keep `packaging.jniLibs.useLegacyPackaging = true` in `android/app/build.gradle.kts`. The server runs as a child process and must exist as a real file on disk.
- OpenCL (`libggml-opencl.so`) and Hexagon (`libggml-hexagon.so` + `libggml-htp-v*.so`) are part of the Snapdragon bundle. Do not NDK-strip the HTP kernels.
- Hexagon empty-device fix is a project patch on llama.cpp **v0.4.1**: `patches/llama.cpp/0001-hexagon-skip-unsupported-devices.patch`.
- Offered llama.cpp backends are `ServerLaunchSettings.supportedLlamaCppBackends`, which currently lists CPU, OpenCL and Hexagon. The device probe only enables or disables entries in that list.
- **What the published APK contains is verified; what it does on a device is not.**
  `inspect-release-apk.yml` downloads the release asset, verifies it against the published
  `SHA256SUMS.txt`, and confirms every native library against the CRC-32 in the archive
  manifest. As of v1.27.0 that establishes: `libggml-opencl.so` (3,578,176 B),
  `libggml-hexagon.so` (899,240 B) and four `libggml-htp-v*.so` (769 KB–852 KB, ELF
  QUALCOMM DSP6) are all shipped, and all are real libraries, not NDK stubs.
  `libOpenCL.so` is absent by design — it is a vendor system library on Android, and
  `libggml-opencl.so` takes it from `/vendor/lib64` via `LD_LIBRARY_PATH`.
  **Whether either accelerator actually runs on a given phone remains unverified.** Do not
  write in any doc or commit message that either works, or that either does not.
- When updating llama-server, replace the `.so` files AND sync the version in `assets/bin/llama_server_manifest.json`. The manifest is display-only (About page) and is not validated against the binaries.

## Development Practices

- Put new business logic under `lib/features/<feature>/` whenever possible.
- Use `lib/app/` for app entry, route assembly, and app-level composition.
- Use `lib/core/` only for foundational capabilities shared across features.
- Use `lib/shared/` for reusable UI components and shared presentation utilities.
- Do not add extra entities unless necessary. Avoid defensive programming and do not design for hypothetical future requirements.
- Put user-facing strings in ARB localization files. Do not hard-code display text in Dart code.

## Layering Rules

- The page layer is responsible for presentation, interaction orchestration, and routing.
- The state layer is responsible for page state, user action coordination, and flow orchestration.
- The service or repository layer is responsible for I/O concerns such as processes, file system access, persistence, and networking.
- Models and types should express strongly typed data only, without page logic mixed in.

## Single Responsibility

- A class, component, or module should have one clear responsibility.
- Pages must not handle low-level I/O directly.
- The state layer must not own low-level resource implementation details.
- The service or repository layer must not contain UI presentation logic.
- Shared components must not embed feature-specific business decisions.
- Shared capabilities should remain reusable, and business capabilities should have clear boundaries.

## Development and Verification

- **Run `tool/verify.sh` before committing.** It runs `flutter analyze`, the test
  suite against a baseline of known failures, the layering guards below, and a
  structural check on the workflows. Use `--fast` to skip the test suite.
- `tool/verify.sh` failing on something you did not touch is information about
  the baseline, not a reason to stop: fix the code, or regenerate the baselines
  with `--update` once the change is deliberate. See `tool/README.md`.
- **The rules in this file are enforced where they are cheap to enforce.** The
  layering rules map to `tool/known_architecture_violations.txt`: existing
  violations are baselined, and a new one fails the build. `pubspec.yaml`
  being the only version source is likewise checked. The rest are still prose.
- Prefer adding unit tests when changing business logic.
- Add the minimum necessary widget tests when changing page interactions.
- Do not manually edit generated files, including `*.g.dart` and `lib/l10n/generated/*`.
- Do not perform unrelated refactors. When touching old code, only bring it closer to the standard within the scope of the current change.
- `python3 tool/lib/dead_code.py` lists declarations nothing references.
  Deleting one is safe with respect to the build, but it is still a decision
  about whether the component is wanted back.

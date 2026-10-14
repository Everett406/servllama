import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/core/services/llama_server_environment.dart';
import 'package:servllama/core/services/native_library_dir_service.dart';

/// A second llama-server that exists only to embed text.
///
/// Why a second process instead of the one already running:
///
/// llama-server started with `--model` is in **single-model mode**, and in
/// that mode the `model` field of a request is *ignored* — the server serves
/// the one model it was given. There is no flag that makes a chat model
/// answer `/v1/embeddings`, and no way to route a second model through it
/// short of restarting in router mode, which means launching without
/// `--model` and reworking the chat path that already works.
///
/// So: a separate process on its own port, with the embedding GGUF. The chat
/// server is not touched, and if embedding is broken the conversation is
/// unaffected.
///
/// It starts when indexing and stops on an idle timer. A 26 MB model is not
/// worth holding awake on a phone between searches, and a process the user
/// cannot see running forever is a battery complaint waiting to happen.
class EmbeddingServer {
  EmbeddingServer({
    Dio? dio,
    NativeLibraryDirService? nativeLibraryDirService,
  }) : _dio = dio ?? Dio(),
       _nativeLibraryDirService = nativeLibraryDirService ??
           NativeLibraryDirService();

  static const String binaryFileName = 'libllama-server.so';

  /// One above the chat server's default, and a port nothing else claims.
  /// Kept out of the launch settings on purpose: this is an implementation
  /// detail of retrieval, not something the user should configure and then
  /// be blamed for when it collides with something.
  static const int defaultPort = 8099;

  /// Idle shutdown. Long enough that indexing a folder does not restart the
  /// process between batches, short enough that a closed knowledge base is
  /// not holding a process open all evening.
  static const Duration idleTimeout = Duration(minutes: 2);

  final Dio _dio;
  final NativeLibraryDirService _nativeLibraryDirService;

  Process? _process;
  Timer? _idleTimer;
  bool _starting = false;
  String? _loadedModelPath;
  int _port = defaultPort;
  String? _lastError;

  bool get isRunning => _process != null;
  int get port => _port;
  String? get lastError => _lastError;

  /// Whether a process is up *and* answering. A process that is alive but
  /// still loading the model would fail every call in a way that looks like a
  /// bad embedding rather than an early request.
  Future<bool> isReady() async {
    if (_process == null) return false;
    try {
      final response = await _dio.get<dynamic>(
        'http://127.0.0.1:$_port/health',
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> start({
    required String modelPath,
    int port = defaultPort,
    Duration? timeout = const Duration(seconds: 60),
  }) async {
    _lastError = null;
    if (_process != null) {
      if (_loadedModelPath == modelPath && _port == port) {
        return 'http://127.0.0.1:$_port';
      }
      await stop();
    }
    if (modelPath.isEmpty) {
      _lastError = 'No embedding model selected.';
      throw StateError(_lastError!);
    }

    _starting = true;
    try {
      final nativeLibraryDir = await _nativeLibraryDirService
          .getNativeLibraryDir();
      final binaryPath = '$nativeLibraryDir/$binaryFileName';
      final args = <String>[
        '--model',
        modelPath,
        '--port',
        '$port',
        '--host',
        '127.0.0.1',
        // The model is ours to keep warm while indexing; it is a fixed cost
        // and the alternative is re-reading 26 MB per batch.
        '--ctx-size',
        '2048',
        // Embedding models take no system prompt and have no chat template to
        // speak of. Asking for one produces a warning on every request and,
        // on some builds, a pool size error.
        '--embedding',
        '--pooling',
        'none',
        '--log-disable',
      ];

      debugPrint('EmbeddingServer: $binaryPath ${args.join(' ')}');
      final process = await Process.start(
        binaryPath,
        args,
        runInShell: false,
        environment: llamaServerLibraryEnvironment(nativeLibraryDir),
      );
      _process = process;
      _loadedModelPath = modelPath;
      _port = port;

      // Drain the pipes. A server that fills its stdout pipe blocks on write,
      // and an embedding indexer will happily produce enough output to do
      // that — a model that looks like it hung while indexing.
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((_) {}, onError: (_) {});
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((_) {}, onError: (_) {});

      unawaited(
        process.exitCode.then((_) {
          if (_process == process) {
            _process = null;
            _loadedModelPath = null;
          }
        }),
      );

      final ready = await _waitUntilReady(timeout ?? const Duration(seconds: 60));
      if (!ready) {
        await stop();
        _lastError =
            'The embedding model did not finish loading. It may be missing '
            'or not an embedding model.';
        throw StateError(_lastError!);
      }
      _resetIdleTimer();
      return 'http://127.0.0.1:$port';
    } catch (error) {
      _lastError = '$error';
      await stop();
      rethrow;
    } finally {
      _starting = false;
    }
  }

  bool get isStarting => _starting;

  /// Poll until the server answers, rather than sleeping a fixed amount. A
  /// fixed sleep is either too short on a slow phone — and produces a failed
  /// index — or wastes seconds on every single call.
  Future<bool> _waitUntilReady(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_process == null) return false;
      if (await isReady()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  /// Keep the process alive across a batch of work.
  void keepAlive() => _resetIdleTimer();

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      unawaited(stop());
    });
  }

  Future<void> stop() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final process = _process;
    _process = null;
    _loadedModelPath = null;
    if (process == null) return;
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // Already gone. Nothing to do about it.
    }
    // Give the OS a moment to release the port; the next start is on a
    // timer and a bind failure would otherwise look like a crash.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
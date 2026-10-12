import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/llama_cpp_device_probe_service.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/engines/llama_cpp_engine_adapter.dart';

import '../../../support/stub_engine_adapter.dart';
import '../../../support/fake_mnn_backend_service.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/features/server/pages/server_config_page.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerConfigPage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });


    testWidgets('shows loading first and then renders loaded slider value', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final loader = _CompleterServerLaunchSettingsLoader();
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        settingsLoader: loader,
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
        ),
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('上下文长度'), findsNothing);
      expect(find.byType(Slider), findsNothing);

      loader.complete(
        const ServerLaunchSettings(contextSize: 8192, batchSize: 1024),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('推理参数'), findsOneWidget);
      expect(find.text('上下文长度'), findsOneWidget);
      expect(find.textContaining('上下文过高可能导致内存不足闪退'), findsOneWidget);
      final contextSlider = tester.widget<Slider>(find.byType(Slider).first);
      expect(contextSlider.value, 8192);
      expect(contextSlider.min, ServerLaunchSettings.minContextSize);
      expect(contextSlider.max, ServerLaunchSettings.maxContextSize);
      expect(
        contextSlider.divisions,
        (ServerLaunchSettings.maxContextSize -
                ServerLaunchSettings.minContextSize) ~/
            512,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == '8192',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses fixed 1-8 defaults for performance sliders', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
        ),
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();
      // The settings list is a SliverList: it only builds elements near the
      // viewport, so which sliders are on screen depends on how tall the
      // sections above them render. Sweep down until the performance sliders
      // (the only ones with 7 divisions, 1-8) are built and visible, instead
      // of guessing a fixed drag distance.
      bool performanceSlidersVisible() => tester
          .widgetList<Slider>(find.byType(Slider))
          .any((slider) => slider.divisions == 7);

      for (var i = 0; i < 12 && !performanceSlidersVisible(); i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      final performanceSliders = sliders.sublist(sliders.length - 2);

      expect(sliders.length, greaterThanOrEqualTo(2));
      expect(performanceSliders[0].min, 1);
      expect(performanceSliders[0].max, 8);
      expect(performanceSliders[0].divisions, 7);
      expect(
        performanceSliders[0].value,
        ServerLaunchSettings.defaultCpuThreads,
      );
      expect(performanceSliders[1].min, 1);
      expect(performanceSliders[1].max, 8);
      expect(performanceSliders[1].divisions, 7);
      expect(performanceSliders[1].value, 1);
      expect(configProvider.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(
        configProvider.parallelSlots,
        ServerLaunchSettings.defaultParallelSlots,
      );
    });

    testWidgets('shows logging controls with enabled info defaults', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
        ),
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('日志'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('日志'), findsOneWidget);
      expect(find.text('日志启用'), findsOneWidget);
      expect(find.text('日志级别'), findsOneWidget);
      expect(find.text('信息'), findsOneWidget);
      expect(configProvider.logEnabled, isTrue);
      expect(configProvider.logLevel, ServerLogLevel.info);
    });

    testWidgets('shows MNN backends without llama inference controls', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final backendService = FakeMnnBackendService();
      addTearDown(backendService.dispose);
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        mnnBackendService: backendService,
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
        ),
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await serverProvider.switchEngine(InferenceEngine.mnn);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MNN'), findsOneWidget);
      expect(find.text('MNN 推理后端'), findsOneWidget);
      expect(find.text('网络与访问'), findsOneWidget);
      expect(find.text('MNN 运行参数'), findsOneWidget);
      expect(find.byKey(const Key('mnn_use_mmap')), findsOneWidget);
      expect(find.byKey(const Key('mnn_precision')), findsOneWidget);
      expect(find.byKey(const Key('mnn_thread_num')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('网络与访问')).dy,
        lessThan(tester.getTopLeft(find.text('MNN 运行参数')).dy),
      );
      expect(find.text('MNN 推理'), findsNothing);
      expect(find.text('推理后端'), findsNothing);
      expect(find.text('推理参数'), findsNothing);
      expect(find.text('上下文长度'), findsNothing);
    });

    testWidgets('removes fixed action bar and saves port changes immediately', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
        ),
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('保存配置'), findsNothing);
      expect(find.textContaining('当前地址：http://'), findsNothing);
      expect(find.textContaining('改动即时保存'), findsNothing);
      expect(
        find.byKey(const Key('server_config_effect_notice')),
        findsNothing,
      );
      expect(find.text('网络与访问'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '8080'), '9001');
      await tester.pumpAndSettle();

      expect(configProvider.port, 9001);
      expect(await kvStorage.getInt(ServerPrefsKeys.port), 9001);
      // Saves persist the full settings snapshot; untouched fields hold
      // their defaults.
      expect(
        await kvStorage.getString(ServerPrefsKeys.listenMode),
        'localhost',
      );
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isEmpty);
      expect(serverProvider.displayAddress, '127.0.0.1:9001');
    });

    testWidgets('restores defaults only after confirmation', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ServerPrefsKeys.listenMode: ServerListenMode.allInterfaces.name,
        ServerPrefsKeys.port: 9000,
        ServerPrefsKeys.apiKey: 'secret',
      });

      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
          resultOverride: () => LlamaCppDeviceProbeResult.cpuOnly,
        ),
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelRepository: _FixedModelStoragePaths('C:\\app\\models'),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(configProvider.listenMode, ServerListenMode.allInterfaces);
      expect(configProvider.port, 9000);
      expect(serverProvider.displayAddress, '0.0.0.0:9000');

      final restoreDefaultTile = find.widgetWithText(SettingsMenuTile, '恢复默认配置');
      await tester.scrollUntilVisible(
        restoreDefaultTile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(restoreDefaultTile, findsOneWidget);
      await tester.tap(restoreDefaultTile);
      await tester.pumpAndSettle();

      expect(find.text('恢复默认配置'), findsNWidgets(2));
      expect(find.text('所有配置项将恢复默认值，确定继续吗？'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(configProvider.listenMode, ServerListenMode.allInterfaces);
      expect(configProvider.port, 9000);
      expect(await kvStorage.getInt(ServerPrefsKeys.port), 9000);

      await tester.ensureVisible(restoreDefaultTile);
      await tester.tap(restoreDefaultTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '恢复默认'));
      await tester.pumpAndSettle();

      expect(configProvider.listenMode, ServerListenMode.localhost);
      expect(configProvider.port, ServerLaunchSettings.defaultPort);
      expect(configProvider.apiKey, isEmpty);
      expect(configProvider.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(
        configProvider.parallelSlots,
        ServerLaunchSettings.defaultParallelSlots,
      );
      expect(
        await kvStorage.getString(ServerPrefsKeys.listenMode),
        'localhost',
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.port),
        ServerLaunchSettings.defaultPort,
      );
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isEmpty);
      expect(
        await kvStorage.getInt(ServerPrefsKeys.cpuThreads),
        ServerLaunchSettings.defaultCpuThreads,
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.parallelSlots),
        ServerLaunchSettings.defaultParallelSlots,
      );
      expect(serverProvider.displayAddress, '127.0.0.1:8080');
    });

    testWidgets('the overflow probe still detects an overflow', (
      tester,
    ) async {
      // The canary. An earlier version of this check reported a clean page
      // because the probe had stopped matching anything and nothing in the
      // suite noticed. If this fails, the scale tests below are passing for the
      // wrong reason.
      const phone = Size(360, 780);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: phone.width,
              child: Align(
                child: SizedBox(
                  width: phone.width * 2,
                  child: const Text('deliberately too wide'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(_escapes(tester, window: phone), isNotEmpty);
    });

    for (final scale in <double>[1.0, 1.3, 1.5, 2.0]) {
      testWidgets('nothing escapes the page at text scale $scale', (
        tester,
      ) async {
        const phone = Size(360, 780);
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final kvStorage = KvStorage();
        final configProvider = ServerConfigProvider(
          kvStorage: kvStorage,
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          // The longest strings the page can show: a real device name, and
          // the raw probe output that is the only way to tell an absent HTP
          // from an unsupported one.
          llamaCppDeviceProbeService: LlamaCppDeviceProbeService(
            resultOverride: () => const LlamaCppDeviceProbeResult(
              openclDeviceName: 'Adreno (TM) 825',
              hexagonDeviceName: 'Qualcomm HTP (QNN)',
              rawOutput:
                  'ggml_opencl: platform IDs not available.\n'
                  '/vendor/lib64/libcdsprpc.so: undefined symbol: '
                  'android::binder2os::get_trace_enabled_tags()',
            ),
          ),
        );
        final serverService = _FakeLlamaServerService();
        final serverProvider = EngineRuntimeProvider(
          llamaCppAdapter: LlamaCppEngineAdapter(
            serverService: serverService,
            settingsLoader: _FixedServerLaunchSettingsLoader(
              const ServerLaunchSettings(),
            ),
            modelRepository: _FixedModelStoragePaths('/app/models'),
          ),
          mnnAdapter: StubEngineAdapter(),
          settingsLoader: _FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
        );
        addTearDown(() {
          configProvider.dispose();
          serverProvider.dispose();
          serverService.dispose();
        });

        await tester.pumpWidget(
          _TestApp(
            serverProvider: serverProvider,
            textScale: scale,
            child: ServerConfigPage(provider: configProvider),
          ),
        );
        await tester.pumpAndSettle();

        // Walk the whole page. What the user showed was in the middle of the
        // scroll, so only measuring the resting position would miss it.
        // Gather the whole list before failing. Stopping at the first hit
        // reports one box at a time and makes this a guessing game.
        final found = <String>[];
        final list = find.byType(ListView);
        for (var i = 0; i < 6; i++) {
          for (final e in _escapes(tester, window: phone)) {
            found.add('step $i: $e');
          }
          if (list.evaluate().isEmpty) break;
          await tester.drag(list, const Offset(0, -240));
          await tester.pumpAndSettle();
        }
        expect(found, isEmpty, reason: 'text scale $scale');
      });
    }

  });
}

/// One box that reaches outside the window it is supposed to stay inside.
class _Escape {
  _Escape(this.rect, this.description);

  final Rect rect;
  final String description;

  @override
  String toString() =>
      '${rect.left.toStringAsFixed(1)}..${rect.right.toStringAsFixed(1)} '
      '(window ${rect.width.toStringAsFixed(1)}) — $description';
}

/// Every rendered box that reaches past the window's left or right edge.
///
/// The previous version of this check reported "0 overflows" and was wrong:
/// the filter had been rewritten three times, the last grep came back empty,
/// and nothing proved the assertion had ever run. So this one carries a canary
/// — a test that feeds it a deliberately oversized child. A probe that quietly
/// stops matching has to fail rather than report a clean page.
/// RenderClipRect, RenderClipRRect, RenderClipOval and friends all name
/// themselves "Clip". That is the cheapest reliable test here; a structural one
/// needs the generic RenderClipper type, which is not exported.
bool _clipsByDefault(RenderObject box) =>
    box.runtimeType.toString().contains('Clip');

bool _isExplicitlyClipping(RenderBox box) {
  try {
    return (box as dynamic).clipBehavior != Clip.none;
  } catch (_) {
    return false;
  }
}

/// True when some ancestor clips the overflow away.
///
/// Flutter sizes a text field's editable to at least its content and then
/// clips it. That box genuinely extends past its container and genuinely
/// paints nothing there, so counting it would be chasing a phantom — which is
/// how a previous version of this check ended up reporting either nothing or
/// everything. Only a box whose overflow is actually painted outside the
/// window counts.
bool _clippedByAncestor(RenderObject box, Size window) {
  var node = box.parent;
  var hops = 0;
  while (node != null && hops < 40) {
    if (node is RenderBox && node.hasSize) {
      final rect = node.localToGlobal(Offset.zero) & node.size;
      // Anything that clips and sits inside the window takes the overflow
      // with it. RenderClipRRect/Rect/Oval all expose clipBehavior; a plain
      // RenderBox with no clip does not.
      final clips = _clipsByDefault(node) || _isExplicitlyClipping(node);
      if (clips && rect.left >= -0.5 && rect.right <= window.width + 0.5) {
        return true;
      }
    }
    node = node.parent;
    hops++;
  }
  return false;
}

List<_Escape> _escapes(WidgetTester tester, {required Size window}) {
  final out = <_Escape>[];
  void visit(RenderObject child) {
    if (child is RenderBox && child.hasSize && child.attached) {
      final origin = child.localToGlobal(Offset.zero);
      final pastLeft = origin.dx < -0.5;
      final pastRight = origin.dx + child.size.width > window.width + 0.5;
      if ((pastLeft || pastRight) && !_clippedByAncestor(child, window)) {
        // Name the field, not just the render class. Every text field on the
        // page is the same render object, so "a TextField overflowed" is not
        // an answer.
        out.add(
          _Escape(
            origin & child.size,
            '${child.runtimeType} w=${child.size.width.toStringAsFixed(0)} '
            'x=${origin.dx.toStringAsFixed(0)}',
          ),
        );
      }
    }
    child.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return out;
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.serverProvider,
    required this.child,
    this.textScale = 1.0,
  });

  final EngineRuntimeProvider serverProvider;
  final Widget child;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EngineRuntimeProvider>.value(
          value: serverProvider,
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _CompleterServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  final Completer<ServerLaunchSettings> _completer =
      Completer<ServerLaunchSettings>();

  @override
  Future<ServerLaunchSettings> load() => _completer.future;

  void complete(ServerLaunchSettings settings) {
    _completer.complete(settings);
  }
}

class _FakeLlamaServerService implements LlamaServerService {
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => false;

  @override
  Future<String> loadBundledVersion() async => 'b9830';

  @override
  void dispose() {
    _runningStateController.close();
  }

  @override
  void initForegroundTask() {}

  @override
  Future<bool> startServer({List<String>? args}) async => true;

  @override
  Future<bool> stopServer() async => true;
}

class _FixedModelStoragePaths extends LocalModelRepository {
  _FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<List<ModelDescriptor>> listModels() async => <ModelDescriptor>[
    ModelDescriptor(
      id: 'test-model',
      modelName: 'test-model',
      sizeBytes: 1,
      storedDirectoryPath: '$modelsDirectoryPath/test-model',
      storedFilePath: '$modelsDirectoryPath/test-model/model.gguf',
      importedAt: DateTime(2026),
    ),
  ];
}

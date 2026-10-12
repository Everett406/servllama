import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:servllama/app/app.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/logging/file_log_sink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // edgeToEdge only controls layout: on its own the navigation bar keeps the
  // platform's opaque background, which on a light app paints a black band
  // under the gesture pill. The app draws its own canvas there instead, so
  // the bar has to be transparent and the contrast scrim turned off.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarDividerColor: Color(0x00000000),
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await _initLogging();
  runApp(const ServLlamaApp());
}

Future<void> _initLogging() async {
  try {
    final sink = await FileLogSink.open();
    AppLogger.instance.attachSink(sink);
    AppLogger.instance.restore(await sink.loadRecent(1000));
    // Retained by WidgetsBinding as an observer; flushes on background/exit.
    AppLifecycleListener(
      onPause: () => unawaited(sink.flush()),
      onDetach: () => unawaited(sink.flush()),
    );
  } catch (_) {
    // Degrade to in-memory only logging if the file sink cannot be opened.
  }
}

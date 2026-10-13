import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/system_prompt_provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/core/providers/generation_params_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class ServLlamaApp extends StatelessWidget {
  const ServLlamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) {
              final provider = AppLocaleProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = AppThemeModeProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = ChatTimeoutProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          // Above ChatProvider so the chat path can read the current sampling
          // settings at the moment a request goes out.
          ChangeNotifierProvider(
            create: (_) {
              final provider = GenerationParamsProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = SystemPromptProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = EngineRuntimeProvider();
              unawaited(provider.restore());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (context) {
              final runtime = context.read<EngineRuntimeProvider>();
              final provider = ModelManagementProvider(
                onModelRenamed:
                    ({
                      required engine,
                      required oldModelId,
                      required newModelId,
                    }) => runtime.handleModelRenamed(
                      engine: engine,
                      oldModelId: oldModelId,
                      newModelId: newModelId,
                    ),
              );
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (context) {
              final modelManagement = context.read<ModelManagementProvider>();
              final provider = DownloadProvider(
                onLibraryChanged: modelManagement.refresh,
                modelNameCoordinator: modelManagement.nameCoordinator,
              );
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) {
              final provider = ModelDiscoveryProvider();
              unawaited(provider.load());
              return provider;
            },
          ),
          ChangeNotifierProxyProvider3<
            EngineRuntimeProvider,
            ChatTimeoutProvider,
            SystemPromptProvider,
            ChatProvider
          >(
            create: (_) => ChatProvider(
              generationParamsProvider: context
                  .read<GenerationParamsProvider>(),
            ),
            update:
                (
                  _,
                  runtimeProvider,
                  chatTimeoutProvider,
                  systemPromptProvider,
                  chatProvider,
                ) {
                  final provider = chatProvider ?? ChatProvider();
                  provider.updateServerState(
                    baseUrl: runtimeProvider.baseUrl,
                    isServerRunning: runtimeProvider.isRunning,
                    engine: runtimeProvider.activeEngine,
                    activeModelId: runtimeProvider.activeModelId,
                    activeModelName: runtimeProvider.activeModelName,
                  );
                  provider.updateChatTimeout(chatTimeoutProvider.timeout);
                  provider.updateSystemPrompt(systemPromptProvider.prompt);
                  return provider;
                },
          ),
        ],
        child: Consumer2<AppThemeModeProvider, AppLocaleProvider>(
          builder: (context, themeModeProvider, localeProvider, _) =>
              MaterialApp(
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appTitle,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: themeModeProvider.themeMode,
                locale: localeProvider.locale,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                // Keeps the gesture-navigation icons legible against the
                // canvas at the bottom of the screen. main.dart makes the bar
                // transparent; this decides which way the icons are tinted,
                // and it has to follow the theme because the bar sits on top
                // of whatever page is showing.
                builder: (context, child) {
                  final dark = Theme.of(context).brightness == Brightness.dark;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarBrightness: dark
                          ? Brightness.dark
                          : Brightness.light,
                      statusBarIconBrightness: dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarDividerColor: Colors.transparent,
                      systemNavigationBarContrastEnforced: false,
                      systemNavigationBarIconBrightness: dark
                          ? Brightness.light
                          : Brightness.dark,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: const MainScaffold(),
              ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/app/sheet/vela_menu.dart';
import 'package:servllama/app/sheet/vela_sheet.dart';
import 'package:servllama/features/chat/services/session_title_generator.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';
import 'package:servllama/core/providers/generation_params_provider.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/providers/system_prompt_provider.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/app/widgets/page_scaffold.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/features/about/pages/about_page.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';
import 'package:servllama/features/settings/pages/generation_params_page.dart';
import 'package:servllama/features/settings/pages/system_prompt_page.dart';
import 'package:servllama/features/settings/widgets/download_settings_section.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Not watched: it is a plain Provider, and the settings page re-reads it
    // when it comes back. Nothing rebuilds the app when a title model moves.
    final titleGenerator = context.read<SessionTitleGenerator>();

    return Consumer4<
      AppThemeModeProvider,
      AppLocaleProvider,
      ChatTimeoutProvider,
      SystemPromptProvider
    >(
      builder:
          (
            context,
            themeProvider,
            localeProvider,
            chatTimeoutProvider,
            systemPromptProvider,
            _,
          ) => PageScaffold(
            title: l10n.settingsTitle,
            maxWidth: 620,
            padding: const EdgeInsets.fromLTRB(
              ClaudeSpacing.lg,
              ClaudeSpacing.xl,
              ClaudeSpacing.lg,
              ClaudeSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: l10n.settingsSectionGeneral,
                  child: SettingsTileList(
                    children: [
                      SettingsMenuTile(
                        key: const Key('settings_theme_mode_tile'),
                        icon: ClaudeIcons.palette,
                        title: l10n.settingsThemeMode,
                        value: _themeModeLabel(l10n, themeProvider.themeMode),
                        onTap: () =>
                            _showThemeModeSheet(context, themeProvider),
                      ),
                      SettingsMenuTile(
                        key: const Key('settings_language_tile'),
                        icon: ClaudeIcons.language,
                        title: l10n.settingsLanguage,
                        value: _localeModeLabel(
                          l10n,
                          localeProvider.localeMode,
                        ),
                        onTap: () =>
                            _showLanguageSheet(context, localeProvider),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSection(
                  title: l10n.settingsSectionChat,
                  child: SettingsTileList(
                    children: [
                      SettingsMenuTile(
                        key: const Key('settings_chat_timeout_tile'),
                        icon: ClaudeIcons.timer,
                        title: l10n.settingsChatTimeout,
                        value: l10n.settingsChatTimeoutValue(
                          chatTimeoutProvider.timeoutSeconds,
                        ),
                        onTap: () =>
                            _showChatTimeoutSheet(context, chatTimeoutProvider),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const DownloadSettingsSection(),
                const SizedBox(height: 18),
                SettingsSection(
                  title: l10n.settingsSectionModel,
                  child: SettingsTileList(
                    children: [
                      SettingsMenuTile(
                        key: const Key('settings_model_library_tile'),
                        icon: ClaudeIcons.layers,
                        title: l10n.modelLibraryTitle,
                        onTap: () =>
                            _push(context, const ModelManagementPage()),
                      ),
                      SettingsMenuTile(
                        key: const Key('settings_system_prompt_tile'),
                        icon: ClaudeIcons.edit,
                        title: l10n.systemPromptTitle,
                        subtitle: systemPromptProvider.isEmpty
                            ? l10n.systemPromptEmpty
                            : systemPromptProvider.prompt,
                        onTap: () => _push(context, const SystemPromptPage()),
                      ),
                      SettingsMenuTile(
                        key: const Key('settings_generation_params_tile'),
                        icon: ClaudeIcons.sliders,
                        title: l10n.generationParamsEntry,
                        subtitle: context
                                .watch<GenerationParamsProvider>()
                                .params
                                .isEmpty
                            ? l10n.generationParamsHint
                            : context
                                      .watch<GenerationParamsProvider>()
                                      .params
                                      .toString(),
                        onTap: () =>
                            _push(context, const GenerationParamsPage()),
                      ),
                      SwitchSettingTile(
                        key: const Key('settings_title_generation_tile'),
                        title: l10n.titleGenerationEntry,
                        subtitle: l10n.titleGenerationHint,
                        value: titleGenerator.enabled,
                        onChanged: (value) =>
                            titleGenerator.setEnabled(value),
                      ),
                      SettingsMenuTile(
                        key: const Key('settings_title_model_tile'),
                        icon: ClaudeIcons.chip,
                        title: l10n.titleGenerationModel,
                        subtitle:
                            titleGenerator.modelOverrideId ??
                            l10n.titleGenerationModelHint,
                        onTap: () => _pickTitleModel(
                          context,
                          titleGenerator,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SettingsSection(
                  title: l10n.settingsSectionAbout,
                  child: SettingsTileList(
                    children: [
                      SettingsMenuTile(
                        icon: ClaudeIcons.info,
                        title: l10n.settingsAbout,
                        onTap: () => _push(context, const AboutPage()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Choose which model names conversations, or go back to reusing whatever
  /// is already running.
  Future<void> _pickTitleModel(
    BuildContext context,
    SessionTitleGenerator generator,
  ) async {
    final l10n = context.l10n;
    final library = context.read<ModelManagementProvider>();
    unawaited(library.load());
    final models = library.libraryModels;

    await showVelaSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VelaMenuItem(
              key: const Key('title_model_clear'),
              title: l10n.titleGenerationModelClear,
              leading: ClaudeIcon(ClaudeIcons.star, size: 17),
              onTap: () {
                generator.setModelOverride(null);
                Navigator.of(sheetContext).pop();
              },
            ),
            const Divider(height: ClaudeSpacing.lg),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final model in models)
                    ListTile(
                      key: Key('title_model_${model.id}'),
                      title: Text(model.title),
                      selected: generator.modelOverrideId == model.runtimeId,
                      onTap: () {
                        generator.setModelOverride(model.runtimeId);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static Future<void> _showThemeModeSheet(
    BuildContext context,
    AppThemeModeProvider provider,
  ) async {
    final l10n = context.l10n;
    await showVelaSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsThemeModeSheetTitle,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontFamily: 'serif'),
              ),
              const SizedBox(height: 14),
              ..._themeModeOptions.map(
                (option) => _ThemeModeSheetOption(
                  themeMode: option,
                  label: _themeModeLabel(l10n, option),
                  isSelected: provider.themeMode == option,
                  onTap: () async {
                    await provider.updateThemeMode(option);
                    if (!sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showLanguageSheet(
    BuildContext context,
    AppLocaleProvider provider,
  ) async {
    final l10n = context.l10n;
    await showVelaSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsLanguageSheetTitle,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontFamily: 'serif'),
              ),
              const SizedBox(height: 14),
              ..._localeModeOptions.map(
                (option) => _LocaleModeSheetOption(
                  localeMode: option,
                  label: _localeModeLabel(l10n, option),
                  isSelected: provider.localeMode == option,
                  onTap: () async {
                    await provider.updateLocaleMode(option);
                    if (!sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showChatTimeoutSheet(
    BuildContext context,
    ChatTimeoutProvider provider,
  ) async {
    await showVelaSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ChatTimeoutSheet(provider: provider),
    );
  }

  static const List<ThemeMode> _themeModeOptions = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  static const List<AppLocaleMode> _localeModeOptions = <AppLocaleMode>[
    AppLocaleMode.system,
    AppLocaleMode.zh,
    AppLocaleMode.en,
  ];

  static String _themeModeLabel(AppLocalizations l10n, ThemeMode value) {
    switch (value) {
      case ThemeMode.system:
        return l10n.themeModeSystem;
      case ThemeMode.light:
        return l10n.themeModeLight;
      case ThemeMode.dark:
        return l10n.themeModeDark;
    }
  }

  static String _localeModeLabel(AppLocalizations l10n, AppLocaleMode value) {
    switch (value) {
      case AppLocaleMode.system:
        return l10n.languageModeSystem;
      case AppLocaleMode.zh:
        return '简体中文 (ZH)';
      case AppLocaleMode.en:
        return 'English (EN)';
    }
  }
}

class _ThemeModeSheetOption extends StatelessWidget {
  const _ThemeModeSheetOption({
    required this.themeMode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode themeMode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('settings_theme_mode_option_${themeMode.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleModeSheetOption extends StatelessWidget {
  const _LocaleModeSheetOption({
    required this.localeMode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final AppLocaleMode localeMode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('settings_language_option_${localeMode.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns the timeout field's controller so it lives exactly as long as the
/// sheet does — disposing it right after `showModalBottomSheet` returns tears
/// it down while the closing animation is still rebuilding the field.
class _ChatTimeoutSheet extends StatefulWidget {
  const _ChatTimeoutSheet({required this.provider});

  final ChatTimeoutProvider provider;

  @override
  State<_ChatTimeoutSheet> createState() => _ChatTimeoutSheetState();
}

class _ChatTimeoutSheetState extends State<_ChatTimeoutSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.provider.timeoutSeconds.toString(),
  );
  late int _draftValue = widget.provider.timeoutSeconds;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _clampedInput {
    final parsed = int.tryParse(_controller.text.trim());
    return (parsed ?? _draftValue).clamp(
      ChatTimeoutProvider.minTimeoutSeconds,
      ChatTimeoutProvider.maxTimeoutSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsChatTimeoutSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsChatTimeoutDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('settings_chat_timeout_input'),
              controller: _controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null) {
                  return;
                }
                setState(() {
                  _draftValue = parsed.clamp(
                    ChatTimeoutProvider.minTimeoutSeconds,
                    ChatTimeoutProvider.maxTimeoutSeconds,
                  );
                });
              },
              decoration: InputDecoration(
                labelText: l10n.settingsChatTimeoutFieldLabel,
                suffixText: l10n.settingsChatTimeoutUnit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsChatTimeoutRange(
                ChatTimeoutProvider.minTimeoutSeconds,
                ChatTimeoutProvider.maxTimeoutSeconds,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('settings_chat_timeout_save_button'),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await widget.provider.updateTimeoutSeconds(_clampedInput);
                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                  },
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

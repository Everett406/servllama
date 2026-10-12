import 'package:flutter/material.dart';

import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/sheet/vela_menu.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/l10n/l10n.dart';

/// The model picker, as a menu anchored to the model chip.
///
/// It was a bottom sheet: three or four rows in a card that filled a third of
/// the screen, with rows sized like settings rows and a divider under each
/// one. That is a lot of surface for a list of file names, and it pushed the
/// composer out of reach every time you wanted to check which model was
/// loaded.
///
/// As a menu it hangs off the chip it belongs to, so the thing you tapped and
/// the thing that answers are in the same place on screen.
class ChatModelMenu extends StatelessWidget {
  const ChatModelMenu({
    super.key,
    required this.models,
    required this.activeModelId,
    required this.pendingModelId,
    required this.downloading,
    required this.onSelect,
    required this.onDiscover,
    this.errorText,
  });

  final List<({String id, String name, String detail})> models;
  final String? activeModelId;
  final String? pendingModelId;
  final int downloading;
  final String? errorText;
  final ValueChanged<({String id, String name, String detail})> onSelect;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              errorText!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.dangerText),
            ),
          ),
        if (models.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Text(
              l10n.chatSelectModel,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.inkTertiary),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                final selected =
                    model.id == activeModelId || model.id == pendingModelId;
                return VelaMenuItem(
                  title: model.name,
                  subtitle: model.detail.isEmpty ? null : model.detail,
                  selected: selected,
                  leading: ClaudeIcon(
                    selected ? ClaudeIcons.chip : ClaudeIcons.chip,
                    size: 16,
                    color: selected ? context.accent : context.inkTertiary,
                  ),
                  onTap: () => onSelect(model),
                );
              },
            ),
          ),
        const Divider(height: 1),
        VelaMenuItem(
          title: l10n.chatBrowseLibrary,
          leading: ClaudeIcon(
            ClaudeIcons.search,
            size: 16,
            color: context.inkTertiary,
          ),
          onTap: onDiscover,
        ),
      ],
    );
  }
}

/// The engine picker, anchored the same way.
class ChatEngineMenu extends StatelessWidget {
  const ChatEngineMenu({
    super.key,
    required this.entries,
    required this.onSelect,
  });

  final List<({String engine, String label, String detail})> entries;
  final ValueChanged<({String engine, String label, String detail})> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          VelaMenuItem(
            title: entry.label,
            subtitle: entry.detail.isEmpty ? null : entry.detail,
            selected: entry.engine == entries.first.engine,
            leading: ClaudeIcon(
              entry.engine == entries.first.engine
                  ? ClaudeIcons.fileText
                  : ClaudeIcons.chip,
              size: 16,
              color: entry.engine == entries.first.engine
                  ? context.accent
                  : context.inkTertiary,
            ),
            onTap: () => onSelect(entry),
          ),
      ],
    );
  }
}

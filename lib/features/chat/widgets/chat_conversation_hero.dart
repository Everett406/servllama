import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:servllama/l10n/l10n.dart';

/// Chat empty state. Starting the runtime is an implementation detail the
/// user should not have to think about, so the only primary action here is
/// "pick a model" — the orchestrator brings the engine up behind it (FR-C1).
class ChatConversationHero extends StatelessWidget {
  const ChatConversationHero({
    super.key,
    required this.isPreparing,
    required this.preparingLabel,
    required this.hasLibraryModels,
    required this.onOpenModels,
    required this.onDiscoverModels,
  });

  /// The orchestrator is mid-flight (loading a model, binding the port…).
  final bool isPreparing;

  /// Phase text to show while [isPreparing]; falls back to a generic label.
  final String? preparingLabel;

  /// False on a fresh install, where the only useful action is downloading.
  final bool hasLibraryModels;

  final VoidCallback? onOpenModels;
  final VoidCallback? onDiscoverModels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;
    final heroTitleColor = isLight
        ? const Color(0xFF171B24)
        : colorScheme.onSurface.withAlpha(236);
    final heroDescriptionColor = isLight
        ? const Color(0xFF7D8698)
        : colorScheme.onSurfaceVariant.withAlpha(210);
    // The copy invites; it does not report. The previous wording was a
    // status readout — "模型准备好了", "还差最后一步" — which is what a
    // loading label says. The composer's model chip and engine button are one
    // tap away and do both jobs, so a third button down here was redundant.
    final String description;
    if (isPreparing) {
      description = preparingLabel ?? l10n.chatPreparingModel;
    } else if (!hasLibraryModels) {
      description = l10n.chatEmptyNoModelsDescription;
    } else {
      description = l10n.chatEmptyDescription;
    }

    return Align(
      key: const Key('chat_conversation_hero_align'),
      // Centred and a touch above the middle. -0.236 put it well up the
      // screen, where it read as a header rather than as the thing you are
      // about to do.
      alignment: const Alignment(0, -0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('chat_empty_state_logo'),
              width: 118,
              height: 118,
              child: SvgPicture.asset('assets/app_icon.svg'),
            ),
            Text(
              l10n.chatEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) + 4,
                fontWeight: FontWeight.w500,
                color: heroTitleColor,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 292),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: heroDescriptionColor,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Secondary entry so downloading stays one tap away even once the
            // primary action has become "pick a model".
            if (!isPreparing && hasLibraryModels)
              TextButton(
                key: const Key('chat_empty_state_discover_button'),
                onPressed: onDiscoverModels,
                style: TextButton.styleFrom(
                  foregroundColor: heroDescriptionColor,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(l10n.discoverTitle),
              ),
          ],
        ),
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/app/sheet/vela_menu.dart';
import 'package:servllama/app/sheet/vela_sheet.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/widgets/claude_icons.dart';

enum ChatSessionAction { rename, pin, unpin, delete }

class ChatSessionActions {
  const ChatSessionActions._();

  /// [anchorContext] is the three-dot button. The menu hangs off it rather
  /// than rising from the bottom of the screen — the button is next to the
  /// conversation it acts on, and a sheet from the bottom of the screen is not.
  static Future<void> showSessionActions({
    required BuildContext context,
    required BuildContext presentationContext,
    required BuildContext anchorContext,
    required ChatSessionRecord session,
  }) async {
    final provider = context.read<ChatProvider>();
    if (!provider.canManageSessions) {
      return;
    }

    if (!presentationContext.mounted) {
      return;
    }
    // No settling delay before the menu opens. It was here to let a sheet's
    // entrance finish before the next route pushed; with an anchored menu
    // there is nothing to wait for, and 150ms of nothing reads as the button
    // being slow. It also meant the menu opened on a timer rather than on the
    // tap.

    final anchor = VelaAnchor.of(anchorContext);

    // An anchored menu needs a rect. Where one isn't available — the history
    // page's ListView, whose rows resolve to slivers — fall back to the sheet
    // this used to always use, instead of returning and leaving a visible
    // button that does nothing when tapped.
    Widget menuBuilder(BuildContext panelContext) {
        final l10n = panelContext.l10n;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VelaMenuItem(
              title: l10n.commonRename,
              leading: ClaudeIcon(
                ClaudeIcons.edit,
                size: 16,
                color: panelContext.inkTertiary,
              ),
              onTap: () =>
                  Navigator.of(panelContext).pop(ChatSessionAction.rename),
            ),
            VelaMenuItem(
              title: session.pinned ? l10n.commonUnpin : l10n.commonPin,
              leading: ClaudeIcon(
                ClaudeIcons.star,
                size: 16,
                color: panelContext.inkTertiary,
              ),
              onTap: () => Navigator.of(panelContext).pop(
                session.pinned
                    ? ChatSessionAction.unpin
                    : ChatSessionAction.pin,
              ),
            ),
            const Divider(height: 1),
            VelaMenuItem(
              title: l10n.commonDelete,
              leading: ClaudeIcon(
                ClaudeIcons.trash,
                size: 16,
                color: panelContext.dangerText,
              ),
              onTap: () =>
                  Navigator.of(panelContext).pop(ChatSessionAction.delete),
            ),
          ],
        );
    }

    // Both paths re-read `presentationContext` after the await; the mounted
    // check immediately below is the guard for both.
    final ChatSessionAction? action = anchor == null
        ? await showVelaSheet<ChatSessionAction>(
            // ignore: use_build_context_synchronously
            context: presentationContext,
            builder: menuBuilder,
          )
        : await anchor.show<ChatSessionAction>(
            // ignore: use_build_context_synchronously
            context: presentationContext,
            width: 200,
            builder: menuBuilder,
          );

    if (action == null || !presentationContext.mounted) {
      return;
    }

    switch (action) {
      case ChatSessionAction.rename:
        await renameSession(
          provider: provider,
          presentationContext: presentationContext,
          session: session,
        );
      case ChatSessionAction.pin:
        await provider.toggleSessionPin(session.id);
      case ChatSessionAction.unpin:
        await provider.toggleSessionPin(session.id);
      case ChatSessionAction.delete:
        await deleteSession(
          provider: provider,
          presentationContext: presentationContext,
          session: session,
        );
    }
  }

  static Future<void> renameSession({
    required ChatProvider provider,
    required BuildContext presentationContext,
    required ChatSessionRecord session,
  }) async {
    var draftTitle = session.title;
    final result = await showDialog<String>(
      context: presentationContext,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.chatRenameSessionTitle),
          content: TextFormField(
            initialValue: session.title,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.chatRenameSessionHint,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              draftTitle = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftTitle),
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }
    await provider.renameSession(session.id, result);
  }

  static Future<void> deleteSession({
    required ChatProvider provider,
    required BuildContext presentationContext,
    required ChatSessionRecord session,
  }) async {
    final confirmed = await showDialog<bool>(
      context: presentationContext,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.chatDeleteSessionTitle),
          content: Text(l10n.chatDeleteSessionConfirm(session.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    await provider.deleteSession(session.id);
  }
}

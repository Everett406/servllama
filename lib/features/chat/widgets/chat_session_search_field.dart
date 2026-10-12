import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatSessionSearchField extends StatefulWidget {
  const ChatSessionSearchField({
    super.key,
    this.fieldKey,
    this.hintText,
    this.autofocus = false,
    this.onOpenHistory,
  });

  final Key? fieldKey;
  final String? hintText;
  final bool autofocus;

  /// Reached from the trailing glyph. The full history page used to be a
  /// button in the chat header, but that header is two buttons and nothing
  /// else now — and a search box you cannot escape into the unfiltered list
  /// is a dead end for anyone who forgot a word.
  final VoidCallback? onOpenHistory;

  @override
  State<ChatSessionSearchField> createState() => _ChatSessionSearchFieldState();
}

class _ChatSessionSearchFieldState extends State<ChatSessionSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query = context.select(
      (ChatProvider provider) => provider.sessionQuery,
    );

    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return Container(
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(56)),
      ),
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: context.read<ChatProvider>().updateSessionQuery,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.hintText ?? context.l10n.chatSearchHint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIcon: ClaudeIcon(
            ClaudeIcons.search,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 26),
          suffixIcon: widget.onOpenHistory == null
              ? null
              : IconButton(
                  key: const Key('drawer_open_history_button'),
                  tooltip: context.l10n.drawerAllHistoryTooltip,
                  onPressed: widget.onOpenHistory,
                  icon: ClaudeIcon(
                    ClaudeIcons.chevronRight,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_session_actions.dart';
import 'package:servllama/l10n/l10n.dart';

/// Buckets a session into one of the five buckets the sidebar renders.
/// Uses calendar-day boundaries rather than rolling 24-hour windows — a chat
/// from 11pm that gets a reply at 1am belongs under "today" either way, and
/// users read the labels as days, not durations.
enum SessionBucket { today, yesterday, lastSevenDays, lastThirtyDays, older }

SessionBucket _bucketFor(DateTime updatedAt, DateTime now) {
  final day = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
  final today = DateTime(now.year, now.month, now.day);
  final age = today.difference(day).inDays;
  if (age <= 0) return SessionBucket.today;
  if (age == 1) return SessionBucket.yesterday;
  if (age < 7) return SessionBucket.lastSevenDays;
  if (age < 30) return SessionBucket.lastThirtyDays;
  return SessionBucket.older;
}

/// The sidebar's conversation list: search-filtered sessions rendered as flat
/// rows under date headers.
class ChatSessionList extends StatelessWidget {
  const ChatSessionList({
    super.key,
    this.onSessionOpened,
    this.onSessionSelected,
    this.itemKeyPrefix = 'chat_session_item',
    this.menuKeyPrefix = 'chat_session_actions',
  });

  /// Called *before* the switch starts — used by the sidebar to dismiss the
  /// overlay drawer while the transition runs.
  final FutureOr<void> Function()? onSessionOpened;

  /// Overrides the default behaviour (switch to the session, staged). The
  /// history page supplies its own so it can pop its route instead.
  final ValueChanged<String>? onSessionSelected;

  /// Key namespaces. The sidebar and the history page render the same rows
  /// but tests address them under separate prefixes, so the prefix is part of
  /// the component's contract rather than hard-coded.
  final String itemKeyPrefix;
  final String menuKeyPrefix;

  Future<void> _open(ChatProvider provider, String sessionId) async {
    final override = onSessionSelected;
    if (override != null) {
      override(sessionId);
      return;
    }
    final before = onSessionOpened;
    if (before != null) unawaited(Future<void>.sync(before));
    await provider.switchSession(sessionId, staged: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.sessions.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final sessions = provider.filteredSessions;
        if (sessions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.xl),
              child: Text(
                provider.sessionQuery.trim().isEmpty
                    ? context.l10n.chatSessionEmpty
                    : context.l10n.chatSessionNotFound,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }

        final grouped = _groupByBucket(sessions);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            ClaudeSpacing.sm,
            ClaudeSpacing.sm,
            ClaudeSpacing.sm,
            ClaudeSpacing.lg,
          ),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final entry = grouped[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BucketHeader(label: _bucketLabel(context, entry.bucket)),
                for (final session in entry.sessions)
                  _SessionRow(
                    // Keyed by id only. Folding the selection into the key
                    // would tear down and rebuild the row on every switch,
                    // which a lazily built list turns into dropped items.
                    key: Key('${itemKeyPrefix}_${session.id}'),
                    session: session,
                    selected: provider.selectedSession?.id == session.id,
                    enabled: provider.canManageSessions,
                    menuKey: Key('${menuKeyPrefix}_${session.id}'),
                    onTap: () => _open(provider, session.id),
                    onMore: () => ChatSessionActions.showSessionActions(
                      context: context,
                      presentationContext: context,
                      session: session,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static String _bucketLabel(BuildContext context, SessionBucket bucket) {
    final l10n = context.l10n;
    return switch (bucket) {
      SessionBucket.today => l10n.chatGroupToday,
      SessionBucket.yesterday => l10n.chatGroupYesterday,
      SessionBucket.lastSevenDays => l10n.chatGroupPreviousSevenDays,
      SessionBucket.lastThirtyDays => l10n.chatGroupPreviousThirtyDays,
      SessionBucket.older => l10n.chatGroupOlder,
    };
  }

  static List<({SessionBucket bucket, List<ChatSessionRecord> sessions})>
  _groupByBucket(List<ChatSessionRecord> sessions) {
    final now = DateTime.now();
    final buckets = <SessionBucket, List<ChatSessionRecord>>{};
    for (final session in sessions) {
      buckets
          .putIfAbsent(
            _bucketFor(session.updatedAt, now),
            () => <ChatSessionRecord>[],
          )
          .add(session);
    }
    final grouped =
        <({SessionBucket bucket, List<ChatSessionRecord> sessions})>[];
    for (final bucket in SessionBucket.values) {
      final group = buckets[bucket];
      if (group != null && group.isNotEmpty) {
        grouped.add((bucket: bucket, sessions: group));
      }
    }
    return grouped;
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.inkTertiary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SessionRow extends StatefulWidget {
  const _SessionRow({
    super.key,
    required this.session,
    required this.selected,
    required this.enabled,
    required this.menuKey,
    required this.onTap,
    required this.onMore,
  });

  final ChatSessionRecord session;
  final bool selected;
  final bool enabled;
  final Key menuKey;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ClaudeRadius.sm);
    final background = widget.selected
        ? context.accentSubtle
        : _hovered
        ? context.surface
        : Colors.transparent;
    final foreground = widget.selected ? context.accent : context.ink;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onMore : null,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                // Always mounted, quiet until hovered. Hiding it on idle is
                // wrong on touch: there is no hover state, so the row's only
                // affordance would be a long-press nobody discovers.
                AnimatedOpacity(
                  opacity: widget.enabled ? (_hovered ? 1 : 0.45) : 0.3,
                  duration: ClaudeMotion.fast,
                  child: IconButton(
                    key: widget.menuKey,
                    onPressed: widget.enabled ? widget.onMore : null,
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 28,
                    ),
                    color: context.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

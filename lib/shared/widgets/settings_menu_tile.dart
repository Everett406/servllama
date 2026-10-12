import 'package:flutter/material.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// A single row in a settings group.
///
/// Typography is deliberately mid-weight: the old tile used w700 throughout,
/// which made an entire settings page look like a list of alerts. Weight now
/// carries hierarchy — the title is merely emphasised, the value recedes.
class SettingsMenuTile extends StatefulWidget {
  const SettingsMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.enabled = true,
    this.showDivider = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;

  /// When non-null, replaces the value + chevron. Use for in-row controls.
  final Widget? trailing;

  /// When set, the whole row is tappable and a chevron is shown.
  final VoidCallback? onTap;

  final bool enabled;

  /// Draws a hairline under this row. Prefer explicit control over
  /// auto-dividers so the last row can stay unlined.
  final bool showDivider;

  final Color? iconColor;

  @override
  State<SettingsMenuTile> createState() => _SettingsMenuTileState();
}

class _SettingsMenuTileState extends State<SettingsMenuTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = widget.enabled ? widget.onTap : null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ClaudeSpacing.lg,
        vertical: 13,
      ),
      child: Row(
        children: [
          ClaudeIcons.render(
            widget.icon,
            size: 20,
            color: widget.enabled
                ? (widget.iconColor ?? context.inkSecondary)
                : context.inkTertiary,
          ),
          const SizedBox(width: ClaudeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.enabled ? context.ink : context.inkTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.subtitle!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: ClaudeSpacing.md),
            widget.trailing!,
          ] else if (widget.value != null) ...[
            const SizedBox(width: ClaudeSpacing.md),
            Text(
              widget.value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (widget.trailing == null && effectiveOnTap != null) ...[
            const SizedBox(width: ClaudeSpacing.xs),
            ClaudeIcon(
              ClaudeIcons.chevronRight,
              color: context.inkTertiary,
              size: 20,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: effectiveOnTap != null,
      enabled: widget.enabled,
      child: Material(
        color: _isPressed ? context.surfaceSunken : Colors.transparent,
        child: InkWell(
          onTap: effectiveOnTap,
          onTapDown: effectiveOnTap == null
              ? null
              : (_) => setState(() => _isPressed = true),
          onTapCancel: effectiveOnTap == null
              ? null
              : () => setState(() => _isPressed = false),
          onTapUp: effectiveOnTap == null
              ? null
              : (_) => setState(() => _isPressed = false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              if (widget.showDivider)
                Divider(height: 1, indent: 52, color: context.border),
            ],
          ),
        ),
      ),
    );
  }
}

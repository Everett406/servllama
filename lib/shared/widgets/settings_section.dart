import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// A titled group of settings.
///
/// Rows are separated by hairlines rather than stacked as individual cards —
/// a column of boxes inside a box is what made the old settings screen feel
/// heavy, and one container per group keeps the rhythm without doubling the
/// border count.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: ClaudeSpacing.xs,
              bottom: ClaudeSpacing.xs,
            ),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.inkTertiary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(
              left: ClaudeSpacing.xs,
              bottom: ClaudeSpacing.sm,
              right: ClaudeSpacing.xl,
            ),
            child: Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        if (title != null || subtitle != null)
          const SizedBox(height: ClaudeSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(ClaudeRadius.lg),
            border: Border.all(color: context.border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

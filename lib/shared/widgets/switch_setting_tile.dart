import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// A label + description + switch row. The whole row toggles, which matters
/// on phones where the switch itself is a small target.
class SwitchSettingTile extends StatelessWidget {
  const SwitchSettingTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// Optional, and the point of making it so: a switch row sitting beside a
  /// menu row used to have no icon and bolder text, so the same column looked
  /// like two designs. Pass the same icon the neighbour uses and the rows
  /// line up.
  final IconData? icon;

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// False greys the row out and the row stops taking taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ClaudeSpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: context.inkSecondary),
                  const SizedBox(width: ClaudeSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        // w500, matching SettingsMenuTile. w600 here made
                        // every switch in the same list look bolder than the
                        // menu rows above and below it.
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.inkTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: ClaudeSpacing.md),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

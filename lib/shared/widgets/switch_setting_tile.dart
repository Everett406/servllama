import 'package:flutter/material.dart';
import 'package:servllama/app/design/tokens.dart';

/// A label + description + switch row. The whole row toggles, which matters
/// on phones where the switch itself is a small target.
class SwitchSettingTile extends StatelessWidget {
  const SwitchSettingTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClaudeSpacing.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: ClaudeSpacing.md),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

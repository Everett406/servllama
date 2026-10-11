import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

class SegmentedSettingOption<T> {
  const SegmentedSettingOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A single-choice control rendered as a flat pill group.
///
/// Material's SegmentedButton draws an outline around the whole control plus
/// one around each segment, which is three borders for one decision. This
/// puts the border on the track and uses a filled accent for the selection.
class SegmentedSetting<T> extends StatelessWidget {
  const SegmentedSetting({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final T value;
  final List<SegmentedSettingOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ClaudeSpacing.xs),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(
              top: 2,
              left: ClaudeSpacing.xs,
              right: ClaudeSpacing.xl,
            ),
            child: Text(
              description!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(height: 1.45),
            ),
          ),
        const SizedBox(height: ClaudeSpacing.sm),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.surfaceSunken,
            borderRadius: BorderRadius.circular(ClaudeRadius.md),
          ),
          child: Row(
            children: [
              for (final option in options)
                Expanded(
                  child: _Segment<T>(
                    label: option.label,
                    selected: option.value == value,
                    onTap: () => onChanged(option.value),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ClaudeMotion.fast,
      curve: ClaudeMotion.curve,
      decoration: BoxDecoration(
        color: selected ? context.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(ClaudeRadius.sm),
        border: Border.all(
          color: selected ? context.border : Colors.transparent,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ClaudeRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? context.ink : context.inkSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

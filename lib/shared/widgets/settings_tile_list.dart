import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';

/// A vertical list of setting tiles separated by hairlines.
///
/// Dividers are inset past the icon column so the rule reads as connecting
/// the labels rather than the icons.
class SettingsTileList extends StatelessWidget {
  const SettingsTileList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, indent: 52, color: context.border),
        ],
      ],
    );
  }
}

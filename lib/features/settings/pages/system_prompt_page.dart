import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/providers/system_prompt_provider.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/l10n/l10n.dart';

/// The system prompt editor.
///
/// A full page rather than a dialog: prompts run to paragraphs, and a prompt
/// that has to live in a scrolling sheet gets truncated exactly where the
/// instruction that mattered is. The live counter is there because the limit
/// is real and a silent truncation would be worse than a visible one.
class SystemPromptPage extends StatefulWidget {
  const SystemPromptPage({super.key});

  @override
  State<SystemPromptPage> createState() => _SystemPromptPageState();
}

class _SystemPromptPageState extends State<SystemPromptPage> {
  late final TextEditingController _controller = TextEditingController(
    text: context.read<SystemPromptProvider>().prompt,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save(String value) {
    context.read<SystemPromptProvider>().updatePrompt(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final length = _controller.text.characters.length;

    return Scaffold(
      backgroundColor: context.canvas,
      appBar: AppBar(
        backgroundColor: context.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.systemPromptTitle),
        leading: IconButton(
          key: const Key('system_prompt_back_button'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ClaudeSpacing.lg,
            ClaudeSpacing.md,
            ClaudeSpacing.lg,
            ClaudeSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.systemPromptHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.inkTertiary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: ClaudeSpacing.md),
              Expanded(
                child: TextField(
                  key: const Key('system_prompt_field'),
                  controller: _controller,
                  onChanged: (value) {
                    _save(value);
                    setState(() {});
                  },
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.65),
                  cursorColor: context.accent,
                  decoration: InputDecoration(
                    hintText: l10n.systemPromptPlaceholder,
                    hintStyle: TextStyle(color: context.inkTertiary),
                    filled: true,
                    fillColor: context.surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ClaudeRadius.lg),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ClaudeRadius.lg),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ClaudeRadius.lg),
                      borderSide: BorderSide(color: context.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ClaudeSpacing.sm),
              Row(
                children: [
                  ClaudeIcon(
                    ClaudeIcons.info,
                    size: 13,
                    color: context.inkTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$length / ${SystemPromptProvider.maxLength}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: length >= SystemPromptProvider.maxLength
                            ? context.dangerText
                            : context.inkTertiary,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('system_prompt_clear_button'),
                    onPressed: length == 0
                        ? null
                        : () {
                            _controller.clear();
                            _save('');
                            setState(() {});
                          },
                    child: Text(l10n.commonClear),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

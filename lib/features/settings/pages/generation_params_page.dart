import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/providers/generation_params_provider.dart';
import 'package:servllama/l10n/l10n.dart';

/// Sampling settings, one row per parameter.
///
/// Every row starts empty and *stays* empty until the user types a number.
/// That is not a placeholder to be tidied up later — it means "let the model
/// decide", and it is why the request body omits the key entirely. A page
/// that opened with sensible-looking defaults would be silently changing how
/// the model behaves, which is the one thing a settings page must never do.
class GenerationParamsPage extends StatelessWidget {
  const GenerationParamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<GenerationParamsProvider>();
    final params = provider.params;

    return Scaffold(
      backgroundColor: context.canvas,
      appBar: AppBar(
        backgroundColor: context.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.generationParamsTitle),
        leading: IconButton(
          key: const Key('generation_params_back_button'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ClaudeSpacing.lg,
            ClaudeSpacing.md,
            ClaudeSpacing.lg,
            ClaudeSpacing.xl,
          ),
          children: [
            Text(
              l10n.generationParamsHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.inkTertiary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: ClaudeSpacing.lg),
            _NumberRow(
              field: GenerationParamField.temperature,
              key: const Key('generation_params_temperature'),
              label: l10n.generationParamsTemperature,
              hint: l10n.generationParamsTemperatureHint,
              value: params.temperature,
              min: 0,
              max: 2,
              decimals: 2,
              onChanged: (value) => provider.update(
                params.copyWith(
                  temperature: value,
                  clearTemperature: value == null,
                ),
              ),
            ),
            _NumberRow(
              field: GenerationParamField.topP,
              key: const Key('generation_params_top_p'),
              label: l10n.generationParamsTopP,
              hint: l10n.generationParamsTopPHint,
              value: params.topP,
              min: 0,
              max: 1,
              decimals: 2,
              onChanged: (value) => provider.update(
                params.copyWith(topP: value, clearTopP: value == null),
              ),
            ),
            _NumberRow(
              field: GenerationParamField.topK,
              key: const Key('generation_params_top_k'),
              label: l10n.generationParamsTopK,
              hint: l10n.generationParamsTopKHint,
              value: params.topK?.toDouble(),
              min: 1,
              max: 200,
              decimals: 0,
              onChanged: (value) => provider.update(
                params.copyWith(
                  topK: value?.round(),
                  clearTopK: value == null,
                ),
              ),
            ),
            _NumberRow(
              field: GenerationParamField.repeatPenalty,
              key: const Key('generation_params_repeat_penalty'),
              label: l10n.generationParamsRepeatPenalty,
              hint: l10n.generationParamsRepeatPenaltyHint,
              value: params.repeatPenalty,
              min: 0.5,
              max: 2,
              decimals: 2,
              onChanged: (value) => provider.update(
                params.copyWith(
                  repeatPenalty: value,
                  clearRepeatPenalty: value == null,
                ),
              ),
            ),
            _NumberRow(
              field: GenerationParamField.maxTokens,
              key: const Key('generation_params_max_tokens'),
              label: l10n.generationParamsMaxTokens,
              hint: l10n.generationParamsMaxTokensHint,
              value: params.maxTokens?.toDouble(),
              min: 1,
              max: 131072,
              decimals: 0,
              onChanged: (value) => provider.update(
                params.copyWith(
                  maxTokens: value?.round(),
                  clearMaxTokens: value == null,
                ),
              ),
            ),
            const SizedBox(height: ClaudeSpacing.lg),
            OutlinedButton.icon(
              key: const Key('generation_params_reset_button'),
              onPressed: params.isEmpty ? null : provider.reset,
              icon: ClaudeIcon(ClaudeIcons.star, size: 16),
              label: Text(l10n.generationParamsReset),
            ),
          ],
        ),
      ),
    );
  }
}

/// One parameter: label, explanation, and a field that is empty when unset.
class _NumberRow extends StatefulWidget {
  const _NumberRow({
    super.key,
    required this.field,
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.decimals,
    required this.onChanged,
  });

  final GenerationParamField field;
  final String label;
  final String hint;
  final double? value;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double?> onChanged;

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value == null ? '' : _format(widget.value!),
  );
  late final FocusNode _focusNode = FocusNode();

  static String _format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(covariant _NumberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only adopt an external change; the field is the source of truth while it
    // has focus and reformatting under the user's cursor is maddening.
    if (widget.value != oldWidget.value && !_focused) {
      _controller.text = widget.value == null ? '' : _format(widget.value!);
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_markFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_markFocus);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _markFocus() {
    _focused = _focusNode.hasFocus;
  }

  bool _focused = false;

  void _commit(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    widget.onChanged(parsed.clamp(widget.min, widget.max));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            widget.hint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
          const SizedBox(height: ClaudeSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 132,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: _commit,
                  onSubmitted: _commit,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    // "unset" is the state the row opens in, so it has to
                    // read as a state and not as an empty mistake.
                    hintText: widget.value == null
                        ? l10n.generationParamsUnsetHint
                        : null,
                    prefixText: '  ',
                  ),
                ),
              ),
              const SizedBox(width: ClaudeSpacing.sm),
              if (widget.value != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged(null);
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

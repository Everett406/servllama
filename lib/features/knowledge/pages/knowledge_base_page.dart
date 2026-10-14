import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/providers/knowledge_base_provider.dart';
import 'package:servllama/features/knowledge/models/embedding_model_descriptor.dart';
import 'package:servllama/features/knowledge/models/retrieval_settings.dart';
import 'package:servllama/features/knowledge/services/embedding_model_store.dart';
import 'package:servllama/features/knowledge/pages/knowledge_documents_page.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';

/// The knowledge base: the embedding model, the documents, and how much of
/// both to use.
///
/// Three things this page has to make obvious, because each one used to be
/// invisible and each made the feature look broken:
///   - **No model is chosen.** Embeddings come from a second llama-server
///     running an embedding GGUF, and the chat server cannot supply them: in
///     single-model mode it ignores the `model` field of a request.
///   - **No documents.** A library with nothing in it searches nothing.
///   - **How much is retrieved.** Three passages or eight, and a floor of
///     0.18 or 0.45, is the difference between an answer and a shrug.
class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<KnowledgeBaseProvider>();
    if (!provider.isLoaded) {
      provider.load();
    }
  }

  @override
  void dispose() {
    // The embedding server has an idle timer, but the last page this feature
    // owns being closed is a stronger signal than a timer.
    context.read<KnowledgeBaseProvider>().shutdown();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final provider = context.read<KnowledgeBaseProvider>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (picked == null) return;

    for (final platformFile in picked.files) {
      final path = platformFile.path;
      if (path == null) continue;
      await provider.importFile(path: path);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickModelFile() async {
    final provider = context.read<KnowledgeBaseProvider>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await provider.adoptModelFile(path);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<KnowledgeBaseProvider>();
    final documents = provider.documents;

    return Scaffold(
      backgroundColor: context.canvas,
      appBar: AppBar(
        backgroundColor: context.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.knowledgeTitle),
        leading: IconButton(
          key: const Key('knowledge_back_button'),
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
            _ModelSection(provider: provider, onPickFile: _pickModelFile),
            const SizedBox(height: ClaudeSpacing.lg),
            _RetrievalSection(provider: provider),
            const SizedBox(height: ClaudeSpacing.lg),
            _DocumentsEntry(
              provider: provider,
              documents: documents,
              onPick: _pickDocument,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const KnowledgeDocumentsPage(),
                ),
              ),
            ),
            if (provider.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: ClaudeSpacing.md),
                child: Text(
                  provider.lastError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- embedding model ----------------------------------------------------

class _ModelSection extends StatelessWidget {
  const _ModelSection({required this.provider, required this.onPickFile});

  final KnowledgeBaseProvider provider;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = provider.selectedModel;

    return _Card(
      title: l10n.knowledgeModelTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected == null)
            Text(
              l10n.knowledgeModelNoneSelected,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.accent),
            )
          else
            _SelectedModelRow(model: selected, provider: provider),
          const SizedBox(height: ClaudeSpacing.sm),
          for (final descriptor in EmbeddingModelDescriptor.all)
            _BuiltInModelRow(
              descriptor: descriptor,
              provider: provider,
              onPickFile: onPickFile,
            ),
          const SizedBox(height: ClaudeSpacing.xs),
          OutlinedButton.icon(
            key: const Key('knowledge_use_own_model_button'),
            onPressed: provider.isBusy ? null : onPickFile,
            icon: ClaudeIcon(ClaudeIcons.chip, size: 16),
            label: Text(l10n.knowledgeUseOwnModel),
          ),
          Text(
            l10n.knowledgeUseOwnModelHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _SelectedModelRow extends StatelessWidget {
  const _SelectedModelRow({required this.model, required this.provider});

  final InstalledEmbeddingModel model;
  final KnowledgeBaseProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClaudeIcon(ClaudeIcons.star, size: 14, color: context.accent),
              const SizedBox(width: ClaudeSpacing.sm),
              Expanded(
                child: Text(
                  model.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const Key('knowledge_clear_model_button'),
                onPressed: () => provider.selectModel(model).then((_) {}),
                child: Text(l10n.commonClear),
              ),
            ],
          ),
          Text(
            model.dimensions == null
                // Unknown width, said out loud: guessing it is exactly how an
                // index becomes silently unsearchable.
                ? l10n.knowledgeModelUnknownSize
                : l10n.knowledgeEmbeddingNote(model.dimensions!, model.maxTokens),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
          // The one combination that is definitely wrong, called out rather
          // than left for the user to discover through a search that never
          // finds anything.
          if (!model.looksLikeEmbeddingModel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.knowledgeModelMayNotEmbed,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.accent),
              ),
            ),
          if (provider.needsRebuild)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.knowledgeRebuildRequired,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.accent),
              ),
            ),
          if (provider.needsRebuild)
            OutlinedButton(
              key: const Key('knowledge_rebuild_button'),
              onPressed: provider.isBusy ? null : provider.rebuild,
              child: Text(l10n.knowledgeRebuild),
            ),
        ],
      ),
    );
  }
}

class _BuiltInModelRow extends StatelessWidget {
  const _BuiltInModelRow({
    required this.descriptor,
    required this.provider,
    required this.onPickFile,
  });

  final EmbeddingModelDescriptor descriptor;
  final KnowledgeBaseProvider provider;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final installed = provider.models
        .where((model) => model.id == descriptor.id)
        .firstOrNull;
    final isSelected = provider.selectedModel?.id == descriptor.id;
    final progress = provider.downloadProgress;

    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descriptor.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${descriptor.dimensions} 维 · '
                      '${(descriptor.approxBytes / 1024 / 1024).round()} MB',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Text(
                  l10n.knowledgeModelInUse,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.accent),
                )
              else if (installed != null)
                TextButton(
                  key: Key('knowledge_select_${descriptor.id}'),
                  onPressed: () => provider.selectModel(installed),
                  child: Text(l10n.knowledgeModelUse),
                )
              else
                TextButton(
                  key: Key('knowledge_download_${descriptor.id}'),
                  onPressed: provider.isBusy
                      ? null
                      : () => provider.downloadModel(descriptor),
                  child: Text(l10n.knowledgeModelDownload),
                ),
              if (installed != null)
                IconButton(
                  tooltip: l10n.commonDelete,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => provider.deleteModel(installed),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
            ],
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: progress),
            ),
        ],
      ),
    );
  }
}

// ---- retrieval ----------------------------------------------------------

class _RetrievalSection extends StatelessWidget {
  const _RetrievalSection({required this.provider});

  final KnowledgeBaseProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = provider.settings;

    return _Card(
      title: l10n.knowledgeRetrievalTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchSettingTile(
            key: const Key('knowledge_retrieval_switch'),
            title: l10n.knowledgeAllowLookup,
            subtitle: l10n.knowledgeAllowLookupHint,
            value: provider.retrievalEnabled,
            enabled: provider.hasModel,
            onChanged: (value) => provider.setRetrievalEnabled(value),
          ),
          const Divider(height: ClaudeSpacing.lg),
          SwitchSettingTile(
            key: const Key('knowledge_model_decides_switch'),
            title: l10n.knowledgeModelDecidesTitle,
            subtitle: l10n.knowledgeModelDecidesHint,
            value: provider.modelDecides,
            enabled: provider.hasIndexedDocuments,
            onChanged: (value) => provider.setModelDecides(value),
          ),
          const Divider(height: ClaudeSpacing.lg),
          Text(
            l10n.knowledgePresetTitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: ClaudeSpacing.xs),
          Wrap(
            spacing: ClaudeSpacing.xs,
            children: [
              for (final preset in RetrievalPreset.values)
                ChoiceChip(
                  key: Key('knowledge_preset_${preset.name}'),
                  label: Text(_presetLabel(l10n, preset)),
                  selected: settings.effectivePreset == preset,
                  onSelected: (_) => provider.applyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: ClaudeSpacing.md),
          _SliderRow(
            label: l10n.knowledgeMaxChunks,
            hint: l10n.knowledgeMaxChunksHint,
            value: settings.maxChunks.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            format: (value) => value.round().toString(),
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(maxChunks: value.round()),
            ),
          ),
          _SliderRow(
            label: l10n.knowledgeMinScore,
            hint: l10n.knowledgeMinScoreHint,
            value: settings.minScore,
            min: 0.05,
            max: 0.8,
            divisions: 15,
            format: (value) => value.toStringAsFixed(2),
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(minScore: value)),
          ),
          _SliderRow(
            label: l10n.knowledgeCharBudget,
            hint: l10n.knowledgeCharBudgetHint,
            value: settings.charBudget.toDouble(),
            min: 200,
            max: 4000,
            divisions: 19,
            format: (value) => value.round().toString(),
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(charBudget: value.round()),
            ),
          ),
          _SliderRow(
            label: l10n.knowledgePerChunkChars,
            hint: l10n.knowledgePerChunkCharsHint,
            value: settings.perChunkChars.toDouble(),
            min: 100,
            max: 1200,
            divisions: 11,
            format: (value) => value.round().toString(),
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(perChunkChars: value.round()),
            ),
          ),
        ],
      ),
    );
  }
}

String _presetLabel(AppLocalizations l10n, RetrievalPreset preset) =>
    switch (preset) {
      RetrievalPreset.precise => l10n.knowledgePresetPrecise,
      RetrievalPreset.balanced => l10n.knowledgePresetBalanced,
      RetrievalPreset.exhaustive => l10n.knowledgePresetExhaustive,
    };

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // The value is shown next to the label rather than in a bubble: a bubble
    // anchored to a slider on a narrow screen is its own overflow problem,
    // and the number is two inches from where the thumb is anyway.
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
              Text(
                format(value),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.accent,
                ),
              ),
            ],
          ),
          Slider(
            key: Key('knowledge_slider_$label'),
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
                        onChanged: onChanged,
          ),
          Text(
            hint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// A row into the document list, not the list itself.
///
/// A library of fifty files is not a settings screen. It used to be one: the
/// documents lived inline under the model picker and the sliders, so the
/// page grew without limit and every scroll started at the configuration you
/// came to change.
class _DocumentsEntry extends StatelessWidget {
  const _DocumentsEntry({
    required this.provider,
    required this.documents,
    required this.onPick,
    required this.onOpen,
  });

  final KnowledgeBaseProvider provider;
  final List<KnowledgeDocument> documents;
  final VoidCallback onPick;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Card(
      title: l10n.knowledgeDocumentsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsMenuTile(
            key: const Key('knowledge_open_documents'),
            icon: ClaudeIcons.fileText,
            title: documents.isEmpty
                ? l10n.knowledgeDocumentsEmpty
                : l10n.knowledgeDocumentsCount(documents.length),
            value: l10n.knowledgeDocumentsAction,
            onTap: onOpen,
          ),
          if (provider.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: ClaudeSpacing.sm),
              child: Text(
                provider.lastError!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.accent),
              ),
            ),
          const SizedBox(height: ClaudeSpacing.sm),
          FilledButton.tonalIcon(
            key: const Key('knowledge_import_documents'),
            onPressed: onPick,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: Text(l10n.knowledgeImportDocuments),
          ),
        ],
      ),
    );
  }
}

// ---- documents ----------------------------------------------------------

/// A titled group. One frame, consistent radius, no nesting.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ClaudeSpacing.md),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(ClaudeRadius.lg),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClaudeSpacing.sm),
          child,
        ],
      ),
    );
  }
}
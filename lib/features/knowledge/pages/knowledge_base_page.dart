import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/providers/knowledge_base_provider.dart';
import 'package:servllama/features/knowledge/models/embedding_model_descriptor.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';

/// The knowledge base: what is in it, and whether chat may look.
///
/// Retrieval is on by default and the model decides when to search. Both
/// defaults are visible and reversible here, because a feature that silently
/// reads someone's documents is not one to bury in a submenu.
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<KnowledgeBaseProvider>();
    final documents = provider.documents;
    const model = EmbeddingModelDescriptor.defaultModel;

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
            SwitchSettingTile(
              key: const Key('knowledge_retrieval_switch'),
              title: l10n.knowledgeRetrievalTitle,
              subtitle: l10n.knowledgeRetrievalHint,
              value: provider.retrievalEnabled,
              onChanged: (value) => provider.setRetrievalEnabled(value),
            ),
            SwitchSettingTile(
              key: const Key('knowledge_model_decides_switch'),
              title: l10n.knowledgeModelDecidesTitle,
              subtitle: l10n.knowledgeModelDecidesHint,
              value: provider.modelDecides,
              // The switch is disabled with an empty library: there is
              // nothing for either setting to decide.
              onChanged: provider.hasIndexedDocuments
                  ? (value) => provider.setModelDecides(value)
                  : (_) {},
            ),
            const SizedBox(height: ClaudeSpacing.sm),
            _EmbeddingNote(model: model, provider: provider),
            const SizedBox(height: ClaudeSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.knowledgeDocumentsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (provider.isBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: ClaudeSpacing.sm),
            if (documents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ClaudeSpacing.lg),
                child: Text(
                  l10n.knowledgeEmpty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.inkTertiary,
                    height: 1.6,
                  ),
                ),
              ),
            for (final document in documents)
              _DocumentTile(
                document: document,
                onRemove: () => provider.remove(document.id),
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

class _EmbeddingNote extends StatelessWidget {
  const _EmbeddingNote({required this.model, required this.provider});

  final EmbeddingModelDescriptor model;
  final KnowledgeBaseProvider provider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final needsRebuild = provider.needsRebuild(model);

    return Container(
      padding: const EdgeInsets.all(ClaudeSpacing.md),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(ClaudeRadius.sm),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClaudeIcon(ClaudeIcons.chip, size: 15),
              const SizedBox(width: ClaudeSpacing.sm),
              Expanded(
                child: Text(
                  model.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.knowledgeEmbeddingNote(model.dimensions, model.maxTokens),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
          // Vectors from two models are not comparable, so a model change is
          // not a preference — it invalidates the index.
          if (needsRebuild) ...[
            const SizedBox(height: ClaudeSpacing.sm),
            Text(
              l10n.knowledgeRebuildRequired,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.accent),
            ),
            const SizedBox(height: ClaudeSpacing.xs),
            OutlinedButton(
              key: const Key('knowledge_rebuild_button'),
              onPressed: provider.isBusy
                  ? null
                  : () => provider.rebuild(model),
              child: Text(l10n.knowledgeRebuild),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onRemove});

  final KnowledgeDocument document;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  document.error != null
                      ? l10n.knowledgeDocumentFailed
                      : l10n.knowledgeDocumentIndexed(document.chunkCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: document.error != null
                        ? context.accent
                        : context.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('knowledge_remove_${document.id}'),
            tooltip: l10n.commonDelete,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

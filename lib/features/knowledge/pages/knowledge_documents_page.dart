import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';
import 'package:servllama/app/widgets/claude_icons.dart';
import 'package:servllama/core/providers/knowledge_base_provider.dart';
import 'package:servllama/features/knowledge/services/knowledge_index.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/app/sheet/vela_sheet.dart';

/// The documents themselves.
///
/// Separate from the configuration because a library grows without limit
/// while the model picker and the retrieval sliders do not. Keeping them on
/// one page meant scrolling past the settings to reach the file you wanted to
/// remove, and scrolling past the file list to reach a slider you wanted to
/// nudge.
class KnowledgeDocumentsPage extends StatefulWidget {
  const KnowledgeDocumentsPage({super.key});

  @override
  State<KnowledgeDocumentsPage> createState() =>
      _KnowledgeDocumentsPageState();
}

class _KnowledgeDocumentsPageState extends State<KnowledgeDocumentsPage> {
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

  Future<void> _confirmDelete(KnowledgeDocument document) async {
    final l10n = context.l10n;
    final confirmed = await showVelaSheet<bool>(
      context: context,
      builder: (sheetContext) => _DeleteSheet(
        name: document.title,
        confirmLabel: l10n.knowledgeDeleteDocument,
        cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<KnowledgeBaseProvider>().remove(document.id);
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
        title: Text(l10n.knowledgeDocumentsTitle),
        leading: IconButton(
          key: const Key('knowledge_documents_back_button'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
        ),
      ),
      body: SafeArea(
        top: false,
        child: documents.isEmpty
            ? _EmptyLibrary(onPick: _pickDocument)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  ClaudeSpacing.lg,
                  ClaudeSpacing.md,
                  ClaudeSpacing.lg,
                  ClaudeSpacing.xl,
                ),
                itemCount: documents.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: ClaudeSpacing.xs),
                itemBuilder: (context, index) {
                  if (index == documents.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: ClaudeSpacing.md),
                      child: FilledButton.tonalIcon(
                        key: const Key('knowledge_import_documents_page'),
                        onPressed: _pickDocument,
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: Text(l10n.knowledgeImportDocuments),
                      ),
                    );
                  }
                  final document = documents[index];
                  return _DocumentTile(
                    document: document,
                    onDelete: () => _confirmDelete(document),
                  );
                },
              ),
      ),
    );
  }
}

/// Says what is missing instead of showing an empty list that reads as a bug.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ClaudeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ClaudeIcons.file,
              size: 34,
              color: context.inkTertiary,
            ),
            const SizedBox(height: ClaudeSpacing.md),
            Text(
              l10n.knowledgeDocumentsEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.inkTertiary,
              ),
            ),
            const SizedBox(height: ClaudeSpacing.lg),
            FilledButton.tonalIcon(
              key: const Key('knowledge_import_documents_empty'),
              onPressed: onPick,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(l10n.knowledgeImportDocuments),
            ),
          ],
        ),
      ),
    );
  }
}

/// A file and what is known about it.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onDelete});

  final KnowledgeDocument document;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Zero chunks means the file is in the library but was never embedded —
    // a real state worth showing, and indistinguishable from "empty" if it
    // just said "0 chunks".
    final indexed = document.chunkCount > 0 && document.error == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ClaudeSpacing.md,
        ClaudeSpacing.sm,
        ClaudeSpacing.xs,
        ClaudeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(ClaudeRadius.lg),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Icon(ClaudeIcons.file, size: 19, color: context.inkTertiary),
          const SizedBox(width: ClaudeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  indexed
                      ? l10n.knowledgeDocumentChunks(document.chunkCount)
                      : (document.error ?? l10n.knowledgeDocumentNotIndexed),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('knowledge_delete_${document.path.hashCode}'),
            tooltip: l10n.knowledgeDeleteDocument,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: context.inkTertiary,
          ),
        ],
      ),
    );
  }
}

/// One confirmation, no more. Deleting re-embeds nothing and cannot be
/// undone from this page, so it asks.
class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({
    required this.name,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String name;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ClaudeSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(confirmLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: ClaudeSpacing.sm),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inkTertiary),
          ),
          const SizedBox(height: ClaudeSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
              ),
              Expanded(
                child: FilledButton(
                  key: const Key('knowledge_delete_confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

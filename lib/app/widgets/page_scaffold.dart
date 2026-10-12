import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// Shared chrome for every pushed page.
///
/// A back affordance, a serif title, and a body capped at a reading measure.
/// Every secondary screen in the app was rolled by hand before; centralising
/// it here is what keeps the new visual language from drifting page to page.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
    this.maxWidth = 760,
    this.padding,
    this.showDivider = true,
    this.leading,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool showDivider;
  final Widget? leading;

  /// Set false when the body manages its own scrolling — a page holding an
  /// [Expanded] cannot live inside an unbounded scroll view.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.canvas,
      appBar: AppBar(
        backgroundColor: context.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading:
            leading ??
            IconButton(
              key: const Key('page_back_button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: actions,
        bottom: showDivider
            ? PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: context.border),
              )
            : null,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: scrollable
            ? SingleChildScrollView(
                padding:
                    padding ??
                    const EdgeInsets.fromLTRB(
                      ClaudeSpacing.lg,
                      ClaudeSpacing.xl,
                      ClaudeSpacing.lg,
                      ClaudeSpacing.xxl * 2,
                    ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ),
              )
            : Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// A short block of explanatory copy above a form. Used where the old pages
/// crammed a description into the section subtitle.
class PageIntro extends StatelessWidget {
  const PageIntro(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ClaudeSpacing.xl, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.inkSecondary,
          height: 1.6,
        ),
      ),
    );
  }
}

/// An inline empty state — icon, title, and one optional line of detail.
class InlineEmptyState extends StatelessWidget {
  const InlineEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClaudeSpacing.xxl),
      child: Column(
        children: [
          Icon(icon, size: 30, color: context.inkTertiary),
          const SizedBox(height: ClaudeSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (detail != null) ...[
            const SizedBox(height: ClaudeSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.55),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: ClaudeSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

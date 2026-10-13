import 'package:flutter/material.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/design/tokens.dart';

/// The wait before the model has said anything at all.
///
/// A reply that has not appeared needs to say why it has not appeared, and an
/// empty gap is not a reason. This covers exactly the gap the thinking line
/// does not: while the server is still prefilling there is no reasoning text
/// either, so [ThinkingLine] would have nothing to show.
///
/// It is a ball and not a spinner because nothing is being *computed* that the
/// user could name — it is waiting on the first token. A spinner implies
/// progress; a slow breath does not.
class PrefillOrb extends StatefulWidget {
  const PrefillOrb({super.key});

  @override
  State<PrefillOrb> createState() => _PrefillOrbState();
}

class _PrefillOrbState extends State<PrefillOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(left: 2, top: 2, bottom: 6),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Row(
                children: [
                  // A soft halo that grows and fades with the ball, so the
                  // breathing does not read as the ball changing size — which
                  // looks like it is being pressed.
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withAlpha((18 + 26 * t).round()),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 8 + 3 * t,
                      height: 8 + 3 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withAlpha((140 + 90 * t).round()),
                      ),
                    ),
                  ),
                  const SizedBox(width: ClaudeSpacing.sm),
                  Container(
                    width: 54,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

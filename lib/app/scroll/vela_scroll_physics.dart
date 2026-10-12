import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Scroll physics with the iOS feel Android never ships.
///
/// Two differences from [BouncingScrollPhysics], and the second is the one
/// that actually shows:
///
/// * Past the edge the list follows the finger instead of resisting to a
///   stop. Android's default decelerates sharply, so the transcript stopped
///   dead under the thumb — reading as a stutter rather than as give.
/// * The rebound does not reuse the deceleration left over from the fling.
///   Carrying a fast fling's velocity into the spring makes it snap back
///   almost instantly, which reads as a bounce animation playing over a
///   refusal to move. This zeros the velocity and springs from wherever the
///   drag actually left the content.
///
/// The friction is deliberately Apple's 0.135 against Android's 0.015, so a
/// long transcript does not feel like it is being dragged through syrup.
class VelaScrollPhysics extends BouncingScrollPhysics {
  const VelaScrollPhysics({super.parent});

  @override
  VelaScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      VelaScrollPhysics(parent: buildParent(ancestor));

  @override
  double frictionFactor(double overscrollFraction) => 0.135;

  @override
  double get minFlingVelocity => 60.0;

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.5, stiffness: 380.0, damping: 34.0);

  /// Zero, so a fling's velocity is not carried into the rebound.
  @override
  double carriedMomentum(double existingVelocity) => 0.0;
}

/// Gives the scroll position a velocity it can actually ease from.
///
/// [correctPixels] jumps. Streaming appends tokens several times a second, so
/// the transcript used to snap downward on each one — the exact opposite of
/// following a reply. Starting an animation on every content change leaves
/// the springs chasing each other instead, so this keeps exactly one running
/// and retargets it from wherever it has got to.
///
/// Not for user drags: those belong to the physics, and a fling fighting an
/// animation is how the "it won't stay still" feeling starts.
extension SmoothFollowOnScrollPosition on ScrollPositionWithSingleContext {
  /// Eases to [target], or to the bottom when no target is given.
  ///
  /// Not for user drags: those belong to the physics, and a fling fighting an
  /// animation is how the "it will not stay still" feeling starts.
  void smoothFollow({
    double? target,
    Duration duration = const Duration(milliseconds: 180),
  }) {
    if (!hasPixels || !hasContentDimensions) return;
    if (userScrollDirection != ScrollDirection.idle) return;

    // The bottom, not the current offset. Clamping the current offset into
    // range is a no-op — it is already in range — which made this a silent
    // no-op for exactly the case it exists for: sitting at the old bottom
    // while the content grows past it.
    final destination = (target ?? maxScrollExtent).clamp(
      minScrollExtent,
      maxScrollExtent,
    );
    final remaining = destination - pixels;
    if (remaining.abs() < 0.5) return;

    // Long enough to swallow, short enough that a fast stream is not visibly
    // behind the text it is supposed to be following.
    final settle = Duration(
      milliseconds: (duration.inMilliseconds * remaining.abs() / 120)
          .clamp(90.0, 320.0)
          .round(),
    );
    goIdle();
    animateTo(destination, duration: settle, curve: Curves.easeOutCubic);
  }
}

/// True while the user is actually driving the list.
///
/// Guard for anything that moves the transcript on its own: auto-follow,
// jump-to-bottom, restoring a position. Firing one of those mid-drag is
/// what makes a list fight the finger.
bool isUserDriving(ScrollPosition? position) =>
    position != null && position.userScrollDirection != ScrollDirection.idle;

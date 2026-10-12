import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:servllama/app/scroll/vela_scroll_physics.dart';

class ChatAutoFollowScrollController extends ScrollController {
  ChatAutoFollowScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  bool Function() shouldAutoFollow = () => false;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ChatAutoFollowScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      controller: this,
    );
  }
}

class _ChatAutoFollowScrollPosition extends ScrollPositionWithSingleContext {
  _ChatAutoFollowScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  final ChatAutoFollowScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (controller.shouldAutoFollow() &&
        userScrollDirection == ScrollDirection.idle) {
      final delta = this.maxScrollExtent - pixels;
      if (delta.abs() > 0.5) {
        // Eased, not jumped. Streaming grows the content several times a
        // second, and correctPixels teleports on each one — the transcript
        // moved in visible steps while a reply was being written. An
        // animation that is still running is retargeted rather than
        // replaced, so the springs do not queue up behind each other.
        //
        // Done in a post-frame callback: starting an animation from inside
        // applyContentDimensions runs it while the scrollable is mid-layout.
        final position = this;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!position.hasContentDimensions) return;
          position.smoothFollow();
        });
      }
    }
    return result;
  }
}

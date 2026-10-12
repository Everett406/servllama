import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  group('the entrance the package can actually produce', () {
    // The curves are fixed in the package:
    //   alpha = t
    //   sigma = 3 * (1 - Curves.easeOut(t)), and easeOut(t) = 1 - (1-t)^2,
    //   so sigma(t) = 3 * (1 - t)^2.
    //
    // They are anti-correlated at the start: the blur peaks at t = 0 where
    // opacity is zero. Sigma is still above 1.0 — plainly out of focus — at
    // t = 0.42, by which point the text is only 42% opaque. That is why the
    // effect read as a fade with no blur: the blurred stretch was too short
    // and too faint to register.
    //
    // The only lever left is the length of the window, which is why the
    // settings below are long.
    double sigmaAt(double t) => 3 * (1 - t) * (1 - t);

    test('the blur is strongest exactly when the text is invisible', () {
      expect(sigmaAt(0), closeTo(3.0, 0.001));
      expect(sigmaAt(0), greaterThan(sigmaAt(0.4)));
    });

    test('a longer window keeps blurred text on screen for longer', () {
      // Time sigma stays above 1.0, as a fraction of the window.
      const threshold = 1.0;
      final tAtThreshold = 1 - math.sqrt(threshold / 3);
      expect(tAtThreshold, closeTo(0.42, 0.02));
      // 0.38s window kept it blurred for ~160ms; 0.62s keeps it for ~260ms.
      expect(0.38 * tAtThreshold * 1000, lessThan(200));
      expect(0.62 * tAtThreshold * 1000, greaterThan(240));
    });
  });

  test('the package has no per-character blur to ask for', () {
    // This is why the effect was only ever visible at line breaks, and it is
    // a property of the package rather than a tuning mistake:
    // `animatesPerCharacter` is true for `wave` alone.
    expect(GptMarkdownAnimation.blurIn.animatesPerCharacter, isFalse);
    expect(GptMarkdownAnimation.wave.animatesPerCharacter, isTrue);
  });

}

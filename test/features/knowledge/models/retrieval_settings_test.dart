import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/knowledge/models/retrieval_settings.dart';

void main() {
  // These were compiled-in constants, which made retrieval quality
  // unarguable with. Three passages or eight, and a floor of 0.18 or 0.45, is
  // the difference between an answer and a shrug.
  group('presets', () {
    test('each preset says what it trades', () {
      final precise = RetrievalPreset.precise.settings;
      final balanced = RetrievalPreset.balanced.settings;
      final exhaustive = RetrievalPreset.exhaustive.settings;

      // Precise: fewer passages, a higher bar, less room.
      expect(precise.maxChunks, lessThan(balanced.maxChunks));
      expect(precise.minScore, greaterThan(balanced.minScore));
      expect(precise.charBudget, lessThan(balanced.charBudget));

      // Exhaustive: the mirror image.
      expect(exhaustive.maxChunks, greaterThan(balanced.maxChunks));
      expect(exhaustive.minScore, lessThan(balanced.minScore));
      expect(exhaustive.charBudget, greaterThan(balanced.charBudget));
    });

    test('a preset is identified by its own values', () {
      for (final preset in RetrievalPreset.values) {
        expect(preset.settings.matchesPreset(preset), isTrue);
        expect(preset.settings.effectivePreset, preset);
      }
    });
  });

  group('hand-adjusted values', () {
    // A slider that snaps back to a preset every time it is touched is a
    // slider you cannot set a value on.
    test('moving one value leaves the preset', () {
      final balanced = RetrievalPreset.balanced.settings;
      final moved = balanced.copyWith(maxChunks: 5);

      expect(moved.preset, isNull);
      expect(moved.effectivePreset, RetrievalPreset.balanced);
      expect(moved.matchesPreset(RetrievalPreset.balanced), isFalse);
      // The rest survived.
      expect(moved.minScore, balanced.minScore);
    });

    test('landing back on preset values re-identifies it', () {
      final moved = RetrievalPreset.balanced.settings.copyWith(maxChunks: 5);
      final returned = moved.copyWith(maxChunks: 4);
      expect(returned.matchesPreset(RetrievalPreset.balanced), isTrue);
    });

    test('copyWith with no arguments changes nothing', () {
      final settings = RetrievalPreset.exhaustive.settings;
      expect(settings.copyWith(), settings);
    });
  });

  group('sanitized', () {
    // A stored value is user input like any other. An out-of-range one has to
    // be corrected here rather than becoming a failed request at send time.
    test('clamps into what a server and a window can take', () {
      const wild = RetrievalSettings(
        maxChunks: 99,
        minScore: 4.2,
        charBudget: 999999,
        perChunkChars: 0,
      );
      final safe = wild.sanitized();

      expect(safe.maxChunks, 16);
      expect(safe.minScore, 1.0);
      expect(safe.charBudget, 8000);
      // Zero characters of a passage would make every passage empty and the
      // budget meaningless.
      expect(safe.perChunkChars, 80);
    });

    test('leaves sane values alone', () {
      final sane = RetrievalPreset.balanced.settings;
      expect(sane.sanitized(), sane);
    });

    test('a per-chunk limit above the total is still legal', () {
      // It simply means the total is what binds. Refusing this would make one
      // of the two knobs meaningless depending on the other's value.
      final settings = RetrievalSettings(charBudget: 500, perChunkChars: 900);
      final safe = settings.sanitized();
      expect(safe.charBudget, 500);
      expect(safe.perChunkChars, 900);
    });
  });

  group('persistence', () {
    test('survives a round trip', () {
      const settings = RetrievalSettings(
        maxChunks: 7,
        minScore: 0.33,
        charBudget: 2600,
        perChunkChars: 450,
        preset: RetrievalPreset.exhaustive,
      );
      expect(RetrievalSettings.fromJson(settings.toJson()), settings);
    });

    // A blob written by an older build is missing fields. Falling back to the
    // class default for each one would land somewhere that belongs to no
    // preset at all.
    test('a partial blob falls back to its preset, not to the defaults', () {
      final restored = RetrievalSettings.fromJson(<String, dynamic>{
        'preset': 'precise',
        'maxChunks': 9,
      });
      expect(restored.maxChunks, 9);
      expect(restored.minScore, RetrievalPreset.precise.settings.minScore);
      expect(restored.perChunkChars, RetrievalPreset.precise.settings.perChunkChars);
    });

    test('a missing or malformed blob costs the tuning, not the library', () {
      expect(RetrievalSettings.fromJson(null), RetrievalPreset.balanced.settings);
      expect(RetrievalSettings.fromJson(<String, dynamic>{}), RetrievalPreset.balanced.settings);
    });
  });
}
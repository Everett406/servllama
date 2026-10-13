import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_descriptor.dart';

void main() {
  // The whole point of a display name is that it is *only* a display name. If
  // it ever moved a file or changed the id the server is launched with, it
  // would be a rename wearing a different label — and renaming a model on
  // disk is destructive enough that the two must not share a code path.
  group('ModelDescriptor.displayName', () {
    ModelDescriptor descriptor({String? displayName}) {
      return ModelDescriptor(
        id: 'abc123',
        modelName: 'qwen3-8b-instruct-q4_k_m.gguf',
        sizeBytes: 4920000000,
        storedDirectoryPath: '/models/abc123',
        storedFilePath: '/models/abc123/qwen3-8b-instruct-q4_k_m.gguf',
        importedAt: DateTime.utc(2026, 1, 2),
        displayName: displayName,
      );
    }

    test('falls back to the real name when there is no alias', () {
      expect(descriptor().label, 'qwen3-8b-instruct-q4_k_m.gguf');
      expect(descriptor(displayName: null).label, 'qwen3-8b-instruct-q4_k_m.gguf');
    });

    test('shows the alias when there is one', () {
      expect(descriptor(displayName: '我的本地模型').label, '我的本地模型');
    });

    test('an empty or blank alias is not an alias', () {
      expect(descriptor(displayName: '').label, 'qwen3-8b-instruct-q4_k_m.gguf');
      expect(descriptor(displayName: '   ').label, 'qwen3-8b-instruct-q4_k_m.gguf');
    });

    test('setting an alias leaves the name, paths and id alone', () {
      final before = descriptor();
      final after = before.copyWith(displayName: '小模型');

      expect(after.modelName, before.modelName);
      expect(after.storedFilePath, before.storedFilePath);
      expect(after.storedDirectoryPath, before.storedDirectoryPath);
      expect(after.id, before.id);
      expect(after.label, '小模型');
    });

    // copyWith's return is a method body, where a parameter is not in scope —
    // an unqualified name there reads the *field*. This is the shape that bug
    // would take if it were reintroduced.
    test('copyWith actually applies the alias', () {
      final result = descriptor().copyWith(displayName: '生效了吗');
      expect(result.displayName, '生效了吗');
    });

    test('an alias can be cleared back to null', () {
      final aliased = descriptor(displayName: '临时');
      expect(aliased.copyWith(displayName: null).displayName, isNull);
      expect(aliased.copyWith().displayName, '临时');
    });
  });

  group('LibraryModel.alias', () {
    LibraryModel model({String? alias}) {
      return LibraryModel(
        id: 'llama_cpp:abc123',
        runtimeId: 'qwen3-8b-instruct-q4_k_m.gguf',
        engine: InferenceEngine.llamaCpp,
        name: 'qwen3-8b-instruct-q4_k_m.gguf',
        sizeBytes: 4920000000,
        importedAt: DateTime.utc(2026, 1, 2),
        storagePath: '/models/abc123/qwen3-8b-instruct-q4_k_m.gguf',
        alias: alias,
      );
    }

    test('title falls back to the real name', () {
      expect(model().title, 'qwen3-8b-instruct-q4_k_m.gguf');
      expect(model().hasAlias, isFalse);
    });

    test('title shows the alias, runtimeId does not', () {
      final aliased = model(alias: '写东西用');
      expect(aliased.title, '写东西用');
      expect(aliased.hasAlias, isTrue);
      // This is what the server is actually launched by.
      expect(aliased.runtimeId, 'qwen3-8b-instruct-q4_k_m.gguf');
      expect(aliased.name, 'qwen3-8b-instruct-q4_k_m.gguf');
      expect(aliased.storagePath.endsWith('.gguf'), isTrue);
    });

    test('a blank alias reads as no alias', () {
      expect(model(alias: '  ').hasAlias, isFalse);
      expect(model(alias: '  ').title, 'qwen3-8b-instruct-q4_k_m.gguf');
    });

    test('copyWith keeps the alias unless told otherwise', () {
      final aliased = model(alias: '保留我');
      expect(aliased.copyWith(name: 'other').alias, '保留我');
      expect(aliased.copyWith(alias: null).alias, isNull);
      expect(aliased.copyWith(alias: '换').title, '换');
    });

    // Two models may legitimately be *shown* under the same name, since only
    // one of them is actually called that. Nothing here should reject it.
    test('two models may share a display name', () {
      final a = model(alias: '同一个名字');
      final b = model(alias: '同一个名字');
      expect(a.title, b.title);
      expect(a.runtimeId, b.runtimeId);
    });
  });
}

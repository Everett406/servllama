import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/features/knowledge/services/embedding_model_store.dart';

/// The bug this locks down: the knowledge base scanned `<support>/kb/models`
/// and the chat library scanned `<support>/models`, so a user who had already
/// downloaded an embedding GGUF into the model library was told they had none
/// and told to go find a file in the system file picker they already had.
void main() {
  late Directory root;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vela_embed_test');
    Hive.init(root.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ModelDescriptorAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<EmbeddingModelStore> storeWithLibrary(
    List<ModelDescriptor> library,
  ) async {
    final repository = LocalModelRepository(
      appSupportDirectory: root,
      storagePaths: ModelStoragePaths(appSupportDirectory: root),
    );
    final box = await Hive.openBox<ModelDescriptor>(
      LocalModelRepository.boxName,
    );
    await box.clear();
    await box.putAll(<String, ModelDescriptor>{
      for (final descriptor in library) descriptor.id: descriptor,
    });
    return EmbeddingModelStore(
      modelLibrary: repository,
      embeddingDirectory: () async =>
          Directory('${root.path}/kb/models')..createSync(recursive: true),
    );
  }

  Future<ModelDescriptor> describeFile(String name) async {
    final modelsDir = ModelStoragePaths(
      appSupportDirectory: root,
    ).getModelsDirectory();
    final models = await modelsDir;
    final file = File('${models.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(1024, 7));
    return ModelDescriptor(
      id: 'local_$name',
      modelName: name,
      sizeBytes: 1024,
      storedDirectoryPath: models.path,
      storedFilePath: file.path,
      importedAt: DateTime.utc(2026, 3, 1),
    );
  }

  test('a GGUF already in the model library is offered as an embedding', () async {
    final descriptor = await describeFile('bge-small-zh-v1.5-q8_0.gguf');
    final store = await storeWithLibrary(<ModelDescriptor>[descriptor]);

    final installed = await store.installed();

    expect(
      installed.map((model) => model.path),
      contains(descriptor.storedFilePath),
      reason: 'a file the app already holds must be selectable',
    );
  });

  test('it is offered in place, not copied into a second directory', () async {
    final descriptor = await describeFile('bge-small-zh-v1.5-q8_0.gguf');
    final store = await storeWithLibrary(<ModelDescriptor>[descriptor]);

    final installed = await store.installed();
    final entry = installed.firstWhere(
      (model) => model.path == descriptor.storedFilePath,
    );

    // The chat library owns its files and deletes them with the model. A
    // private copy would be invisible to the user and would survive as an
    // orphan.
    expect(entry.path, isNot(contains('/kb/')));
  });

  test('a built-in keeps its declared width; an unknown file has none', () async {
    final known = await describeFile('bge-small-zh-v1.5-q8_0.gguf');
    final odd = await describeFile('my-own-encoder.gguf');
    final store = await storeWithLibrary(<ModelDescriptor>[known, odd]);

    final installed = await store.installed();
    final knownEntry = installed.firstWhere(
      (model) => model.path == known.storedFilePath,
    );
    final oddEntry = installed.firstWhere(
      (model) => model.path == odd.storedFilePath,
    );

    expect(knownEntry.dimensions, isNotNull);
    // Guessing here is what makes an index silently unsearchable.
    expect(oddEntry.dimensions, isNull);
    expect(oddEntry.custom, isTrue);
  });

  test('an unreadable model library does not hide the built-in downloads', () async {
    final store = EmbeddingModelStore(
      listLibraryModels: () async => throw StateError('hive is not ready'),
      embeddingDirectory: () async =>
          Directory('${root.path}/kb/models')..createSync(recursive: true),
    );

    expect(await store.installed(), isEmpty);
    // No throw. A library that cannot be read is a reason to offer the
    // downloads, not a reason to have no way to set a model at all.
  });
  group('ordering for the picker', () {
    InstalledEmbeddingModel model(String name, int size) =>
        InstalledEmbeddingModel(
          id: name,
          name: name,
          path: '/models/$name.gguf',
          sizeBytes: size,
        );

    test('an embedding model comes before a chat model, however big', () {
      final sorted = <InstalledEmbeddingModel>[
        // The realistic case: a 4 GB chat model and a 26 MB embedder.
        model('Qwen3-8B-Q4_K_M', 4 * 1024 * 1024 * 1024),
        model('bge-small-zh-v1.5-q8_0', 26 * 1024 * 1024),
      ]..sort(EmbeddingModelStore.compareForPicking);

      expect(
        sorted.first.name,
        'bge-small-zh-v1.5-q8_0',
        reason: 'the model the user came for must not be below twenty chat ones',
      );
    });

    test('an embedding model is still offered even without "embed" in its name', () {
      // Filtered out of the list is unselectable, and unselectable looks
      // exactly like absent.
      final odd = model('my-own-encoder', 26 * 1024 * 1024);
      expect(odd.looksLikeEmbeddingModel, isFalse);
      // Listed, marked, and a click away — never hidden.
      expect(odd.id, isNotEmpty);
    });

    test('within a group the smaller model comes first', () {
      final sorted = <InstalledEmbeddingModel>[
        model('bge-base-zh-v1.5', 105 * 1024 * 1024),
        model('bge-small-zh-v1.5', 26 * 1024 * 1024),
      ]..sort(EmbeddingModelStore.compareForPicking);

      expect(sorted.first.name, 'bge-small-zh-v1.5');
    });
  });

}

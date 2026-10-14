/// Embedding models the knowledge base can download and use.
///
/// Kept as data rather than as a generic "any GGUF" picker. An embedding
/// model is not interchangeable with a chat model: swapping one for another
/// changes the vector space, which silently invalidates every chunk already
/// indexed. Letting a user drop any GGUF into this slot is how you get a
/// knowledge base that quietly answers from nothing.
///
/// Three are offered, and the reason for each is a trade somebody actually
/// has to make:
///
/// - **bge-small-zh-v1.5** — the default. 24M parameters, BERT architecture
///   so llama.cpp reads the pooling straight out of the GGUF with no
///   `--pooling` flag, and a 512-token window that lines up with how the
///   chunker sizes a piece of Chinese text. Chinese-native, so nothing is
///   spent on languages that will not appear in the library.
/// - **multilingual-e5-small** — for a library that mixes Chinese prose with
///   English identifiers, API names and error strings. Larger, and its
///   Chinese is weaker than bge's.
/// - **bge-base-zh-v1.5** — same family, 768 dimensions and noticeably
///   better recall. Costs about four times the memory and is worth it only
///   if the phone has room to spare next to the chat model.
///
/// Quantisation is fixed at Q8_0 for all three. Quantising a 24M model buys
/// very little — the source project's own numbers put it around 30% on CPU —
/// and the download is the thing a phone user notices, not the RAM.
class EmbeddingModelDescriptor {
  const EmbeddingModelDescriptor({
    required this.id,
    required this.name,
    required this.fileName,
    required this.url,
    required this.dimensions,
    required this.maxTokens,
    required this.approxBytes,
    required this.languages,
    this.note,
  });

  /// Stable id. Also the name of the directory under `kb/models/`.
  final String id;
  final String name;
  final String fileName;
  final String url;

  /// Length of one vector. Stored alongside every index so a library indexed
  /// with one model can refuse to be searched with another.
  final int dimensions;

  /// The model's own token window. A chunk longer than this is truncated by
  /// the encoder, and the tail is silently lost — so the chunker needs to
  /// know it.
  final int maxTokens;

  final int approxBytes;

  /// Human-readable, for the picker row. Not a claim about coverage.
  final String languages;
  final String? note;

  static const bgeSmallZh = EmbeddingModelDescriptor(
    id: 'bge-small-zh-v1.5',
    name: 'bge-small-zh-v1.5',
    fileName: 'bge-small-zh-v1.5-q8_0.gguf',
    url:
        'https://huggingface.co/CompendiumLabs/bge-small-zh-v1.5-gguf/'
        'resolve/main/bge-small-zh-v1.5-q8_0.gguf',
    dimensions: 512,
    maxTokens: 512,
    approxBytes: 26 * 1024 * 1024,
    languages: '中文',
  );

  static const multilingualE5Small = EmbeddingModelDescriptor(
    id: 'multilingual-e5-small',
    name: 'multilingual-e5-small',
    fileName: 'multilingual-e5-small-q8_0.gguf',
    url:
        'https://huggingface.co/cstr/multilingual-e5-small-GGUF/'
        'resolve/main/multilingual-e5-small-q8_0.gguf',
    dimensions: 384,
    maxTokens: 512,
    approxBytes: 120 * 1024 * 1024,
    languages: '中文 / 英文',
    note: '中英混排时选这个；纯中文不如 bge-small-zh。',
  );

  static const bgeBaseZh = EmbeddingModelDescriptor(
    id: 'bge-base-zh-v1.5',
    name: 'bge-base-zh-v1.5',
    fileName: 'bge-base-zh-v1.5-q8_0.gguf',
    url:
        'https://huggingface.co/CompendiumLabs/bge-base-zh-v1.5-gguf/'
        'resolve/main/bge-base-zh-v1.5-q8_0.gguf',
    dimensions: 768,
    maxTokens: 512,
    approxBytes: 105 * 1024 * 1024,
    languages: '中文',
    note: '更准，但内存是默认的约四倍，手机上要留得下。',
  );

  static const all = <EmbeddingModelDescriptor>[
    bgeSmallZh,
    multilingualE5Small,
    bgeBaseZh,
  ];

  static const defaultModel = bgeSmallZh;

  /// Look a descriptor up by the file it installs as, so a file the user
  /// already has on disk can be recognised as one of the built-ins rather
  /// than being filed as an unknown custom model.
  static EmbeddingModelDescriptor? byFileName(String fileName) {
    for (final model in all) {
      if (model.fileName == fileName) return model;
    }
    return null;
  }

  static EmbeddingModelDescriptor? byId(String id) {
    for (final model in all) {
      if (model.id == id) return model;
    }
    return null;
  }
}
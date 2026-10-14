class ServerPrefsKeys {
  const ServerPrefsKeys._();

  static const String listenMode = 'server.listen_mode';
  static const String port = 'server.port';
  static const String apiKey = 'server.api_key';
  static const String contextSize = 'server.context_size';
  static const String cpuThreads = 'server.cpu_threads';
  static const String batchSize = 'server.batch_size';
  static const String parallelSlots = 'server.parallel_slots';
  static const String imageMaxTokens = 'server.image_max_tokens';
  static const String flashAttentionMode = 'server.flash_attention_mode';
  static const String useMmap = 'server.use_mmap';
  static const String logEnabled = 'server.log_enabled';
  static const String logLevel = 'server.log_level';
  static const String llamaCppBackend = 'server.llama_cpp_backend';
  static const String llamaCppGpuLayers = 'server.llama_cpp_gpu_layers';
  static const String mnnBackend = 'server.mnn_backend';
  static const String mnnUseMmap = 'server.mnn_use_mmap';
  static const String mnnPrecision = 'server.mnn_precision';
  static const String mnnThreadNum = 'server.mnn_thread_num';
  static const String foregroundNotificationPermissionPrompted =
      'server.foreground_notification_permission_prompted';

  /// Sampling settings, stored as one JSON blob rather than five keys: they
  /// are written and read together, and a half-written set of five preferences
  /// is harder to reason about than one document that is either there or not.
  static const String generationParams = 'chat.generation_params';

  /// Which embedding GGUF is in use. Path rather than id alone, because the
  /// user's own file has no id — the app did not ship it.
  static const String embeddingModelId = 'kb.embedding_model_id';
  static const String embeddingModelPath = 'kb.embedding_model_path';

  /// Recorded when known so a mismatch against the stored vectors can be
  /// caught before the search silently returns nothing.
  static const String embeddingModelDimensions = 'kb.embedding_model_dimensions';

  /// Retrieval knobs. The defaults are not the only sensible settings — a
  /// large library and a small one want different ones — so they are stored
  /// rather than compiled in.
  static const String retrievalSettings = 'kb.retrieval_settings';

  /// Which built-in tools are on. Kept out of the retrieval blob: turning off
  /// a tool and re-tuning a search are different decisions and should not
  /// overwrite each other.
  static const String builtinToolsEnabled = 'chat.builtin_tools_enabled';

  /// Whether to spend a request naming a conversation. On by default: without
  /// it every conversation is named by the first line of the user's message,
  /// which is usually a question rather than a topic.
  static const String titleGenerationEnabled = 'chat.title_generation_enabled';

  /// A model to name conversations with, empty to reuse the running one. A
  /// title is a few words; a small model can do it without the memory a big one
  /// would be holding for no reason.
  static const String titleGenerationModel = 'chat.title_generation_model';
}

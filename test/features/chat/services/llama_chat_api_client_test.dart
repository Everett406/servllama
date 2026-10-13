import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/generation_params.dart';
import 'package:servllama/features/chat/models/chat_tool_call.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

void main() {
  group('LlamaChatApiClient', () {
    late _TestChatServer server;
    late LlamaChatApiClient client;

    setUp(() async {
      server = _TestChatServer();
      await server.start();
      client = LlamaChatApiClient(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(apiKey: 'secret'),
        ),
      )..updateBaseUrl(server.baseUrl);
    });

    tearDown(() async {
      await server.close();
    });

    // The point of the whole feature: settings typed into a page have to turn
    // up in the request. A page that renders them beautifully and sends
    // nothing looks exactly the same as one that works.
    test('sends the set generation parameters in the request body', () async {
      server.chatResponder = (request) async {
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'hello',
                createdAt: DateTime(2026, 3, 25),
              ),
            ],
            cancelToken: CancelToken(),
            generationParams: const GenerationParams(
              temperature: 0.6,
              topP: 0.9,
              topK: 40,
              repeatPenalty: 1.1,
              maxTokens: 512,
            ),
          )
          .toList();

      final captured = server.lastChatRequestBody!;
      expect(captured['temperature'], 0.6);
      expect(captured['top_p'], 0.9);
      expect(captured['top_k'], 40);
      expect(captured['repeat_penalty'], 1.1);
      expect(captured['max_tokens'], 512);
      expect(captured['model'], 'alpha');
      expect(captured['stream'], isTrue);
    });

    test('omits unset parameters rather than sending nulls', () async {
      server.chatResponder = (request) async {
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'hello',
                createdAt: DateTime(2026, 3, 25),
              ),
            ],
            cancelToken: CancelToken(),
          )
          .toList();

      final captured = server.lastChatRequestBody!;
      expect(captured.containsKey('temperature'), isFalse);
      expect(captured.containsKey('top_p'), isFalse);
      expect(captured.containsKey('max_tokens'), isFalse);
    });

    // Tool calling is only real if the request advertises the tools and the
    // results come back in the shape the API accepts them in. A server that
    // answers "here is a title" to a `role: tool` message fails in a way only
    // a request body test catches.
    test('advertises the built-in tools and tool_choice auto', () async {
      server.chatResponder = (request) async {
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'what time is it',
                createdAt: DateTime(2026, 3, 25),
              ),
            ],
            cancelToken: CancelToken(),
          )
          .toList();

      final body = server.lastChatRequestBody!;
      expect(body['tool_choice'], 'auto');
      final tools = body['tools']! as List;
      expect(tools, hasLength(3));
      // Not filtered by a "supports tools" label: the server decides.
      final names = tools
          .map((spec) => ((spec as Map)['function'] as Map)['name'])
          .toList();
      expect(names, contains('calculator'));
    });

    test('sends an assistant tool-call turn and its results back', () async {
      server.chatResponder = (request) async {
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'what is 2+2',
                createdAt: DateTime(2026, 3, 25),
              ),
              ChatMessageRecord(
                id: 'm2',
                role: ChatRole.assistant,
                content: '',
                createdAt: DateTime(2026, 3, 25),
                toolCalls: const <ChatToolCall>[
                  ChatToolCall(
                    id: 'call_1',
                    name: 'calculator',
                    arguments: '{"expression":"2+2"}',
                  ),
                ],
                toolResults: const <ChatToolResult>[
                  ChatToolResult(
                    callId: 'call_1',
                    name: 'calculator',
                    arguments: '{"expression":"2+2"}',
                    result: '{"result":"4"}',
                  ),
                ],
              ),
            ],
            cancelToken: CancelToken(),
          )
          .toList();

      final roles = (server.lastChatRequestBody!['messages']! as List)
          .map((message) => (message as Map)['role'])
          .toList();
      expect(roles, contains('assistant'));
      expect(roles, contains('tool'));
    });

    test('streams tool_calls fragments out of the delta', () async {
      // Built with jsonEncode rather than a hand-escaped literal: the payload
      // is JSON inside JSON inside a Dart string, and escaping that by hand is
      // how a test ends up asserting on a server that was never asked.
      String sse(Map<String, dynamic> toolCall) {
        final delta = <String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'delta': <String, dynamic>{'tool_calls': <Map<String, dynamic>>[toolCall]},
            },
          ],
        };
        return 'data: ${jsonEncode(delta)}\n\n';
      }

      final payload = <String>[
        sse(<String, dynamic>{
          'index': 0,
          'id': 'call_9',
          'function': <String, dynamic>{
            'name': 'calculator',
            'arguments': '{"expression": "(3+4)',
          },
        }),
        sse(<String, dynamic>{
          'index': 0,
          'function': <String, dynamic>{'arguments': '*2"}'},
        }),
      ].join();

      server.chatResponder = (request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.add(utf8.encode(payload));
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      final deltas = await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'calculate',
                createdAt: DateTime(2026, 3, 25),
              ),
            ],
            cancelToken: CancelToken(),
          )
          .toList();

      final accumulator = ChatToolCallAccumulator(index: 0);
      for (final delta in deltas) {
        for (final fragment in delta.toolCalls) {
          accumulator.add(fragment);
        }
      }
      final call = accumulator.build()!;
      expect(call.id, 'call_9');
      expect(call.name, 'calculator');
      // The arguments arrived split, usually mid-token. Stitching them by
      // index is the whole job; getting it wrong loses calls silently.
      expect(call.parsedArguments['expression'], '(3+4)*2');
    });

    test('uses 120 seconds receive timeout by default', () {
      final client = LlamaChatApiClient(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );

      expect(
        client.dio.options.receiveTimeout,
        LlamaChatApiClient.defaultChatReceiveTimeout,
      );
    });

    test('updates receive timeout at runtime', () {
      final client = LlamaChatApiClient(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );

      client.updateReceiveTimeout(const Duration(seconds: 300));

      expect(client.dio.options.receiveTimeout, const Duration(seconds: 300));
    });

    test('streamChatCompletion parses content and reasoning SSE chunks', () async {
      server.chatResponder = (request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"reasoning_content":"先分析问题。"}}]}\n\n',
          ),
        );
        request.response.add(
          utf8.encode('data: {"choices":[{"delta":{"content":"你"}}]}\n\n'),
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"好","reasoning_content":"再组织答案。"}}]}\n\n',
          ),
        );
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      final chunks = await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'hello',
                createdAt: DateTime(2026, 3, 25),
              ),
            ],
            cancelToken: CancelToken(),
          )
          .toList();

      expect(chunks, <ChatStreamDelta>[
        const ChatStreamDelta(reasoningContent: '先分析问题。'),
        const ChatStreamDelta(content: '你'),
        const ChatStreamDelta(content: '好', reasoningContent: '再组织答案。'),
      ]);
      expect(server.lastChatRequestBody?['model'], 'alpha');
      expect(server.lastAuthorization, 'Bearer secret');
      expect(server.lastChatRequestBody?['messages'], <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': 'hello'},
      ]);
    });

    test(
      'streamChatCompletion inlines image attachments as data URLs',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('servllama_test');
        addTearDown(() => tempDir.delete(recursive: true));
        final imageFile = File(
          '${tempDir.path}${Platform.pathSeparator}photo.png',
        );
        const imageBytes = <int>[1, 2, 3, 4];
        await imageFile.writeAsBytes(imageBytes);

        server.chatResponder = (request) async {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.add(utf8.encode('data: [DONE]\n\n'));
          await request.response.close();
        };

        await client
            .streamChatCompletion(
              modelId: 'alpha',
              messages: <ChatMessageRecord>[
                ChatMessageRecord(
                  id: 'm1',
                  role: ChatRole.user,
                  content: 'look',
                  createdAt: DateTime(2026, 3, 25),
                  imageFilePaths: <String>[
                    imageFile.path,
                    '${tempDir.path}${Platform.pathSeparator}missing.png',
                  ],
                ),
              ],
              cancelToken: CancelToken(),
            )
            .toList();

        final messages =
            server.lastChatRequestBody?['messages'] as List<Object?>;
        final content = (messages.single as Map)['content'] as List<Object?>;
        // Text part plus the existing image; the missing file is skipped.
        expect(content, hasLength(2));
        expect((content[0] as Map)['type'], 'text');
        final imagePart = content[1] as Map;
        expect(imagePart['type'], 'image_url');
        expect(
          (imagePart['image_url'] as Map)['url'],
          'data:image/png;base64,${base64Encode(imageBytes)}',
        );
      },
    );

    test(
      'streamChatCompletion decodes multi-byte characters split across chunks',
      () async {
        server.chatResponder = (request) async {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          // "你好" split mid-character across two network chunks.
          final bytes = utf8.encode(
            'data: {"choices":[{"delta":{"content":"你好"}}]}\n\n',
          );
          request.response.add(bytes.sublist(0, 40));
          await request.response.flush();
          request.response.add(bytes.sublist(40));
          request.response.add(utf8.encode('data: [DONE]\n\n'));
          await request.response.close();
        };

        final chunks = await client
            .streamChatCompletion(
              modelId: 'alpha',
              messages: const <ChatMessageRecord>[],
              cancelToken: CancelToken(),
            )
            .toList();

        expect(chunks, <ChatStreamDelta>[const ChatStreamDelta(content: '你好')]);
      },
    );

    test('streamChatCompletion skips malformed SSE data lines', () async {
      server.chatResponder = (request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.add(
          utf8.encode('data: {"choices":[{"delta":{"content":"前"}}]}\n\n'),
        );
        request.response.add(utf8.encode('data: not-json at all\n\n'));
        request.response.add(
          utf8.encode('data: {"choices":[{"delta":{"content":"后"}}]}\n\n'),
        );
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      final chunks = await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: const <ChatMessageRecord>[],
            cancelToken: CancelToken(),
          )
          .toList();

      expect(chunks, <ChatStreamDelta>[
        const ChatStreamDelta(content: '前'),
        const ChatStreamDelta(content: '后'),
      ]);
    });

    test(
      'streamChatCompletion parses a trailing line without a newline',
      () async {
        server.chatResponder = (request) async {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.add(
            utf8.encode('data: {"choices":[{"delta":{"content":"尾行"}}]}'),
          );
          await request.response.close();
        };

        final chunks = await client
            .streamChatCompletion(
              modelId: 'alpha',
              messages: const <ChatMessageRecord>[],
              cancelToken: CancelToken(),
            )
            .toList();

        expect(chunks, <ChatStreamDelta>[const ChatStreamDelta(content: '尾行')]);
      },
    );

    test('streamChatCompletion surfaces JSON error responses', () async {
      server.chatResponder = (request) async {
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': 'Invalid API Key'},
          }),
        );
        await request.response.close();
      };

      expect(
        () => client
            .streamChatCompletion(
              modelId: 'alpha',
              messages: const <ChatMessageRecord>[],
              cancelToken: CancelToken(),
            )
            .toList(),
        throwsA(
          isA<LlamaChatApiException>().having(
            (error) => error.message,
            'message',
            'Invalid API Key',
          ),
        ),
      );
    });
  });
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _TestChatServer {
  HttpServer? _server;

  String? lastAuthorization;
  Map<String, Object?>? lastChatRequestBody;
  Future<void> Function(HttpRequest request)? chatResponder;

  String get baseUrl => 'http://127.0.0.1:$port';
  int get port => _server!.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server!.forEach(_handleRequest));
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    lastAuthorization = request.headers.value('authorization');

    if (request.method == 'POST' &&
        request.uri.path == '/v1/chat/completions' &&
        chatResponder != null) {
      final body = await utf8.decoder.bind(request).join();
      lastChatRequestBody = jsonDecode(body) as Map<String, Object?>;
      await chatResponder!(request);
      return;
    }

    request.response.statusCode = 404;
    await request.response.close();
  }
}

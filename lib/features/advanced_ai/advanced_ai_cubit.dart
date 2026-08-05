import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';

/// One turn in the Advanced AI conversation.
///
/// The reasoning model returns its working separately from its answer, so a
/// turn carries both: [thinking] is the chain of thought, [content] is the
/// reply. Keeping them apart is what lets the UI collapse the former.
class AiTurn extends Equatable {
  const AiTurn({
    required this.role,
    this.content = '',
    this.thinking = '',
    this.isThinking = false,
    this.imageDataUrl,
  });

  final String role;
  final String content;
  final String thinking;

  /// True while reasoning tokens are still arriving.
  final bool isThinking;

  final String? imageDataUrl;

  bool get isUser => role == 'user';
  bool get hasThinking => thinking.trim().isNotEmpty;

  AiTurn copyWith({String? content, String? thinking, bool? isThinking}) =>
      AiTurn(
        role: role,
        content: content ?? this.content,
        thinking: thinking ?? this.thinking,
        isThinking: isThinking ?? this.isThinking,
        imageDataUrl: imageDataUrl,
      );

  @override
  List<Object?> get props => [
    role,
    content,
    thinking,
    isThinking,
    imageDataUrl,
  ];
}

class AdvancedAiState extends Equatable {
  const AdvancedAiState({
    this.turns = const [],
    this.streaming = false,
    this.error,
  });

  final List<AiTurn> turns;
  final bool streaming;
  final String? error;

  AdvancedAiState copyWith({
    List<AiTurn>? turns,
    bool? streaming,
    String? error,
  }) => AdvancedAiState(
    turns: turns ?? this.turns,
    streaming: streaming ?? this.streaming,
    error: error,
  );

  @override
  List<Object?> get props => [turns, streaming, error];
}

/// Streaming chat backed by `/v1/openrouter-chat`.
///
/// Mirrors the web dashboard's request: full history, `stream: true`, the UI
/// language (the server picks its system prompt from it, and answers in
/// Egyptian Arabic for `ar`), and high reasoning effort.
class AdvancedAiCubit extends Cubit<AdvancedAiState> {
  AdvancedAiCubit(this._api) : super(const AdvancedAiState());

  final ApiClient _api;

  /// Kept as API-shaped content so history replays exactly as it was sent —
  /// a multimodal array when an image was attached, a plain string otherwise.
  final List<Object> _apiContents = [];

  Future<void> send(String text, {XFile? image, String lang = 'en'}) async {
    final q = text.trim();
    if ((q.isEmpty && image == null) || state.streaming) return;

    String? previewUrl;
    Map<String, dynamic>? imageBlock;

    if (image != null) {
      final bytes = await image.readAsBytes();
      try {
        // The server compresses and returns the block to embed.
        imageBlock = await _api.uploadChatMedia(
          bytes: bytes,
          fileName: image.name,
          prompt: q,
        );
        previewUrl = (imageBlock?['image_url'] as Map?)?['url']?.toString();
      } on AppException {
        // Upload is an optimisation, not a requirement — fall back to encoding
        // locally so an attachment still works if the endpoint is unavailable.
        final mime = image.mimeType ?? 'image/jpeg';
        previewUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        imageBlock = {
          'type': 'image_url',
          'image_url': {'url': previewUrl},
        };
      }
    }

    final Object userContent = imageBlock == null
        ? q
        : [
            if (q.isNotEmpty) {'type': 'text', 'text': q},
            imageBlock,
          ];

    final history = [..._apiContents];
    _apiContents.add(userContent);

    emit(
      state.copyWith(
        turns: [
          ...state.turns,
          AiTurn(role: 'user', content: q, imageDataUrl: previewUrl),
          const AiTurn(role: 'assistant'),
        ],
        streaming: true,
        error: null,
      ),
    );

    final answer = StringBuffer();
    final thinking = StringBuffer();
    var inThinkTag = false;

    void push({bool? isThinking}) {
      final turns = [...state.turns];
      turns[turns.length - 1] = turns.last.copyWith(
        content: answer.toString(),
        thinking: thinking.toString(),
        isThinking: isThinking,
      );
      emit(state.copyWith(turns: turns));
    }

    try {
      final stream = _api.streamChatTokens(
        '/v1/openrouter-chat',
        body: {
          'messages': [
            for (var i = 0; i < history.length; i++)
              {'role': i.isEven ? 'user' : 'assistant', 'content': history[i]},
            {'role': 'user', 'content': userContent},
          ],
          'stream': true,
          'lang': lang,
          'reasoning': {'effort': 'high'},
        },
      );

      await for (final token in stream) {
        if (isClosed) return;

        if (token.isReasoning) {
          thinking.write(token.text);
          push(isThinking: true);
          continue;
        }

        // Some models wrap their working in <think> tags inside the content
        // channel instead of using a separate one.
        var chunk = token.text;
        if (!inThinkTag && chunk.contains('<think>')) {
          final parts = chunk.split('<think>');
          answer.write(parts.first);
          if (parts.length > 1) thinking.write(parts[1]);
          inThinkTag = true;
          push(isThinking: true);
          continue;
        }
        if (inThinkTag) {
          if (chunk.contains('</think>')) {
            final parts = chunk.split('</think>');
            thinking.write(parts.first);
            if (parts.length > 1) answer.write(parts[1]);
            inThinkTag = false;
            push(isThinking: false);
          } else {
            thinking.write(chunk);
            push(isThinking: true);
          }
          continue;
        }

        // Content with no reasoning alongside it means the thinking is done.
        answer.write(chunk);
        push(isThinking: false);
      }

      _apiContents.add(answer.toString());
      emit(state.copyWith(streaming: false));
    } on AppException catch (e) {
      _fail(answer, thinking, e.message);
    } catch (_) {
      _fail(answer, thinking, 'Streaming failed. Please try again.');
    }
  }

  void _fail(StringBuffer answer, StringBuffer thinking, String error) {
    final turns = [...state.turns];
    if (turns.isNotEmpty) {
      turns[turns.length - 1] = turns.last.copyWith(
        content: answer.isEmpty ? error : answer.toString(),
        thinking: thinking.toString(),
        isThinking: false,
      );
    }
    emit(state.copyWith(turns: turns, streaming: false, error: error));
  }

  void clear() {
    _apiContents.clear();
    emit(const AdvancedAiState());
  }
}

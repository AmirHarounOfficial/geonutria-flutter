import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../consultant/data/consultant_models.dart';

class AdvancedAiState extends Equatable {
  const AdvancedAiState({
    this.messages = const [],
    this.streaming = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool streaming;
  final String? error;

  AdvancedAiState copyWith({
    List<ChatMessage>? messages,
    bool? streaming,
    String? error,
  }) =>
      AdvancedAiState(
        messages: messages ?? this.messages,
        streaming: streaming ?? this.streaming,
        error: error,
      );

  @override
  List<Object?> get props => [messages, streaming, error];
}

/// General-purpose streaming chat backed by `/v1/openrouter-chat` (cloud
/// Nemotron model). Tokens stream into the trailing assistant message.
class AdvancedAiCubit extends Cubit<AdvancedAiState> {
  AdvancedAiCubit(this._api) : super(const AdvancedAiState());

  final ApiClient _api;

  Future<void> send(String text, {XFile? image}) async {
    final q = text.trim();
    if ((q.isEmpty && image == null) || state.streaming) return;

    // Encode an attached image as a data URL for both display and the request.
    String? dataUrl;
    if (image != null) {
      final bytes = await image.readAsBytes();
      final mime = image.mimeType ?? 'image/jpeg';
      dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    }

    final priorMessages = state.messages;
    final base = [
      ...priorMessages,
      ChatMessage(role: 'user', content: q, imageDataUrl: dataUrl),
      const ChatMessage(role: 'assistant', content: ''),
    ];
    emit(state.copyWith(messages: base, streaming: true, error: null));

    // Current turn's content: multimodal array when an image is attached,
    // otherwise a plain string (OpenAI/OpenRouter-compatible).
    final Object userContent = dataUrl == null
        ? q
        : [
            if (q.isNotEmpty) {'type': 'text', 'text': q},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ];

    final buffer = StringBuffer();
    try {
      final stream = _api.streamChatTokens('/v1/openrouter-chat', body: {
        'messages': [
          for (final m in priorMessages) m.toJson(),
          {'role': 'user', 'content': userContent},
        ],
        'stream': true,
      });
      await for (final token in stream) {
        if (isClosed) return;
        buffer.write(token);
        final msgs = [...state.messages];
        msgs[msgs.length - 1] =
            ChatMessage(role: 'assistant', content: buffer.toString());
        emit(state.copyWith(messages: msgs));
      }
      emit(state.copyWith(streaming: false));
    } on AppException catch (e) {
      _failLast(buffer, e.message);
    } catch (_) {
      _failLast(buffer, 'Streaming failed. Please try again.');
    }
  }

  void _failLast(StringBuffer buffer, String error) {
    final msgs = [...state.messages];
    if (msgs.isNotEmpty) {
      msgs[msgs.length - 1] = ChatMessage(
        role: 'assistant',
        content: buffer.isEmpty ? error : buffer.toString(),
      );
    }
    emit(state.copyWith(messages: msgs, streaming: false, error: error));
  }
}

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

class ChatSession extends Equatable {
  const ChatSession({
    required this.id,
    required this.preview,
    required this.updatedAt,
    this.turns = const [],
    this.apiContents = const [],
  });

  final String id;
  final String preview;
  final DateTime updatedAt;
  final List<AiTurn> turns;
  final List<Object> apiContents;

  ChatSession copyWith({
    String? preview,
    DateTime? updatedAt,
    List<AiTurn>? turns,
    List<Object>? apiContents,
  }) => ChatSession(
    id: id,
    preview: preview ?? this.preview,
    updatedAt: updatedAt ?? this.updatedAt,
    turns: turns ?? this.turns,
    apiContents: apiContents ?? this.apiContents,
  );

  @override
  List<Object?> get props => [id, preview, updatedAt, turns, apiContents];
}

class AdvancedAiState extends Equatable {
  const AdvancedAiState({
    this.currentSessionId = 'default',
    this.sessions = const [],
    this.turns = const [],
    this.streaming = false,
    this.error,
  });

  final String currentSessionId;
  final List<ChatSession> sessions;
  final List<AiTurn> turns;
  final bool streaming;
  final String? error;

  AdvancedAiState copyWith({
    String? currentSessionId,
    List<ChatSession>? sessions,
    List<AiTurn>? turns,
    bool? streaming,
    String? error,
  }) => AdvancedAiState(
    currentSessionId: currentSessionId ?? this.currentSessionId,
    sessions: sessions ?? this.sessions,
    turns: turns ?? this.turns,
    streaming: streaming ?? this.streaming,
    error: error,
  );

  @override
  List<Object?> get props => [
    currentSessionId,
    sessions,
    turns,
    streaming,
    error,
  ];
}

/// Streaming chat backed by `/v1/openrouter-chat`.
///
/// Mirrors the web dashboard's request: full history, `stream: true`, the UI
/// language (the server picks its system prompt from it, and answers in
/// Egyptian Arabic for `ar`), and high reasoning effort.
class AdvancedAiCubit extends Cubit<AdvancedAiState> {
  AdvancedAiCubit(this._api) : super(const AdvancedAiState());

  final ApiClient _api;

  List<Object> _apiContents = [];
  bool _streamingAborted = false;
  int _generation = 0;

  void stop() {
    if (!state.streaming) return;
    _generation++;
    _streamingAborted = true;
    if (_apiContents.length.isOdd &&
        state.turns.isNotEmpty &&
        !state.turns.last.isUser) {
      _apiContents.add(state.turns.last.content);
    }
    emit(state.copyWith(streaming: false));
    _saveCurrentSession();
  }

  void newChat() {
    stop();
    _generation++;
    _streamingAborted = true;
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    _apiContents = [];
    emit(
      state.copyWith(
        currentSessionId: newId,
        turns: const [],
        streaming: false,
        error: null,
      ),
    );
  }

  void selectSession(String sessionId) {
    stop();
    _generation++;
    _streamingAborted = true;
    final session = state.sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => ChatSession(
        id: sessionId,
        preview: 'New Chat',
        updatedAt: DateTime.now(),
      ),
    );

    _apiContents = [...session.apiContents];
    emit(
      state.copyWith(
        currentSessionId: session.id,
        turns: session.turns,
        streaming: false,
        error: null,
      ),
    );
  }

  void deleteSession(String sessionId) {
    final nextSessions = state.sessions
        .where((s) => s.id != sessionId)
        .toList();
    if (state.currentSessionId == sessionId) {
      newChat();
      emit(state.copyWith(sessions: nextSessions));
    } else {
      emit(state.copyWith(sessions: nextSessions));
    }
  }

  Future<void> send(String text, {XFile? image, String lang = 'en'}) async {
    final q = text.trim();
    if ((q.isEmpty && image == null) || state.streaming) return;

    final generation = ++_generation;
    String? previewUrl;
    Map<String, dynamic>? imageBlock;

    if (image != null) {
      final bytes = await image.readAsBytes();
      // Match the dashboard's FileReader data URL. The upload endpoint can
      // return application/octet-stream, which vision providers reject.
      final mime = _imageMime(bytes, image);
      previewUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      imageBlock = {
        'type': 'image_url',
        'image_url': {'url': previewUrl},
      };
    }

    if (isClosed || generation != _generation) return;
    final Object userContent = imageBlock == null
        ? q
        : [
            {'type': 'text', 'text': q},
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

    _streamingAborted = false;

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
        if (isClosed || generation != _generation || _streamingAborted) return;

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

      if (isClosed || generation != _generation) return;
      _apiContents.add(answer.toString());
      emit(state.copyWith(streaming: false));
      _saveCurrentSession();
    } on AppException catch (e) {
      if (isClosed || generation != _generation) return;
      _fail(answer, thinking, e.message);
    } catch (_) {
      if (isClosed || generation != _generation) return;
      _fail(answer, thinking, 'Streaming failed. Please try again.');
    }
  }

  void _saveCurrentSession() {
    if (state.turns.isEmpty) return;
    final firstUserTurn = state.turns.firstWhere(
      (t) => t.isUser && t.content.isNotEmpty,
      orElse: () => state.turns.first,
    );
    final preview = firstUserTurn.content.isNotEmpty
        ? (firstUserTurn.content.length > 35
              ? '${firstUserTurn.content.substring(0, 35)}…'
              : firstUserTurn.content)
        : 'Image inquiry';

    final updated = ChatSession(
      id: state.currentSessionId,
      preview: preview,
      updatedAt: DateTime.now(),
      turns: state.turns,
      apiContents: List<Object>.of(_apiContents),
    );

    final sessions = [...state.sessions];
    final idx = sessions.indexWhere((s) => s.id == state.currentSessionId);
    if (idx >= 0) {
      sessions[idx] = updated;
    } else {
      sessions.insert(0, updated);
    }
    emit(state.copyWith(sessions: sessions));
  }

  void _fail(StringBuffer answer, StringBuffer thinking, String error) {
    // Only completed pairs belong in API history. A failed request must not
    // shift subsequent user messages into the assistant role.
    if (_apiContents.length.isOdd) {
      if (answer.isEmpty) {
        _apiContents.removeLast();
      } else {
        _apiContents.add(answer.toString());
      }
    }
    final turns = [...state.turns];
    if (turns.isNotEmpty) {
      turns[turns.length - 1] = turns.last.copyWith(
        content: answer.isEmpty ? error : answer.toString(),
        thinking: thinking.toString(),
        isThinking: false,
      );
    }
    emit(state.copyWith(turns: turns, streaming: false, error: error));
    _saveCurrentSession();
  }

  void clear() {
    _generation++;
    _apiContents.clear();
    emit(const AdvancedAiState());
  }

  static String _imageMime(List<int> bytes, XFile image) {
    bool startsWith(List<int> prefix) =>
        bytes.length >= prefix.length &&
        List.generate(
          prefix.length,
          (i) => bytes[i] == prefix[i],
        ).every((matches) => matches);
    if (startsWith([0xff, 0xd8, 0xff])) return 'image/jpeg';
    if (startsWith([0x89, 0x50, 0x4e, 0x47])) return 'image/png';
    if (startsWith([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
        bytes.length >= 12 &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    final mime = image.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    switch (image.name.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';

class SupportMessage extends Equatable {
  const SupportMessage({required this.role, required this.message});
  final String role; // User / Agent / System / Admin
  final String message;

  bool get isUser => role.toLowerCase() == 'user';

  @override
  List<Object?> get props => [role, message];
}

class SupportState extends Equatable {
  const SupportState({
    this.messages = const [],
    this.connected = false,
    this.error,
  });

  final List<SupportMessage> messages;
  final bool connected;
  final String? error;

  SupportState copyWith({
    List<SupportMessage>? messages,
    bool? connected,
    String? error,
  }) => SupportState(
    messages: messages ?? this.messages,
    connected: connected ?? this.connected,
    error: error,
  );

  @override
  List<Object?> get props => [messages, connected, error];
}

/// Live technical-support chat over WebSocket, seeded with REST history.
class SupportCubit extends Cubit<SupportState> {
  SupportCubit(this._api, this._userId) : super(const SupportState());

  final ApiClient _api;
  final int _userId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connecting = false;

  Future<void> reconnect() async {
    if (_connecting || state.connected || isClosed) return;
    await _sub?.cancel();
    await _channel?.sink.close();
    if (!isClosed) await _connect();
  }

  Future<void> init() async {
    await _loadHistory();
    if (!isClosed) await _connect();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.get('/support/$_userId/history');
      if (data is List) {
        final msgs = data
            .whereType<Map>()
            .map(
              (e) => SupportMessage(
                role: '${e['role']}',
                message: '${e['message']}',
              ),
            )
            .toList();
        if (!isClosed) emit(state.copyWith(messages: msgs));
      }
    } catch (_) {
      // History is best-effort.
    }
  }

  Future<void> _connect() async {
    if (_connecting || isClosed) return;
    _connecting = true;
    try {
      final uri = Uri.parse('${Env.wsBaseUrl}/support/ws/$_userId');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (_) {
          if (!isClosed) emit(state.copyWith(connected: false));
        },
        onDone: () {
          if (!isClosed) emit(state.copyWith(connected: false));
        },
      );
      await channel.ready;
      if (!isClosed) emit(state.copyWith(connected: true));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(connected: false, error: '$e'));
    } finally {
      _connecting = false;
    }
  }

  void _onData(dynamic data) {
    if (isClosed) return;
    try {
      final json = jsonDecode('$data') as Map<String, dynamic>;
      final msg = SupportMessage(
        role: '${json['role'] ?? 'Agent'}',
        message: '${json['message'] ?? ''}',
      );
      emit(state.copyWith(messages: [...state.messages, msg]));
    } catch (_) {
      emit(
        state.copyWith(
          messages: [
            ...state.messages,
            SupportMessage(role: 'Agent', message: '$data'),
          ],
        ),
      );
    }
  }

  bool send(String text) {
    final t = text.trim();
    if (t.isEmpty || _channel == null || !state.connected || isClosed)
      return false;
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          SupportMessage(role: 'User', message: t),
        ],
      ),
    );
    _channel!.sink.add(t);
    return true;
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _channel?.sink.close();
    return super.close();
  }
}

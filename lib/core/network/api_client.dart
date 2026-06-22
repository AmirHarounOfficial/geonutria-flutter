import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../error/app_exception.dart';
import '../storage/secure_session.dart';
import 'paywall_notifier.dart';

/// Thin wrapper over Dio that mirrors the web `apiService.js`:
/// generic get/post/put/delete + multipart upload + PDF download, with the
/// backend's quirks centralized here (402 -> [InsufficientCreditsException],
/// `user_id` as the auth credential rather than a bearer token).
class ApiClient {
  ApiClient(this._session, {PaywallNotifier? paywall})
      : _paywall = paywall,
        _dio = Dio(_options) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) {
          if (e.response?.statusCode == 402) {
            _paywall?.trigger();
            handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                error: const InsufficientCreditsException(),
                response: e.response,
                type: e.type,
              ),
            );
            return;
          }
          handler.next(e);
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
      ));
    }
  }

  final SecureSession _session;
  final PaywallNotifier? _paywall;
  final Dio _dio;

  static final BaseOptions _options = BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Accept': 'application/json'},
  );

  int? get userId => _session.userId;

  /// Merge the current `user_id` into a query map (the backend's auth scheme).
  Map<String, dynamic> authQuery([Map<String, dynamic>? extra]) {
    final uid = _session.userId;
    return {
      'user_id': ?uid,
      ...?extra,
    };
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() async {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    });
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() async {
      final res = await _dio.post(path, data: body, queryParameters: query);
      return res.data;
    });
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() async {
      final res = await _dio.put(path, data: body, queryParameters: query);
      return res.data;
    });
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() async {
      final res = await _dio.delete(path, data: body, queryParameters: query);
      return res.data;
    });
  }

  /// Multipart upload. [files] maps a form field name to a [MultipartFile].
  Future<dynamic> upload(
    String path, {
    required Map<String, MultipartFile> files,
    Map<String, dynamic>? fields,
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() async {
      final form = FormData();
      fields?.forEach((k, v) => form.fields.add(MapEntry(k, '$v')));
      files.forEach((k, v) => form.files.add(MapEntry(k, v)));
      final res = await _dio.post(path, data: form, queryParameters: query);
      return res.data;
    });
  }

  /// POST that streams an OpenAI-style SSE response (`/v1/openrouter-chat`),
  /// yielding incremental `choices[0].delta.content` text tokens.
  Stream<String> streamChatTokens(String path, {Object? body}) async* {
    final resp = await _dio.post(
      path,
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
    final stream = (resp.data as ResponseBody).stream;
    final lines = stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') {
        if (payload == '[DONE]') break;
        continue;
      }
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final err = json['error'];
        if (err is Map && err['message'] != null) {
          throw AppException('${err['message']}');
        }
        final choices = json['choices'];
        if (choices is List && choices.isNotEmpty) {
          final delta = (choices.first as Map)['delta'];
          final content = delta is Map ? delta['content'] : null;
          if (content is String && content.isNotEmpty) yield content;
        }
      } on AppException {
        rethrow;
      } catch (_) {
        // Ignore keep-alive / non-JSON lines.
      }
    }
  }

  /// POST that expects a binary PDF response (report generation).
  Future<Uint8List> postPdf(String path, {Object? body}) async {
    return _wrap(() async {
      final res = await _dio.post(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );
      return Uint8List.fromList(res.data as List<int>);
    });
  }

  Future<T> _wrap<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final err = e.error;
      if (err is AppException) throw err;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      final code = e.response?.statusCode;
      final msg = _extractMessage(e.response?.data) ??
          'Request failed${code != null ? ' ($code)' : ''}';
      throw AppException(msg, statusCode: code);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['detail'] != null) return '${data['detail']}';
    if (data is Map && data['message'] != null) return '${data['message']}';
    if (data is String && data.isNotEmpty) return data;
    return null;
  }
}

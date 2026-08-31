import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../error/app_exception.dart';
import '../logging/in_app_log_service.dart';
import '../storage/secure_session.dart';
import 'paywall_notifier.dart';

/// Thin wrapper over Dio that mirrors the web `apiService.js`:
/// generic get/post/put/delete + multipart upload + PDF download, with the
/// backend's quirks centralized here (402 -> [InsufficientCreditsException],
/// `user_id` as the auth credential rather than a bearer token).
/// A single streamed token, tagged with which channel it belongs to.
class ChatToken {
  const ChatToken._(this.text, this.isReasoning);
  const ChatToken.content(String text) : this._(text, false);
  const ChatToken.reasoning(String text) : this._(text, true);

  final String text;

  /// True when this is part of the model's chain of thought rather than the
  /// answer the user asked for.
  final bool isReasoning;
}

class ApiClient {
  ApiClient(this._session, {PaywallNotifier? paywall})
    : _paywall = paywall,
      _dio = Dio(_options) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final queryStr = options.queryParameters.isNotEmpty
              ? '\nQuery Parameters:\n${_formatJson(options.queryParameters)}'
              : '';
          final bodyStr = options.data != null
              ? '\nRequest Body:\n${_formatJson(options.data)}'
              : '';
          InAppLogService.instance.network(
            method: options.method,
            url: options.uri.toString(),
            statusCode: null,
            message: 'Request ->',
            details: 'Headers: ${options.headers}$queryStr$bodyStr',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          InAppLogService.instance.network(
            method: response.requestOptions.method,
            url: response.requestOptions.uri.toString(),
            statusCode: response.statusCode,
            message: 'Response <- OK',
            details: 'Incoming Response Body:\n${_formatJson(response.data)}',
          );
          handler.next(response);
        },
        onError: (e, handler) {
          final respData = e.response?.data;
          final respStr = respData != null
              ? '\nIncoming Response Body:\n${_formatJson(respData)}'
              : '';
          InAppLogService.instance.network(
            method: e.requestOptions.method,
            url: e.requestOptions.uri.toString(),
            statusCode: e.response?.statusCode,
            message: 'Response Error: ${e.message ?? e.error}',
            details:
                'Type: ${e.type}\nStatus Code: ${e.response?.statusCode}\nError: ${e.error}$respStr',
            isError: true,
          );
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
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
        ),
      );
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
    return {'user_id': ?uid, ...?extra};
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
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

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    return _wrap(() async {
      final res = await _dio.patch(path, data: body, queryParameters: query);
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
  /// One token from the chat stream.
  ///
  /// The reasoning model emits its working separately from its answer, so the
  /// two are kept apart rather than concatenated — otherwise the chain of
  /// thought lands in the middle of the reply.
  Stream<ChatToken> streamChatTokens(String path, {Object? body}) async* {
    final resp = await _dio.post(
      path,
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    Stream<String> lineStream;
    final data = resp.data;
    if (data is ResponseBody) {
      lineStream = data.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
    } else if (data is String) {
      lineStream = Stream.fromIterable(data.split('\n'));
    } else if (data is List<int>) {
      lineStream = Stream.value(utf8.decode(data))
          .transform(const LineSplitter());
    } else if (data != null) {
      lineStream = Stream.value(data.toString())
          .transform(const LineSplitter());
    } else {
      return;
    }

    await for (final line in lineStream) {
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
          if (delta is Map) {
            String? reasoning = delta['reasoning']?.toString();
            if (reasoning == null || reasoning.isEmpty) {
              final details = delta['reasoning_details'];
              if (details is List && details.isNotEmpty) {
                reasoning = details
                    .whereType<Map>()
                    .map((d) => d['text'] ?? '')
                    .join();
              }
            }
            if (reasoning != null && reasoning.isNotEmpty) {
              yield ChatToken.reasoning(reasoning);
            }
            final content = delta['content'];
            if (content is String && content.isNotEmpty) {
              yield ChatToken.content(content);
            }
          }
        } else {
          // Some providers send a plain message instead of a delta.
          final content = (json['message'] as Map?)?['content'];
          if (content is String && content.isNotEmpty) {
            yield ChatToken.content(content);
          }
        }
      } on AppException {
        rethrow;
      } catch (_) {
        // Ignore keep-alive / non-JSON lines.
      }
    }
  }

  /// Uploads an attachment for the AI chat and returns the multimodal content
  /// block to embed in the message.
  ///
  /// Worth the round trip: the server compresses anything over 1 MB, and a
  /// phone photo is routinely several megabytes. Encoding it locally would
  /// push a base64 payload of that size through the request.
  Future<Map<String, dynamic>?> uploadChatMedia({
    required List<int> bytes,
    required String fileName,
    String prompt = '',
  }) async {
    final data = await upload(
      '/v1/upload-media',
      files: {'file': MultipartFile.fromBytes(bytes, filename: fileName)},
      fields: {'prompt': prompt},
    );
    final block = (data is Map) ? data['content_block'] : null;
    if (block is Map) return block.cast<String, dynamic>();
    return null;
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
      final serverMsg = _extractMessage(e.response?.data);
      if (serverMsg != null && serverMsg.isNotEmpty) {
        throw AppException(serverMsg, statusCode: e.response?.statusCode);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        if (kIsWeb) {
          final isXmlErr = e.toString().contains('XMLHttpRequest') ||
              e.message?.contains('XMLHttpRequest') == true ||
              e.error?.toString().contains('XMLHttpRequest') == true;
          if (isXmlErr) {
            throw NetworkException(
              'Browser CORS / Network error connecting to ${Env.apiBaseUrl}. Ensure CORS preflight is configured on the server, or test on Android / iOS / Desktop.',
            );
          }
          throw NetworkException(
            'Unable to connect to backend server (${Env.apiBaseUrl}). Please check server network connection.',
          );
        }
        throw const NetworkException();
      }
      final code = e.response?.statusCode;
      final msg = 'Request failed${code != null ? ' ($code)' : ''}';
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

String _formatJson(dynamic data) {
  if (data == null) return 'null';
  try {
    if (data is Map || data is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }
    if (data is String && (data.startsWith('{') || data.startsWith('['))) {
      final decoded = jsonDecode(data);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    }
  } catch (_) {}
  return '$data';
}

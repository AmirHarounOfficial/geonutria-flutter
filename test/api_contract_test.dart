import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/core/error/app_exception.dart';
import 'package:geonutria_mobile/core/network/api_client.dart';
import 'package:geonutria_mobile/core/network/paywall_notifier.dart';
import 'package:geonutria_mobile/core/storage/secure_session.dart';
import 'package:geonutria_mobile/features/consultant/data/consultant_repository.dart';

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ApiClient client(
  ResponseBody Function(RequestOptions) respond, {
  PaywallNotifier? paywall,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.httpClientAdapter = TestAdapter(respond);
  return ApiClient(SecureSession(), dio: dio, paywall: paywall);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF download rejects successful HTML or JSON responses', () async {
    final api = client(
      (_) => ResponseBody.fromString(
        '<html>Error</html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );
    await expectLater(
      api.postPdf('/generate-report'),
      throwsA(isA<AppException>()),
    );
    final spoofed = client(
      (_) => ResponseBody.fromString(
        'not a PDF',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/pdf'],
        },
      ),
    );
    await expectLater(
      spoofed.postPdf('/generate-report'),
      throwsA(isA<AppException>()),
    );
  });
  test('Valid PDF bytes are preserved', () async {
    final api = client(
      (_) => ResponseBody.fromString(
        '%PDF-1.7\nbody',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/pdf'],
        },
      ),
    );
    expect(
      utf8.decode(await api.postPdf('/generate-report')),
      '%PDF-1.7\nbody',
    );
  });
  test(
    'Consultant sends the chosen language instead of backend Arabic default',
    () async {
      final api = client((request) {
        expect(request.path, '/ai-consultant/start');
        expect((request.data as Map)['lang'], 'en');
        expect((request.data as Map)['user_id'], 7);
        return ResponseBody.fromString(
          '{"task_id":"test"}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      expect(
        await ConsultantRepository(api).start(
          userId: 7,
          history: [],
          selection: ConsultantSelection(),
          lang: 'en',
        ),
        'test',
      );
    },
  );
  test('Streamed 402 errors keep the same paywall behavior as REST', () async {
    final paywall = PaywallNotifier();
    var notified = false;
    paywall.addListener(() => notified = true);
    final api = client(
      (_) => ResponseBody.fromString(
        '{"detail":"Insufficient credits"}',
        402,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
      paywall: paywall,
    );
    await expectLater(
      api.streamChatTokens('/predict-yield').toList(),
      throwsA(isA<InsufficientCreditsException>()),
    );
    expect(notified, isTrue);
  });
}

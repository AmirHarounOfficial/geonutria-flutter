import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geonutria_mobile/core/error/app_exception.dart';
import 'package:geonutria_mobile/core/network/api_client.dart';
import 'package:geonutria_mobile/core/storage/secure_session.dart';
import 'package:geonutria_mobile/features/advanced_ai/advanced_ai_cubit.dart';

class ChatApi extends ApiClient {
  ChatApi() : super(SecureSession());
  final requests = <Map>[];
  bool fail = false;

  @override
  Stream<ChatToken> streamChatTokens(String path, {Object? body}) async* {
    expect(path, '/v1/openrouter-chat');
    requests.add(body as Map);
    if (fail) throw const AppException('Temporary failure');
    yield const ChatToken.content('Answer');
  }

  @override
  Future<Map<String, dynamic>?> uploadChatMedia({
    required List<int> bytes,
    required String fileName,
    String prompt = '',
  }) => throw StateError('Dashboard image requests do not use upload-media');
}

void main() {
  for (final lang in ['ar', 'en']) {
    test('Image requests match dashboard contract in $lang', () async {
      final api = ChatApi();
      final cubit = AdvancedAiCubit(api);
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      await cubit.send(
        'Describe this soil',
        lang: lang,
        image: XFile.fromData(
          bytes,
          name: 'photo',
          mimeType: 'application/octet-stream',
        ),
      );
      expect(api.requests.single, {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Describe this soil'},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,${base64Encode(bytes)}',
                },
              },
            ],
          },
        ],
        'stream': true,
        'lang': lang,
        'reasoning': {'effort': 'high'},
      });
      expect(cubit.state.error, isNull);
      await cubit.close();
    });
  }

  test(
    'Failed sends cannot corrupt roles in later conversation history',
    () async {
      final api = ChatApi();
      final cubit = AdvancedAiCubit(api);
      await cubit.send('First');
      api.fail = true;
      await cubit.send('Failed');
      api.fail = false;
      await cubit.send('Retry');
      expect(api.requests.last['messages'], [
        {'role': 'user', 'content': 'First'},
        {'role': 'assistant', 'content': 'Answer'},
        {'role': 'user', 'content': 'Retry'},
      ]);
      await cubit.close();
    },
  );

  test(
    'Clearing a conversation does not erase stored session API history',
    () async {
      final api = ChatApi();
      final cubit = AdvancedAiCubit(api);
      await cubit.send('First');
      final saved = cubit.state.sessions.single;
      cubit.clear();
      expect(saved.apiContents, ['First', 'Answer']);
      await cubit.close();
    },
  );
}

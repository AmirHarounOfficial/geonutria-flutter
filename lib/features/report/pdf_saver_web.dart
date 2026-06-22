import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: turn the PDF bytes into a Blob and trigger a browser download.
Future<void> savePdf(List<int> bytes, String fileName) async {
  final data = Uint8List.fromList(bytes);
  final parts = <JSAny>[data.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

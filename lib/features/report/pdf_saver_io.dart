import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write the PDF to a temp file and open the share sheet.
Future<void> savePdf(List<int> bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(path)], text: 'GeoNutria farm report');
}

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Cancellation must not silently write another copy.
Future<String?> savePdf(
  List<int> bytes,
  String fileName, {
  String title = 'Save Report PDF',
}) async {
  final path = await FilePicker.saveFile(
    dialogTitle: title,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    bytes: Uint8List.fromList(bytes),
  );
  if (path != null &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return path;
}

Future<void> sharePdf(
  List<int> bytes,
  String fileName, {
  String title = 'GeoNutria Farm Report',
}) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(path, mimeType: 'application/pdf', name: fileName)],
    subject: title,
    text: title,
  );
}

/// The system chooser attaches the PDF; mailto cannot attach files.
Future<void> sharePdfViaEmail(
  List<int> bytes,
  String fileName, {
  String? recipientEmail,
  String title = 'GeoNutria Farm Report',
}) => sharePdf(bytes, fileName, title: title);

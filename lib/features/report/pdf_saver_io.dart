import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mobile/desktop direct download: writes the PDF directly to disk (Downloads/Documents)
/// without opening the system share sheet.
Future<String?> savePdf(List<int> bytes, String fileName) async {
  String? targetPath;

  // Try file picker save dialog if available
  try {
    targetPath = await FilePicker.saveFile(
      dialogTitle: 'Save Report PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: Uint8List.fromList(bytes),
    );
  } catch (_) {}

  // Fallback to direct directory writing if saveFile returned null or is unsupported
  if (targetPath == null || targetPath.isEmpty) {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}

    if (dir == null && Platform.isAndroid) {
      final pubDownload = Directory('/storage/emulated/0/Download');
      if (pubDownload.existsSync()) {
        dir = pubDownload;
      }
    }

    dir ??= await getApplicationDocumentsDirectory();

    targetPath = '${dir.path}/$fileName';
    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
  } else {
    // Ensure file bytes are written if file_picker returned a path but didn't write bytes automatically
    final file = File(targetPath);
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
  }

  return targetPath;
}

/// Mobile/desktop: write PDF to temporary storage and open the native system share sheet.
Future<void> sharePdf(List<int> bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(path, mimeType: 'application/pdf', name: fileName)],
    subject: 'GeoNutria Farm Report',
    text: 'GeoNutria farm report',
  );
}

/// Share generated PDF report via email intent / email application.
Future<void> sharePdfViaEmail(List<int> bytes, String fileName, {String? recipientEmail}) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(bytes, flush: true);

  final mailtoUri = Uri(
    scheme: 'mailto',
    path: recipientEmail ?? '',
    queryParameters: {
      'subject': 'GeoNutria Farm Report',
      'body': 'Please find attached the GeoNutria farm report.',
    },
  );

  if (await canLaunchUrl(mailtoUri)) {
    await launchUrl(mailtoUri);
  } else {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf', name: fileName)],
      subject: 'GeoNutria Farm Report',
      text: 'GeoNutria farm report',
    );
  }
}

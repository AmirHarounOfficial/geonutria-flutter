import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mobile/desktop: write the PDF to a temp file and open the share sheet.
Future<void> savePdf(List<int> bytes, String fileName) async {
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
  }
  // Also invoke system share sheet with PDF attachment pre-filtered for email/apps
  await Share.shareXFiles(
    [XFile(path, mimeType: 'application/pdf', name: fileName)],
    subject: 'GeoNutria Farm Report',
    text: 'GeoNutria farm report',
  );
}

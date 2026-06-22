/// Cross-platform PDF persistence: on mobile/desktop it writes a temp file and
/// opens the share sheet; on web it triggers a browser download. The concrete
/// implementation is selected at compile time via conditional import.
export 'pdf_saver_io.dart' if (dart.library.html) 'pdf_saver_web.dart';

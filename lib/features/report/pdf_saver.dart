/// Cross-platform PDF persistence: on mobile/desktop it writes a temp file and
/// triggers direct download; on web it triggers a browser download.
library;

export 'pdf_saver_io.dart' if (dart.library.html) 'pdf_saver_web.dart';

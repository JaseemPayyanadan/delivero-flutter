import 'dart:typed_data';

import 'pdf_download_impl.dart'
    if (dart.library.html) 'pdf_download_web.dart' as impl;

Future<void> downloadPdfFile(Uint8List bytes, String filename) {
  return impl.downloadPdfFile(bytes, filename);
}

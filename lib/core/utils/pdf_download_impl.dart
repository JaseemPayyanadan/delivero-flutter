import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> downloadPdfFile(Uint8List bytes, String filename) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

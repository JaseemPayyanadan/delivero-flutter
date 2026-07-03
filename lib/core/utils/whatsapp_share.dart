import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp with a pre-filled [message].
///
/// On mobile uses `wa.me`. On web uses WhatsApp Web and falls back to clipboard.
Future<void> openWhatsAppShare({required String message, String? phone}) async {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    throw Exception('Nothing to share.');
  }

  final encoded = Uri.encodeComponent(trimmed);

  if (kIsWeb) {
    await _openWhatsAppWeb(encoded: encoded, phone: phone);
    return;
  }

  final Uri uri;
  if (phone != null && phone.trim().isNotEmpty) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      throw Exception('Enter a valid WhatsApp number.');
    }
    uri = Uri.parse('https://wa.me/$digits?text=$encoded');
  } else {
    uri = Uri.parse('https://wa.me/?text=$encoded');
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    throw Exception('Could not open WhatsApp. Install it or try again.');
  }
}

Future<void> _openWhatsAppWeb({required String encoded, String? phone}) async {
  final Uri uri;
  if (phone != null && phone.trim().isNotEmpty) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      throw Exception('Enter a valid WhatsApp number.');
    }
    uri = Uri.parse(
      'https://web.whatsapp.com/send?phone=$digits&text=$encoded',
    );
  } else {
    uri = Uri.parse('https://web.whatsapp.com/send?text=$encoded');
  }

  final launched = await launchUrl(
    uri,
    webOnlyWindowName: '_blank',
    mode: LaunchMode.platformDefault,
  );

  if (launched) return;

  // Popup blocked or launcher unavailable — copy so user can paste in WhatsApp Web.
  await Clipboard.setData(ClipboardData(text: Uri.decodeComponent(encoded)));
  throw Exception(
    'WhatsApp could not open (popup blocked). Message copied — paste it in WhatsApp Web.',
  );
}

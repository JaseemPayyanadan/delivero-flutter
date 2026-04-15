import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the platform maps app or a maps URL with [address] as the destination query.
Future<bool> openMapsForAddress(String address) async {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return false;

  final encoded = Uri.encodeComponent(trimmed);
  final Uri uri;
  if (kIsWeb) {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
  } else {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        uri = Uri.parse('https://maps.apple.com/?q=$encoded');
        break;
      default:
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encoded',
        );
    }
  }

  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

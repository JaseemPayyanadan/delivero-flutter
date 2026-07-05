import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up free-text address suggestions from OpenStreetMap's Nominatim
/// search API (no API key required).
///
/// Nominatim's usage policy requires a valid identifying User-Agent and asks
/// callers to keep request volume low — callers should debounce keystrokes and
/// query only for reasonably long inputs.
class AddressSuggestionService {
  final http.Client _client;

  /// ISO 3166-1 alpha-2 country code(s) the search is biased to. Defaults to
  /// India ('in') to match the app's default phone country — without this bias
  /// Nominatim ranks matches globally by importance and returns famous
  /// worldwide places instead of the nearby address the user is typing.
  final String countryCodes;

  AddressSuggestionService({http.Client? client, this.countryCodes = 'in'})
      : _client = client ?? http.Client();

  static const _minQueryLength = 3;
  static const _userAgent = 'DelivroApp/1.0 (delivery management app)';

  /// Returns up to five human-readable address suggestions for [query].
  /// Returns an empty list for short queries or on any network/parse failure —
  /// suggestions are a convenience, never a hard dependency.
  Future<List<String>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < _minQueryLength) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '0',
      'limit': '5',
      'dedupe': '1',
      if (countryCodes.isNotEmpty) 'countrycodes': countryCodes,
    });

    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': _userAgent,
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => (e['display_name'] as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

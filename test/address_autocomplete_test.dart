import 'package:delivero/core/services/address_suggestion_service.dart';
import 'package:delivero/core/widgets/address_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AddressSuggestionService', () {
    test('parses display_name values from a Nominatim response', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.queryParameters['q'], 'mg road');
        // Region bias so results are local, not famous worldwide places.
        expect(request.url.queryParameters['countrycodes'], 'in');
        return http.Response(
          '[{"display_name":"MG Road, Kochi, Kerala"},'
          '{"display_name":"MG Road, Bengaluru, Karnataka"}]',
          200,
        );
      });

      final results = await AddressSuggestionService(client: client).search('mg road');
      expect(results, [
        'MG Road, Kochi, Kerala',
        'MG Road, Bengaluru, Karnataka',
      ]);
    });

    test('returns empty for short queries without hitting the network',
        () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });

      final results = await AddressSuggestionService(client: client).search('mg');
      expect(results, isEmpty);
      expect(called, isFalse);
    });

    test('returns empty on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final results =
          await AddressSuggestionService(client: client).search('somewhere');
      expect(results, isEmpty);
    });

    test('returns empty on malformed JSON', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final results =
          await AddressSuggestionService(client: client).search('somewhere');
      expect(results, isEmpty);
    });
  });

  group('AddressAutocompleteField', () {
    testWidgets('shows suggestions while typing and fills on tap',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddressAutocompleteField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Address'),
              search: (q) async => ['12 MG Road, Kochi', '9 Marine Drive'],
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'mg');
      // Wait past the 350ms debounce, then let the overlay build.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('12 MG Road, Kochi'), findsOneWidget);

      await tester.tap(find.text('12 MG Road, Kochi'));
      await tester.pumpAndSettle();

      expect(controller.text, '12 MG Road, Kochi');
    });
  });
}

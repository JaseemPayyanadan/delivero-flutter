import 'package:delivero/core/services/location_service.dart';
import 'package:delivero/core/widgets/use_current_location_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

Placemark _placemark({
  String? street,
  String? name,
  String? subLocality,
  String? locality,
  String? administrativeArea,
  String? postalCode,
}) {
  return Placemark(
    street: street,
    name: name,
    subLocality: subLocality,
    locality: locality,
    administrativeArea: administrativeArea,
    postalCode: postalCode,
  );
}

void main() {
  group('LocationService.formatAddress', () {
    test('joins the parts in order, skipping empties', () {
      final address = LocationService.formatAddress(
        _placemark(
          street: '12 MG Road',
          subLocality: 'Panampilly Nagar',
          locality: 'Kochi',
          administrativeArea: 'Kerala',
          postalCode: '682036',
        ),
      );
      expect(
        address,
        '12 MG Road, Panampilly Nagar, Kochi, Kerala, 682036',
      );
    });

    test('drops empty and whitespace-only parts', () {
      final address = LocationService.formatAddress(
        _placemark(street: '5th Cross', locality: 'Kochi', postalCode: '   '),
      );
      expect(address, '5th Cross, Kochi');
    });

    test('falls back to name when street is missing', () {
      final address = LocationService.formatAddress(
        _placemark(name: 'Sunrise Cafe', locality: 'Kochi'),
      );
      expect(address, 'Sunrise Cafe, Kochi');
    });

    test('removes case-insensitive duplicate parts', () {
      final address = LocationService.formatAddress(
        _placemark(
          street: 'Kochi',
          locality: 'Kochi',
          administrativeArea: 'Kerala',
        ),
      );
      expect(address, 'Kochi, Kerala');
    });

    test('returns empty string when nothing usable is present', () {
      expect(LocationService.formatAddress(_placemark()), '');
    });
  });

  group('UseCurrentLocationButton', () {
    Widget harness(TextEditingController controller,
        Future<LocationAddressResult> Function() fetcher) {
      return MaterialApp(
        home: Scaffold(
          body: UseCurrentLocationButton(
            addressController: controller,
            fetcher: fetcher,
          ),
        ),
      );
    }

    testWidgets('success fills the address controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        harness(
          controller,
          () async => const LocationAddressResult(
            LocationStatus.success,
            address: '12 MG Road, Kochi',
          ),
        ),
      );

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      expect(controller.text, '12 MG Road, Kochi');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('failure shows a snackbar and leaves the field empty',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        harness(
          controller,
          () async => const LocationAddressResult(LocationStatus.denied),
        ),
      );

      await tester.tap(find.text('Use current location'));
      await tester.pump(); // start async
      await tester.pump(); // settle snackbar

      expect(controller.text, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

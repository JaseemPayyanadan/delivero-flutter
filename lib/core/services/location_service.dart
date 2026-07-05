import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Why a location address lookup ended the way it did.
enum LocationStatus {
  success,

  /// Device location services are turned off system-wide.
  serviceDisabled,

  /// The user denied the permission this time.
  denied,

  /// The user denied permanently ("don't ask again" / iOS denied) — the app
  /// can only recover by sending them to Settings.
  deniedForever,

  /// Got a position but couldn't turn it into a readable address, or the
  /// lookup failed/timed out.
  failed,
}

/// Result of [LocationService.currentAddress].
class LocationAddressResult {
  final LocationStatus status;

  /// Human-readable address, only set when [status] is [LocationStatus.success].
  final String? address;

  const LocationAddressResult(this.status, {this.address});

  bool get isSuccess =>
      status == LocationStatus.success &&
      (address != null && address!.trim().isNotEmpty);
}

/// Resolves the device's current position into a readable street address.
///
/// Pure formatting lives in [formatAddress] so it can be unit-tested without
/// the platform channels.
class LocationService {
  const LocationService();

  Future<LocationAddressResult> currentAddress() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationAddressResult(LocationStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationAddressResult(LocationStatus.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationAddressResult(LocationStatus.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        return const LocationAddressResult(LocationStatus.failed);
      }

      final address = formatAddress(placemarks.first);
      if (address.isEmpty) {
        return const LocationAddressResult(LocationStatus.failed);
      }
      return LocationAddressResult(LocationStatus.success, address: address);
    } catch (_) {
      return const LocationAddressResult(LocationStatus.failed);
    }
  }

  /// Builds a single-line address from a [Placemark], dropping empty parts and
  /// removing case-insensitive duplicates (e.g. when `locality` repeats
  /// `subAdministrativeArea`). Order: street → subLocality → locality →
  /// administrativeArea → postalCode.
  static String formatAddress(Placemark place) {
    final parts = <String>[
      (place.street ?? '').trim().isNotEmpty
          ? place.street!.trim()
          : (place.name ?? '').trim(),
      (place.subLocality ?? '').trim(),
      (place.locality ?? '').trim(),
      (place.administrativeArea ?? '').trim(),
      (place.postalCode ?? '').trim(),
    ];

    final seen = <String>{};
    final result = <String>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      final key = part.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(part);
    }
    return result.join(', ');
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../theme/app_colors.dart';

/// A compact "Use current location" action that resolves the device location
/// into a readable address and writes it into [addressController].
///
/// [fetcher] is injectable so widget tests can supply a fake without touching
/// the platform channels; it defaults to the real [LocationService].
class UseCurrentLocationButton extends StatefulWidget {
  final TextEditingController addressController;
  final Future<LocationAddressResult> Function() fetcher;

  UseCurrentLocationButton({
    super.key,
    required this.addressController,
    Future<LocationAddressResult> Function()? fetcher,
  }) : fetcher = fetcher ?? const LocationService().currentAddress;

  @override
  State<UseCurrentLocationButton> createState() =>
      _UseCurrentLocationButtonState();
}

class _UseCurrentLocationButtonState extends State<UseCurrentLocationButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    LocationAddressResult result;
    try {
      result = await widget.fetcher();
    } catch (_) {
      result = const LocationAddressResult(LocationStatus.failed);
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess) {
      widget.addressController.text = result.address!;
      widget.addressController.selection = TextSelection.collapsed(
        offset: result.address!.length,
      );
      return;
    }
    _reportError(result.status);
  }

  void _reportError(LocationStatus status) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();

    late final String message;
    var offerSettings = false;
    switch (status) {
      case LocationStatus.serviceDisabled:
        message = 'Location is off. Turn it on, then try again.';
        break;
      case LocationStatus.denied:
        message = 'Location permission denied — enter the address manually.';
        break;
      case LocationStatus.deniedForever:
        message =
            'Location permission is blocked. Enable it in Settings to use this.';
        offerSettings = true;
        break;
      case LocationStatus.failed:
      case LocationStatus.success:
        message = "Couldn't get your location. Try again.";
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: offerSettings
            ? SnackBarAction(
                label: 'Settings',
                onPressed: Geolocator.openAppSettings,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _loading ? null : _onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(Icons.my_location_rounded, size: 18),
        label: Text(
          _loading ? 'Locating…' : 'Use current location',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

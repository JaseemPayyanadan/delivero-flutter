# delivero_flutter

A new Flutter project.

## Getting Started

## Wireless ADB

Android 11+ (Wireless debugging / pairing):

```bash
adb pair <phone-ip>:<pairing-port>
adb connect <phone-ip>:<adb-port>
```

Example:

```bash
adb connect 10.10.0.243:35071
```

If `10.10.0.243:35071` is the pairing port (shown under “Pair device with pairing code”), use:

```bash
adb pair 10.10.0.243:35071
```

Older method (TCP/IP 5555):

```bash
adb tcpip 5555
adb connect <phone-ip>:5555
```

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

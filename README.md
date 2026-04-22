# delivero_flutter

A new Flutter project.

## Getting Started

## Android signing / SHA1 verification (Google Play upload key)

- **Create `android/key.properties`** by copying `android/key.properties.example` and filling in your real values.
- **Verify the SHA1 Google will see** (run from the `android/` folder):

```bash
./gradlew signingReport
```

Look under the `release` variant for `SHA1:` and confirm it matches what Google expects.

If you prefer verifying directly against the keystore file:

```bash
keytool -list -v -keystore <path-to-your-upload-keystore.jks>
```

If you see your release build getting signed with the debug key, a `release` build will now fail unless `android/key.properties` is present (to prevent accidental uploads with the wrong fingerprint).

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

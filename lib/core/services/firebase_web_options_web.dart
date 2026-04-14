import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core/firebase_core.dart';

class FirebaseWebOptionsImpl {
  static FirebaseOptions? tryGet() {
    final cfgAny = globalContext.getProperty('firebaseConfig'.toJS);
    if (cfgAny.isUndefinedOrNull) return null;
    if (!cfgAny.isA<JSObject>()) return null;
    final config = cfgAny as JSObject;

    String getString(String key) {
      final v = config.getProperty(key.toJS);
      if (v.isUndefinedOrNull) return '';
      if (v.isA<JSString>()) return (v as JSString).toDart;
      return v.toString();
    }

    final apiKey = getString('apiKey');
    final projectId = getString('projectId');
    final appId = getString('appId');

    if (apiKey.isEmpty || projectId.isEmpty || appId.isEmpty) return null;

    return FirebaseOptions(
      apiKey: apiKey,
      authDomain: getString('authDomain'),
      projectId: projectId,
      storageBucket: getString('storageBucket'),
      messagingSenderId: getString('messagingSenderId'),
      appId: appId,
      measurementId: getString('measurementId'),
    );
  }
}

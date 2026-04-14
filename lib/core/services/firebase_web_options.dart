import 'package:firebase_core/firebase_core.dart';

import 'firebase_web_options_stub.dart'
    if (dart.library.js_interop) 'firebase_web_options_web.dart';

/// Web-only helper to read FirebaseOptions at runtime.
///
/// On web, this tries to read a JS object from `window.firebaseConfig`.
/// On other platforms it always returns null.
class FirebaseWebOptions {
  static FirebaseOptions? tryGetFromWindow() => FirebaseWebOptionsImpl.tryGet();
}

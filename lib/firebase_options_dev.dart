// Firebase options of the dev environment (project tsuki-tunes-dev), the
// counterpart of firebase_options.dart for the dev flavor. Android only.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DevFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDNp7eCNiDj1m8nJ1kyKIc11fb2gL6EOjc',
    appId: '1:603398005547:android:d065623248f6cf08065b6e',
    messagingSenderId: '603398005547',
    projectId: 'tsuki-tunes-dev',
    storageBucket: 'tsuki-tunes-dev.firebasestorage.app',
  );
}

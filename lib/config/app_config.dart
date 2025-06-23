import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  static FirebaseOptions get firebaseOptions {
    if (kIsWeb) {
      return webOptions;
    }
    
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidOptions;
      case TargetPlatform.iOS:
        return iosOptions;
      case TargetPlatform.macOS:
        return macosOptions;
      case TargetPlatform.windows:
        return windowsOptions;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get webOptions {
    return FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_WEB_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_WEB_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    );
  }

  static FirebaseOptions get androidOptions {
    return FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    );
  }

  static FirebaseOptions get iosOptions {
    return FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_IOS_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_IOS_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
      iosBundleId: 'com.example.webApp',
    );
  }

  static FirebaseOptions get macosOptions {
    return FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_MACOS_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_MACOS_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
      iosBundleId: 'com.example.webApp',
    );
  }

  static FirebaseOptions get windowsOptions {
    return FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_WINDOWS_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_WINDOWS_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    );
  }
  
  static String get googleSignInClientId {
    return dotenv.env['GOOGLE_SIGNIN_CLIENT_ID'] ?? '';
  }
}

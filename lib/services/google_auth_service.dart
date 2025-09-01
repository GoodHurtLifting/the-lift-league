import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // Ensure we initialize only once.
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // Supply clientId/serverClientId if you use them; safe to omit for Android.
    await GoogleSignIn.instance.initialize(
      // clientId: '<YOUR_IOS_OR_WEB_CLIENT_ID>',
      // serverClientId: '<YOUR_SERVER_CLIENT_ID>',
    );
    _initialized = true;
  }

  static Future<UserCredential?> signIn() async {
    final auth = FirebaseAuth.instance;

    if (kIsWeb) {
      try {
        final provider = GoogleAuthProvider();
        return await auth.signInWithPopup(provider);
      } catch (_) {
        return null;
      }
    } else {
      await _ensureInitialized();

      try {
        // Triggers the Google sign-in UI on platforms that support it.
        final GoogleSignInAccount? account =
        await GoogleSignIn.instance.authenticate();

        if (account == null) return null; // user cancelled

        // v7: authentication only returns ID token; access tokens are part of authorization.
        final googleAuth = account.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken, // sufficient for Firebase Auth
          // accessToken is not required here with v7
        );

        return await auth.signInWithCredential(credential);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<UserCredential?> link() async {
    final auth = FirebaseAuth.instance;

    if (kIsWeb) {
      try {
        final provider = GoogleAuthProvider();
        return await auth.currentUser?.linkWithPopup(provider);
      } catch (_) {
        return null;
      }
    } else {
      await _ensureInitialized();

      try {
        final GoogleSignInAccount? account =
        await GoogleSignIn.instance.authenticate();
        if (account == null) return null;

        final googleAuth = account.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        return await auth.currentUser?.linkWithCredential(credential);
      } catch (_) {
        return null;
      }
    }
  }
}

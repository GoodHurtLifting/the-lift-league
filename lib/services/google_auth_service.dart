import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await auth.signInWithCredential(credential);
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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await auth.currentUser?.linkWithCredential(credential);
    }
  }
}

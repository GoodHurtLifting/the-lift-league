import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'web_sign_in_dialog.dart';

/// Returns true if [error] indicates an expired or invalid auth session.
bool isAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return error.code == 'user-token-expired' ||
        error.code == 'invalid-user-token' ||
        error.code == 'user-disabled' ||
        error.code == 'requires-recent-login';
  }
  if (error is FirebaseException) {
    return error.code == 'permission-denied' || error.code == 'unauthenticated';
  }
  return false;
}

/// Signs out and prompts the user to re-authenticate if [error] was auth-related.
/// Returns `true` if the user successfully signed back in.
Future<bool> promptReAuthIfNeeded(BuildContext context, Object error) async {
  if (!isAuthError(error)) return false;
  await FirebaseAuth.instance.signOut();
  return showWebSignInDialog(context);
}

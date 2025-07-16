import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/titles_data.dart';
import '../services/google_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<bool> showWebSignInDialog(BuildContext context) async {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool loading = false;
  bool isLogin = true;
  bool success = false;

  Future<void> _createUserProfileIfNeeded(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'displayName': user.displayName ?? 'New Lifter',
        'title': getUserTitle(0),
        'blocksCompleted': 0,
        'totalLbsLifted': 0,
        'profileImageUrl': user.photoURL ?? '',
        'isAdmin': false,
      });
    }
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> handleEmail() async {
            setState(() => loading = true);
            try {
              UserCredential cred;
              if (isLogin) {
                cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: emailController.text.trim(),
                  password: passController.text.trim(),
                );
              } else {
                cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: emailController.text.trim(),
                  password: passController.text.trim(),
                );
              }
              await _createUserProfileIfNeeded(cred.user!);
              success = true;
              // Close the dialog so the home page can react to the new auth state.
              if (context.mounted) Navigator.of(context).pop(true);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
            if (context.mounted) setState(() => loading = false);
          }

          Future<void> handleGoogle() async {
            setState(() => loading = true);
            try {
              final cred = await GoogleAuthService.signIn();
              if (cred != null) {
                await _createUserProfileIfNeeded(cred.user!);
                success = true;
                // Close the dialog after a successful popup sign in.
                if (context.mounted) Navigator.of(context).pop(true);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
            if (context.mounted) setState(() => loading = false);
          }

          Future<void> handleApple() async {
            setState(() => loading = true);
            try {
              final appleCred = await SignInWithApple.getAppleIDCredential(
                scopes: [
                  AppleIDAuthorizationScopes.email,
                  AppleIDAuthorizationScopes.fullName,
                ],
              );
              final oauth = OAuthProvider('apple.com').credential(
                idToken: appleCred.identityToken,
                accessToken: appleCred.authorizationCode,
              );
              final userCred =
                  await FirebaseAuth.instance.signInWithCredential(oauth);
              await _createUserProfileIfNeeded(userCred.user!);
              success = true;
              // Close the dialog once Apple sign in succeeds.
              if (context.mounted) Navigator.of(context).pop(true);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
            if (context.mounted) setState(() => loading = false);
          }

          return AlertDialog(
            title: Text(isLogin ? 'Sign In' : 'Create Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 20),
                if (loading) const CircularProgressIndicator() else Column(
                  children: [
                    ElevatedButton(
                      onPressed: handleEmail,
                      child: Text(isLogin ? 'Sign In' : 'Create'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(isLogin ? 'Create Account' : 'Have an account?'),
                    ),
                    const Divider(),
                    ElevatedButton(
                      onPressed: handleGoogle,
                      child: const Text('Sign in with Google'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: handleApple,
                      child: const Text('Sign in with Apple'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );

  return success;
}

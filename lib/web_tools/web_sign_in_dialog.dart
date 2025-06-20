import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<bool> showWebSignInDialog(BuildContext context) async {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool loading = false;
  bool isLogin = true;
  bool success = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> handleEmail() async {
            setState(() => loading = true);
            try {
              if (isLogin) {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: emailController.text.trim(),
                  password: passController.text.trim(),
                );
              } else {
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: emailController.text.trim(),
                  password: passController.text.trim(),
                );
              }
              success = true;
              if (context.mounted) Navigator.pop(context);
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
                success = true;
                if (context.mounted) Navigator.pop(context);
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
              await FirebaseAuth.instance.signInWithCredential(oauth);
              success = true;
              if (context.mounted) Navigator.pop(context);
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
                onPressed: () => Navigator.pop(context),
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

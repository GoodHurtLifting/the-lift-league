import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:lift_league/data/titles_data.dart';
import 'user_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _navigateToDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    bool isAdmin = false;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      isAdmin = doc.data()?['isAdmin'] ?? false;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => UserDashboard(isAdmin: isAdmin)),
          (route) => false,
    );
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;

    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await _navigateToDashboard();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
    setState(() => isLoading = false);
  }

  Future<void> _signup() async {
    if (!_validateInputs()) return;

    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'displayName': 'New Lifter',
        'title': getUserTitle(0),
        'blocksCompleted': 0,
        'totalLbsLifted': 0,
        'profileImageUrl': '',
        'isAdmin': false,
      });

      await _navigateToDashboard();

    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
    setState(() => isLoading = false);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {

        setState(() => isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCred.additionalUserInfo?.isNewUser ?? false) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
          'displayName': userCred.user!.displayName ?? 'New Lifter',
          'title': getUserTitle(0),
          'blocksCompleted': 0,
          'totalLbsLifted': 0,
          'profileImageUrl': userCred.user!.photoURL ?? '',
        });
      }
      await _navigateToDashboard();

    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _signInWithApple() async {
    setState(() => isLoading = true);
    try {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );
      final userCred =
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      if (userCred.additionalUserInfo?.isNewUser ?? false) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
          'displayName': userCred.user!.displayName ?? 'New Lifter',
          'title': getUserTitle(0),
          'blocksCompleted': 0,
          'totalLbsLifted': 0,
          'profileImageUrl': '',
        });
      }
      await _navigateToDashboard();

    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    }
    setState(() => isLoading = false);
  }


  bool _validateInputs() {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _showError("Email and password cannot be empty.");
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showError("Enter your email to reset password.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent.")),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/flatLogo.jpg',
                  height: 120,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 28),
                isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                  children: [
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _signup,
                      child: const Text('Create Account'),
                    ),
                    TextButton(
                      onPressed: _resetPassword,
                      child: const Text('Forgot Password?'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _signInWithGoogle,
                      child: const Text('Sign in with Google'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _signInWithApple,
                      child: const Text('Sign in with Apple'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

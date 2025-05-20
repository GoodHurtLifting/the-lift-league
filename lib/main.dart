import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:lift_league/screens/user_dashboard.dart';
import 'package:lift_league/screens/login_screen.dart';
import 'package:lift_league/screens/add_check_in_screen.dart';
import 'package:lift_league/screens/public_profile_screen.dart';

late FirebaseAnalytics analytics;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  analytics = FirebaseAnalytics.instance;

  // ✅ Enable Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ✅ Enable App Check (debug mode for dev)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  runApp(const LiftLeagueApp());
}

class LiftLeagueApp extends StatelessWidget {
  const LiftLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The Lift League',
      theme: ThemeData.dark().copyWith(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: const FadePageTransitionsBuilder(),
            TargetPlatform.iOS: const FadePageTransitionsBuilder(),
          },
        ),
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      routes: {
        '/addCheckIn': (context) => const AddCheckInScreen(),
        '/publicProfile': (context) => PublicProfileScreen(
          userId: (ModalRoute.of(context)?.settings.arguments as Map?)?['userId'] ?? '',
        ),
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return const UserDashboard();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  final Duration duration;

  const FadePageTransitionsBuilder({this.duration = const Duration(milliseconds: 150)});

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.linear,
      ),
      child: child,
    );
  }
}




import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lift_league/web_tools/poss_home_page.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:lift_league/screens/user_dashboard.dart';
import 'package:lift_league/screens/login_screen.dart';
import 'package:lift_league/screens/add_check_in_screen.dart';
import 'package:lift_league/screens/custom_block_wizard.dart';
import 'package:lift_league/screens/public_profile_screen.dart';
import 'package:lift_league/services/notifications_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

late FirebaseAnalytics analytics;

/// Background handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM DEBUG] onBackgroundMessage: ${message.notification?.title} - ${message.notification?.body}');
  await Firebase.initializeApp();
  NotificationService().showNotification(message);
}

Future<void> setupPushNotifications() async {
  // 1. Request permission (iOS, Android 13+)
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // 2. (Optional) Get and print FCM token, and save to Firestore if logged in
  final token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $token');
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  // 3. Listen for token refresh and update Firestore
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('FCM Token refreshed: $newToken');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    }
  });


  // 4. Foreground: Show notification via NotificationService
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('FCM Foreground Message: ${message.notification?.title} - ${message.notification?.body}');
    NotificationService().showNotification(message);
  });

  // 5. App opened via notification (background/tapped)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('App opened via notification: ${message.notification?.title}');
    // Optional: handle deep linking or navigation
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  analytics = FirebaseAnalytics.instance;

  // ✅ Enable Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ✅ Enable App Check (debug mode for dev)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }
  // Set up local notifications
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await NotificationService().init();
  }

  // Set FCM presentation options — Only for mobile!
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 🔥 SETUP FCM PERMISSIONS AND LISTENERS
    await setupPushNotifications();
  }

  if (kIsWeb) {
    runApp(const POSSApp());
  } else {
    runApp(const LiftLeagueApp());
  }
}
class POSSApp extends StatelessWidget {
  const POSSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POSS Tool',
      theme: ThemeData.dark(), // or your custom theme
      home: const POSSHomePage(),
      routes: {
        '/poss': (context) => const POSSHomePage(),
      },
    );
  }
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
      builder: (context, child) {
        return SafeArea(
          top: false,
          child: child ?? const SizedBox.shrink(),
        );
      },
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      routes: {
        '/addCheckIn': (context) => const AddCheckInScreen(),
        '/customBlock': (ctx) => const CustomBlockWizard(),
        '/publicProfile': (context) => PublicProfileScreen(
          userId: (ModalRoute.of(context)?.settings.arguments as Map?)?['userId'] ?? '',
        ),
        '/poss': (context) => const POSSHomePage(),

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

  const FadePageTransitionsBuilder({this.duration = const Duration(milliseconds: 100)});

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




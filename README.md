import 'package:flutter/material.dart';
import 'screens/user_dashboard.dart';

void main() {
runApp(LiftLeagueApp());
}

class LiftLeagueApp extends StatelessWidget {
@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'The Lift League',
theme: ThemeData.dark(), // Dark theme
home: UserDashboard(),
);
}
}

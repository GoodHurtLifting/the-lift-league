import 'package:flutter/material.dart';

class CaloriesChart extends StatelessWidget {
  final String userId;
  const CaloriesChart({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      color: Colors.orangeAccent.withOpacity(0.2),
      alignment: Alignment.center,
      child: const Text('Calories Chart'),
    );
  }
}

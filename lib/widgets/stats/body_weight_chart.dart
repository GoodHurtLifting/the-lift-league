import 'package:flutter/material.dart';

class BodyWeightChart extends StatelessWidget {
  final String userId;
  const BodyWeightChart({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      color: Colors.lightBlueAccent.withOpacity(0.2),
      alignment: Alignment.center,
      child: const Text('Body Weight Chart'),
    );
  }
}

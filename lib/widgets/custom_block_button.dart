import 'package:flutter/material.dart';

class CustomBlockButton extends StatelessWidget {
  const CustomBlockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFC3B3D),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 28,
        icon: Stack(
          alignment: Alignment.center,
          children: const [
            Icon(Icons.fitness_center, color: Colors.white),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.add, size: 12, color: Colors.white),
            ),
          ],
        ),
        onPressed: () => Navigator.pushNamed(context, '/customBlock'),
      ),
    );
  }
}
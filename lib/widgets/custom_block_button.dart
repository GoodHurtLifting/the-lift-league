import 'package:flutter/material.dart';

class CustomBlockButton extends StatelessWidget {
  final VoidCallback? onReturn;

  const CustomBlockButton({super.key, this.onReturn});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.library_add, color: Colors.white, size: 28),
      tooltip: 'Build Your Own Block',
      onPressed: () async {
        await Navigator.pushNamed(context, '/customBlock');
        if (onReturn != null) onReturn!();
      },
    );
  }
}
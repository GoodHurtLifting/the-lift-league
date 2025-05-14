import 'package:flutter/material.dart';
import 'package:lift_league/modals/calculator_modal.dart';

class WorkoutHeader extends StatelessWidget {
  final String blockName;
  final String workoutName;
  final VoidCallback onBack;
  final VoidCallback onHome;

  const WorkoutHeader({
    super.key,
    required this.blockName,
    required this.workoutName,
    required this.onBack,
    required this.onHome,
  });

  void _showCalculatorModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Calculator',
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.black,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CalculatorModal(),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  blockName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  workoutName,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.calculate),
              onPressed: () => _showCalculatorModal(context),
            ),
          ],
        ),
      ),
    );
  }
}

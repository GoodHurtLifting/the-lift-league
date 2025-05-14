// rest_timer.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';

class RestTimer extends StatefulWidget {
  const RestTimer({super.key});

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  int _remainingSeconds = 0;
  Timer? _timer;
  int _lastUsedDuration = 60; // Default initial value

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = seconds;
      _lastUsedDuration = seconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        Vibration.hasVibrator().then((hasVibrator) {
          if(hasVibrator ?? false) {
            Vibration.vibrate(duration: 500);
          }
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  Widget _presetButton(int seconds, String label) {
    return TextButton(
      onPressed: () => _startTimer(seconds),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                if (_lastUsedDuration > 0) _startTimer(_lastUsedDuration);
              },
              icon: const Icon(Icons.refresh),
              color: Colors.green,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(), // remove built-in size
              visualDensity: VisualDensity.compact, // remove vertical space
              tooltip: 'Restart Last Timer',
            ),
            const SizedBox(width: 6),
            Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                fontFamily: 'Digital',
                fontSize: 24,
                letterSpacing: 2,
                color: _remainingSeconds == 0 ? Colors.red : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _presetButton(30, '30s'),
            const SizedBox(width: 4),
            _presetButton(60, '60s'),
            const SizedBox(width: 4),
            _presetButton(90, '90s'),
            const SizedBox(width: 4),
            _presetButton(120, '2m'),
          ],
        ),
      ],
    );
  }

}

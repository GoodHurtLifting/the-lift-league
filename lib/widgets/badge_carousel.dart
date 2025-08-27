// badge_carousel.dart
import 'package:flutter/material.dart';
import '../services/badge_service.dart';
import '../widgets/badge_carousel.dart'; // adjust path if different


class BadgeCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> earnedBadges;
  final VoidCallback onComplete;

  const BadgeCarousel({
    super.key,
    required this.earnedBadges,
    required this.onComplete,
  });

  @override
  State<BadgeCarousel> createState() => _BadgeCarouselState();
}

class _BadgeCarouselState extends State<BadgeCarousel> {
  int currentIndex = 0;

  void _nextBadge() {
    if (currentIndex < widget.earnedBadges.length - 1) {
      setState(() => currentIndex++);
    } else {
      Navigator.of(context).pop(); // Close the overlay
      widget.onComplete(); // Resume workout flow
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.earnedBadges[currentIndex];
    return GestureDetector(
      onTap: _nextBadge,
      child: Container(
        color: const Color.fromARGB(242, 0, 0, 0), // ~95% opacity black
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final flipAnimation = Tween(begin: 1.0, end: 0.0).animate(animation);
                return AnimatedBuilder(
                  animation: flipAnimation,
                  child: child,
                  builder: (context, child) {
                    final isUnder = (flipAnimation.value < 0.5);
                    final tilt = (1 - flipAnimation.value) * 3.14; // radians

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(isUnder ? 3.14 - tilt : tilt),
                      child: child,
                    );
                  },
                );
              },
              child: Image.asset(
                'assets/images/badges/${badge['image'] ?? 'badge_default.png'}',
                key: ValueKey<String>(badge['badgeId'] ?? ''),
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.width * 0.95,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                badge['name'],
                key: ValueKey('name_${badge['badgeId']}'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                badge['description'],
                key: ValueKey('desc_${badge['badgeId']}'),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

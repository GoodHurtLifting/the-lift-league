import 'package:flutter/material.dart';

class BadgeGrid extends StatelessWidget {
  final List<String> imagePaths;

  const BadgeGrid({super.key, required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    final hasMultipleBadges = imagePaths.length > 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: imagePaths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        return _AnimatedBadgeTile(
          imagePath: imagePaths[index],
          delay: hasMultipleBadges ? Duration(milliseconds: index * 100) : Duration.zero,
        );
      },
    );
  }
}

class _AnimatedBadgeTile extends StatefulWidget {
  final String imagePath;
  final Duration delay;

  const _AnimatedBadgeTile({
    required this.imagePath,
    required this.delay,
  });

  @override
  State<_AnimatedBadgeTile> createState() => _AnimatedBadgeTileState();
}

class _AnimatedBadgeTileState extends State<_AnimatedBadgeTile> with SingleTickerProviderStateMixin {
  double opacity = 0.0;
  double scale = 0.8;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          opacity = 1.0;
          scale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Image.asset(widget.imagePath, width: 60, height: 60),
        ),
      ),
    );
  }
}

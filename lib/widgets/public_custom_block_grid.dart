import 'package:flutter/material.dart';

class PublicCustomBlockGrid extends StatelessWidget {
  final List<String> images;
  final List<String> names;
  final void Function(int index) onAdd;

  const PublicCustomBlockGrid({
    super.key,
    required this.images,
    required this.names,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onAdd(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Positioned.fill(
                  child: images[index].startsWith('http')
                      ? Image.network(images[index], fit: BoxFit.cover)
                      : Image.asset(images[index], fit: BoxFit.cover),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black54,
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      names[index],
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
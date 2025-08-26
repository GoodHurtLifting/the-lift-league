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
    if (images.isEmpty || names.isEmpty) return const SizedBox.shrink();

    // Guard against list length mismatch to avoid range errors.
    assert(
    images.length == names.length,
    'PublicCustomBlockGrid: images and names must be same length',
    );
    final count = images.length;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        final img = images[index];
        final name = names[index];

        Widget imageWidget;
        if (img.startsWith('http')) {
          imageWidget = Image.network(
            img,
            fit: BoxFit.cover,
            // Smooth loading & a safe fallback if the URL fails
            loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (ctx, error, stack) =>
                Image.asset('assets/logo25.jpg', fit: BoxFit.cover),
          );
        } else {
          imageWidget = Image.asset(img, fit: BoxFit.cover);
        }

        return Material(
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onAdd(index),
            child: Stack(
              children: [
                Positioned.fill(child: imageWidget),
                // Name bar with ellipsis
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
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
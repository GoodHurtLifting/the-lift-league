import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lift_league/services/db_service.dart';

class CustomBlocksScreen extends StatefulWidget {
  final VoidCallback onCreateNew;
  const CustomBlocksScreen({super.key, required this.onCreateNew});

  @override
  State<CustomBlocksScreen> createState() => _CustomBlocksScreenState();
}

class _CustomBlocksScreenState extends State<CustomBlocksScreen> {
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    final blocks = await DBService().getCustomBlocks(includeDrafts: true);
    setState(() {
      _blocks = blocks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_blocks.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: widget.onCreateNew,
          child: const Text('Create Your First Block'),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: _blocks.length,
            itemBuilder: (context, index) {
              final b = _blocks[index];
              final path = b['coverImagePath']?.toString() ?? 'assets/logo25.jpg';
              final Widget imageWidget;
              if (path.startsWith('assets/')) {
                imageWidget = Image.asset(path, fit: BoxFit.cover);
              } else {
                imageWidget = Image.file(File(path), fit: BoxFit.cover);
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(child: imageWidget),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(4),
                        width: double.infinity,
                        child: Text(
                          b['name'] as String? ?? '',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: widget.onCreateNew,
          child: const Text('Create Block'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

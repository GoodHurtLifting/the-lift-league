import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'web_custom_block_service.dart';
import 'auth_utils.dart';
import 'package:firebase_core/firebase_core.dart';

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
    try {
      final blocks = await WebCustomBlockService().getCustomBlocks();
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _loading = false;
      });
    } on FirebaseException catch (e) {
      final reauthed = await promptReAuthIfNeeded(context, e);
      if (reauthed) {
        await _loadBlocks();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    }
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
              // Blocks saved from the web builder store the cover image under
              // `coverImageUrl` while legacy blocks might use `coverImagePath`.
              final path = b['coverImagePath']?.toString() ??
                  b['coverImageUrl']?.toString() ?? 'assets/logo25.jpg';
              final Widget imageWidget;
              if (path.startsWith('assets/')) {
                imageWidget = Image.asset(path, fit: BoxFit.cover);
              } else {
                imageWidget = Image.network(path, fit: BoxFit.cover);
              }
              return InkWell(
                onTap: () {
                  final id = b["id"].toString();
                  context.go('/custom-blocks/$id');
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(child: imageWidget),
                      if (b['isDraft'] == true)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: const Text(
                              'DRAFT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(4),
                          width: double.infinity,
                          child: Text(
                            b['isDraft'] == true
                                ? '${b['name']} (draft)'
                                : b['name'] as String? ?? '',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
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

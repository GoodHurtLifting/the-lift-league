import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/custom_block_models.dart';
import 'web_custom_block_service.dart';
import 'web_block_dashboard.dart';

class WebBlockPage extends StatefulWidget {
  final String blockId;
  const WebBlockPage({super.key, required this.blockId});

  @override
  State<WebBlockPage> createState() => _WebBlockPageState();
}

class _WebBlockPageState extends State<WebBlockPage> {
  CustomBlock? _block;
  bool _loading = true;
  FirebaseException? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('[DEBUG] WebBlockPage → blockId = ${widget.blockId}');
    _load();
  }

  Future<void> _load() async {
    try {
      final block = await WebCustomBlockService()
          .getCustomBlockById(widget.blockId);
      if (!mounted) return;
      setState(() {
        _block = block;
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_block == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error?.message ?? 'Block not found'),
        ),
      );
    }

    return WebBlockDashboard(block: _block!);
  }
}

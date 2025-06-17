import 'package:flutter/material.dart';
import 'about_screen.dart';
import 'custom_blocks_screen.dart';
import 'poss_block_builder.dart';
import '../services/db_service.dart';
import '../services/promo_popup_service.dart';

const Color _lightGrey = Color(0xFFD0D0D0);

class POSSHomePage extends StatefulWidget {
  const POSSHomePage({super.key});

  @override
  State<POSSHomePage> createState() => _POSSHomePageState();
}

class _POSSHomePageState extends State<POSSHomePage> {
  bool _showGrid = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkBlocks();
  }

  Future<void> _checkBlocks() async {
    try {
      final blocks = await DBService().getCustomBlocks();
      setState(() {
        _showGrid = blocks.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSaved() {
    _checkBlocks();
    PromoPopupService().showPromoDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_showGrid) {
      body = CustomBlocksScreen(onCreateNew: () {
        setState(() => _showGrid = false);
      });
    } else {
      body = const Center(
        child: Text(
          'There are no saved blocks yet',
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      );
    }

    return DefaultTextStyle(
      style: const TextStyle(color: _lightGrey),
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: _lightGrey,
          centerTitle: true,

          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                'Progressive Overload Scoring System',
                textAlign: TextAlign.center,
                softWrap: true,
              ),
              Text(
                'Build Workouts • Stay Motivated\n Get Feedback',
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.black54),
                child: Text('Menu'),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _showGrid = true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Block Builder'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => POSSBlockBuilder(onSaved: _onSaved)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
*/
/*
import '../../services/health/fitbit_provider.dart';
*//*


class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});

  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  final _storage = const FlutterSecureStorage();
  final _fitbitProvider = FitbitProvider();

  bool _fitbit = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final fitbit = await _storage.read(key: FitbitProvider.connectedKey);

    setState(() {
      _fitbit = fitbit == 'true';
    });
  }

  Future<void> _toggleFitbit(bool value) async {
    if (value) {
      final ok = await _fitbitProvider.authorize();
      if (!ok) return;
    } else {
      await _fitbitProvider.disconnect();
    }
    setState(() => _fitbit = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Apps'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: ListView(
        children: [
          SwitchListTile(
            activeColor: Colors.green,
            title: const Text('Fitbit', style: TextStyle(color: Colors.white)),
            value: _fitbit,
            onChanged: _toggleFitbit,
          ),
        ],
      ),
    );
  }
}
*/

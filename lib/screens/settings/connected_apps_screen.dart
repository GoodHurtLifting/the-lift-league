import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/health/apple_health_provider_stub.dart'
    if (dart.library.io) '../../services/health/apple_health_provider.dart';
import '../../services/health/google_fit_provider_stub.dart'
    if (dart.library.io) '../../services/health/google_fit_provider.dart';
import '../../services/health/fitbit_provider.dart';

class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});

  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  final _storage = const FlutterSecureStorage();
  final _appleProvider = AppleHealthProvider();
  final _googleProvider = GoogleFitProvider();
  final _fitbitProvider = FitbitProvider();

  bool _apple = false;
  bool _google = false;
  bool _fitbit = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final apple = await _storage.read(key: AppleHealthProvider.connectedKey);
    final google = await _storage.read(key: GoogleFitProvider.connectedKey);
    final fitbit = await _storage.read(key: FitbitProvider.connectedKey);

    setState(() {
      _apple = apple == 'true';
      _google = google == 'true';
      _fitbit = fitbit == 'true';
    });
  }

  Future<void> _toggleApple(bool value) async {
    if (value) {
      final granted = await _appleProvider.requestAuthorization();
      if (!granted) return;
    } else {
      await _appleProvider.disconnect();
    }
    setState(() => _apple = value);
  }

  Future<void> _toggleGoogle(bool value) async {
    if (value) {
      final granted = await _googleProvider.requestAuthorization();
      if (!granted) return;
    } else {
      await _googleProvider.disconnect();
    }
    setState(() => _google = value);
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
            title: const Text('Apple Health', style: TextStyle(color: Colors.white)),
            value: _apple,
            onChanged: _toggleApple,
          ),
          SwitchListTile(
            activeColor: Colors.green,
            title: const Text('Google Fit', style: TextStyle(color: Colors.white)),
            value: _google,
            onChanged: _toggleGoogle,
          ),
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

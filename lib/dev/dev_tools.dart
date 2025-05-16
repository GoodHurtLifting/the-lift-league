import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/screens/user_dashboard.dart';

const bool devToolsEnabled = bool.fromEnvironment('DEV_TOOLS_ENABLED');

class DevTools extends StatelessWidget {
  const DevTools({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !devToolsEnabled) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.bug_report, color: Colors.red, size: 28),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("⚠️ Reset Local Database"),
            content: const Text("This will wipe all local data. Continue?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
            ],
          ),
        );

        if (confirm == true) {
          await DBService().resetDevDatabase();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserDashboard()),
          );
        }
      },
    );
  }
}

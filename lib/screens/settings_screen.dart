import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'package:lift_league/services/title_observer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool showStats = true;
  bool showTimeline = true;
  bool showCheckInInfo = true;
  bool isLoading = true;
  bool notifyMessages = true;
  bool notifyTrainingCircle = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacyAndNotificationSettings();
  }

  Future<void> _loadPrivacyAndNotificationSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();

    if (data != null) {
      final notif = Map<String, dynamic>.from(data['notificationPrefs'] ?? {});
      setState(() {
        showStats = data['showStats'] ?? true;
        showTimeline = data['showTimeline'] ?? true;
        showCheckInInfo = data['showCheckInInfo'] ?? true;
        // notificationPrefs with defaults
        notifyMessages = notif['messages'] ?? true;
        notifyTrainingCircle = notif['trainingCircle'] ?? true;
        isLoading = false;
      });
    }
  }

  Future<void> _updatePrivacy(String field, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      field: value,
    });

    final labelMap = {
      'showStats': 'Show Stats',
      'showTimeline': 'Show Timeline',
      'showCheckInInfo': 'Check-In Info',
    };

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${labelMap[field]} updated')),
    );
  }

  Future<void> _updateNotificationPref(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      if (key == 'messages') notifyMessages = value;
      if (key == 'trainingCircle') notifyTrainingCircle = value;
    });
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationPrefs': {
        key: value,
      }
    }, SetOptions(merge: true));
    final labelMap = {
      'messages': 'Message notifications',
      'trainingCircle': 'Training Circle notifications',
    };
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${labelMap[key]} updated')),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      TitleObserverService.stopObserving(); // 🔥 stop listening first
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text('Account', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Navigate to account settings page
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.notifications, color: Colors.white),
            title: const Text('Notifications', style: TextStyle(color: Colors.white)),
            collapsedIconColor: Colors.white,
            iconColor: Colors.green,
            childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            children: [
              SwitchListTile(
                activeColor: Colors.green,
                title: const Text('New Messages', style: TextStyle(color: Colors.white)),
                value: notifyMessages,
                onChanged: (val) => _updateNotificationPref('messages', val),
              ),
              SwitchListTile(
                activeColor: Colors.green,
                title: const Text('Training Circle Updates', style: TextStyle(color: Colors.white)),
                value: notifyTrainingCircle,
                onChanged: (val) => _updateNotificationPref('trainingCircle', val),
              ),
            ],
          ),
          const Divider(color: Colors.white54),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              'Public Profile Settings',
              style: TextStyle(color: Colors.grey[300], fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            activeColor: Colors.green,
            title: const Text('Show Stats', style: TextStyle(color: Colors.white)),
            value: showStats,
            onChanged: (val) {
              setState(() => showStats = val);
              _updatePrivacy('showStats', val);
            },
          ),
          SwitchListTile(
            activeColor: Colors.green,
            title: const Text('Show Check-In Timeline', style: TextStyle(color: Colors.white)),
            value: showTimeline,
            onChanged: (val) {
              setState(() => showTimeline = val);
              _updatePrivacy('showTimeline', val);
            },
          ),
          SwitchListTile(
            activeColor: Colors.green,
            title: const Text('Show Check-In Stats', style: TextStyle(color: Colors.white)),
            value: showCheckInInfo,
            onChanged: (val) {
              setState(() => showCheckInInfo = val);
              _updatePrivacy('showCheckInInfo', val);
            },
          ),
          const Divider(color: Colors.white54),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Log Out', style: TextStyle(color: Colors.white)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
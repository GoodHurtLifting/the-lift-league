import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'package:lift_league/services/title_observer_service.dart';
import '../services/google_auth_service.dart';


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
  bool notifyFollow = true;
  bool notifyCircleAdd = true;
  bool playRestSound = true;
  bool googleLinked = false;
  bool appleLinked = false;

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

    final providers = FirebaseAuth.instance.currentUser?.providerData ?? [];
    setState(() {
      googleLinked = providers.any((p) => p.providerId == 'google.com');
      appleLinked = providers.any((p) => p.providerId == 'apple.com');
    });

    if (data != null) {
      final notif = Map<String, dynamic>.from(data['notificationPrefs'] ?? {});
      setState(() {
        showStats = data['showStats'] ?? true;
        showTimeline = data['showTimeline'] ?? true;
        showCheckInInfo = data['showCheckInInfo'] ?? true;
        // notificationPrefs with defaults
        notifyMessages = notif['messages'] ?? true;
        notifyTrainingCircle = notif['trainingCircle'] ?? true;
        notifyFollow = notif['follow'] ?? true;
        notifyCircleAdd = notif['trainingCircleAdd'] ?? true;
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

  Future<void> _updateAllCheckInsPublic(bool isPublic) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('timeline_entries')
        .where('type', isEqualTo: 'checkin')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'public': isPublic});
    }

    await batch.commit();
  }

  Future<void> _updateRestSoundPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('playRestSound', value);
    setState(() => playRestSound = value);
  }

  Future<void> _updateNotificationPref(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      if (key == 'messages') notifyMessages = value;
      if (key == 'trainingCircle') notifyTrainingCircle = value;
      if (key == 'follow') notifyFollow = value;
      if (key == 'trainingCircleAdd') notifyCircleAdd = value;
    });
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationPrefs': {
        key: value,
      }
    }, SetOptions(merge: true));
    final labelMap = {
      'messages': 'Message notifications',
      'trainingCircle': 'Training Circle notifications',
      'follow': 'Follower notifications',
      'trainingCircleAdd': 'Training Circle Add notifications',
    };
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${labelMap[key]} updated')),
    );
  }

  Future<void> _changePassword(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating password: $e')),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final newPassController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Change Password', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPass = newPassController.text.trim();
                final confirm = confirmController.text.trim();
                if (newPass.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill out both fields')),
                  );
                  return;
                }
                if (newPass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                Navigator.pop(context);
                _changePassword(newPass);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
  Future<void> _linkWithGoogle() async {
    try {
      final userCred = await GoogleAuthService.link();
      if (userCred != null) {
        setState(() => googleLinked = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google account linked')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error linking Google: $e')),
      );
    }
  }

  Future<void> _linkWithApple() async {
    try {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );
      await FirebaseAuth.instance.currentUser?.linkWithCredential(oauth);
      setState(() => appleLinked = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple account linked')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error linking Apple: $e')),
      );
    }
  }

  Future<void> _unlinkProvider(String providerId) async {
    try {
      await FirebaseAuth.instance.currentUser?.unlink(providerId);
      setState(() {
        if (providerId == 'google.com') googleLinked = false;
        if (providerId == 'apple.com') appleLinked = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account unlinked')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unlinking account: $e')),
      );
    }
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
          ExpansionTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text('Account', style: TextStyle(color: Colors.white)),
            collapsedIconColor: Colors.white,
            iconColor: Colors.green,
            children: [
              ListTile(
                leading: const Icon(Icons.lock, color: Colors.white),
                title:
                const Text('Change Password', style: TextStyle(color: Colors.white)),
                onTap: _showChangePasswordDialog,
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.white),
                title: Text(
                  googleLinked ? 'Unlink Google' : 'Link Google',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: googleLinked
                    ? () => _unlinkProvider('google.com')
                    : _linkWithGoogle,
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.white),
                title: Text(
                  appleLinked ? 'Unlink Apple' : 'Link Apple',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap:
                appleLinked ? () => _unlinkProvider('apple.com') : _linkWithApple,
              ),
            ],
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
              SwitchListTile(
                activeColor: Colors.green,
                title: const Text('New Followers', style: TextStyle(color: Colors.white)),
                value: notifyFollow,
                onChanged: (val) => _updateNotificationPref('follow', val),
              ),
              SwitchListTile(
                activeColor: Colors.green,
                title: const Text('Added to Training Circle', style: TextStyle(color: Colors.white)),
                value: notifyCircleAdd,
                onChanged: (val) => _updateNotificationPref('trainingCircleAdd', val),
              ),
              SwitchListTile(
                activeColor: Colors.green,
                title: const Text('Rest Timer Sound', style: TextStyle(color: Colors.white)),
                value: playRestSound,
                onChanged: (val) => _updateRestSoundPref(val),
              ),
            ],
          ),
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
              _updateAllCheckInsPublic(val);
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
  }}
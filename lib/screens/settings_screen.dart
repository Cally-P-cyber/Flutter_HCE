import 'package:flutter/material.dart';
import 'package:nfc_emulator/services/setting_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SettingsScreen({Key? key, required this.onToggleTheme})
      : super(key: key);
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _pref; // null=system, true=dark, false=light

  @override
  void initState() {
    super.initState();
    SettingsService.getDarkModePreference().then((v) {
      setState(() => _pref = v);
    });
  }

  void _cycleTheme() {
    final next = _pref == null ? false : (_pref == false ? true : null);
    SettingsService.setDarkModePreference(next);
    setState(() => _pref = next);
    widget.onToggleTheme();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext c) {
    final texts = ['System Default', 'Light Mode', 'Dark Mode'];
    final idx = _pref == null ? 0 : (_pref! ? 2 : 1);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        ListTile(
          title: const Text('Theme'),
          subtitle: Text(texts[idx]),
          trailing: IconButton(
              icon: Icon(idx == 0
                  ? Icons.settings_brightness
                  : idx == 1
                      ? Icons.light_mode
                      : Icons.dark_mode),
              onPressed: _cycleTheme),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign Out'),
          onTap: _signOut,
        ),
      ]),
    );
  }
}

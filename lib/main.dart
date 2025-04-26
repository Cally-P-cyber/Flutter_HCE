// … earlier imports …
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/nfc_service.dart';
import 'services/setting_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NfcService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _darkPref;

  @override
  void initState() {
    super.initState();
    SettingsService.getDarkModePreference().then((pref) {
      setState(() => _darkPref = pref);
    });
  }

  void _toggleTheme() {
    // reload saved preference after user changes it
    SettingsService.getDarkModePreference().then((pref) {
      setState(() => _darkPref = pref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color.fromARGB(255, 11, 218, 81);
    return MaterialApp(
      title: 'NFC Tag Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _darkPref == null
          ? ThemeMode.system
          : (_darkPref! ? ThemeMode.dark : ThemeMode.light),
      home: StreamBuilder<User?>(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          // 1) Still loading auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          // 2) User is logged in
          if (snapshot.hasData) {
            return HomeScreen(onToggleTheme: _toggleTheme);
          }
          // 3) No user: show login
          return LoginScreen();
        },
      ),
    );
  }
}

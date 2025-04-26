import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<User?> signIn(String email, String password) async {
    final creds = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return creds.user;
  }

  static Future<User?> register(String email, String password) async {
    final creds = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    return creds.user;
  }

  static Future<void> signOut() => _auth.signOut();
}

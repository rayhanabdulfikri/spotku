import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // pengguna membatalkan proses login
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      // AuthGate di main.dart akan otomatis pindah ke HomeScreen
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal masuk: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_rounded, size: 96, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                'SpotKu',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Diari Perjalanan & Kenanganmu',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('Masuk dengan Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

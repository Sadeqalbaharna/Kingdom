import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
// ...existing code...
import '../auth_service.dart';

class GoogleSignInScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  const GoogleSignInScreen({super.key, required this.onSignedIn});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _emailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await _authEmailPassword(email, password);
      widget.onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authEmailPassword(String email, String password) async {
    // Directly use FirebaseAuth for email/password login
    await AuthService().signInWithEmailPassword(email, password);
  }
  final _auth = AuthService();
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Try silent sign-in for web, fallback to signIn for both platforms
      bool isWeb = identical(0, 0.0);
      if (isWeb) {
        final googleSignIn = GoogleSignIn();
        final user = await googleSignIn.signInSilently();
        if (user != null) {
          await _auth.signInWithGoogle(silent: true);
          widget.onSignedIn();
          return;
        }
      }
      await _auth.signInWithGoogle();
      widget.onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 390,
        height: 844,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Welcome to Kingdom', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _go,
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(labelText: 'Password'),
                              obscureText: true,
                              validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _busy ? null : _emailLogin,
                              child: const Text('Login with Email'),
                            ),
                          ],
                        ),
                      ),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12.0),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

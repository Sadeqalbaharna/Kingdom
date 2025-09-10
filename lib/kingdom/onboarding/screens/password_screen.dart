import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';

class PasswordScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PasswordScreen({super.key, required this.onComplete});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        setState(() => _error = 'No user is currently signed in.');
        return;
      }
      final providers = await FirebaseAuth.instance.fetchSignInMethodsForEmail(user.email!);
      if (providers.contains('password')) {
        await user.updatePassword(_pwd.text);
        widget.onComplete();
        return;
      }
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _pwd.text,
        );
        await user.linkWithCredential(credential);
        widget.onComplete();
      } catch (e) {
        // If provider already linked, treat as success and continue
        if (e.toString().contains('provider-already-linked')) {
          await user.updatePassword(_pwd.text);
          widget.onComplete();
        } else {
          setState(() => _error = e.toString());
        }
      }
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
            appBar: AppBar(title: const Text('Set Password')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Set a password for email login (optional).'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pwd,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars',
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _busy ? null : _save,
                        child: const Text('Continue'),
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

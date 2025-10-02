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

  @override
  void initState() {
    super.initState();
    // After first frame, reload and check providerData to avoid stale state on web.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await user.reload();
        await Future.delayed(const Duration(milliseconds: 50));
        final refreshed = FirebaseAuth.instance.currentUser;
        final hasPasswordProvider = refreshed?.providerData.any((p) => p.providerId == 'password') ?? false;
        if (hasPasswordProvider && mounted) {
          widget.onComplete();
          Navigator.of(context).maybePop();
        }
      } catch (_) {}
    });
  }

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
      // Prefer providerData over deprecated fetchSignInMethodsForEmail.
      final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
      if (hasPasswordProvider) {
        // User already linked with password; just update to the new one.
        await user.updatePassword(_pwd.text);
        try { widget.onComplete(); } catch (_) {}
        if (mounted) {
          Navigator.of(context).maybePop(true);
        }
        return;
      }
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _pwd.text,
        );
        await user.linkWithCredential(credential);
        try { widget.onComplete(); } catch (_) {}
        if (mounted) {
          Navigator.of(context).maybePop(true);
        }
      } catch (e) {
        // If provider already linked, treat as success and continue
        if (e.toString().contains('provider-already-linked')) {
          await user.updatePassword(_pwd.text);
          try { widget.onComplete(); } catch (_) {}
          if (mounted) {
            Navigator.of(context).maybePop(true);
          }
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

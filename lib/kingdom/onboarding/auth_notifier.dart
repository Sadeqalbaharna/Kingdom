import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthNotifier extends ChangeNotifier {
  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final wasLoggedIn = _loggedIn;
      _loggedIn = user != null;
      if (_loggedIn != wasLoggedIn) notifyListeners();
    });
  }

  void forceNotify() => notifyListeners();
}

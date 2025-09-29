import 'package:flutter/material.dart';
import 'package:turn_page_transition/turn_page_transition.dart';

class NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget page;
  const NavButton({required this.label, required this.icon, required this.page, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      onPressed: () {
        Navigator.of(context).push(
          TurnPageRoute(
            overleafColor: Colors.white,
            transitionDuration: const Duration(milliseconds: 700),
            builder: (_) => page,
          ),
        );
      },
    );
  }
}
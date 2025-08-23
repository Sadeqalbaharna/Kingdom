import 'package:flutter/widgets.dart';

class HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(0.25 * w, 0.067 * h)
      ..lineTo(0.75 * w, 0.067 * h)
      ..lineTo(1.0 * w, 0.50 * h)
      ..lineTo(0.75 * w, 0.933 * h)
      ..lineTo(0.25 * w, 0.933 * h)
      ..lineTo(0.00 * w, 0.50 * h)
      ..close();
    return p;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

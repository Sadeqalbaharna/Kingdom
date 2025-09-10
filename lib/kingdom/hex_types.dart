import 'dart:math' as math;
import 'package:flutter/material.dart';

class Axial {
  final int x; // q
  final int y; // r
  const Axial(this.x, this.y);

  int get q => x;
  int get r => y;

  @override
  bool operator ==(Object o) => o is Axial && o.x == x && o.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => '($x,$y)';
  static Axial parse(String key) {
    final sp = key.split(',');
    return Axial(int.parse(sp[0]), int.parse(sp[1]));
  }
}

/// pixel -> axial (rounded), inverse of [axialToPixel]
Axial pixelToAxial(Offset p, Size size, double tileSize) {
  final r = tileSize;
  final dx = p.dx - size.width / 2;
  final dy = p.dy - size.height / 2;

  final qf = (2.0 / 3.0) * dx / r;
  final rf = (-1.0 / 3.0) * dx / r + (1.0 / math.sqrt(3)) * dy / r;

  // cube rounding
  final xf = qf;
  final zf = rf;
  final yf = -xf - zf;

  int rx = xf.round();
  int ry = yf.round();
  int rz = zf.round();

  final dxr = (rx - xf).abs();
  final dyr = (ry - yf).abs();
  final dzr = (rz - zf).abs();

  if (dxr > dyr && dxr > dzr) {
    rx = -ry - rz;
  } else if (dyr > dzr) {
    ry = -rx - rz;
  } else {
    rz = -rx - ry;
  }
  return Axial(rx, rz); // axial (q==x, r==z)
}

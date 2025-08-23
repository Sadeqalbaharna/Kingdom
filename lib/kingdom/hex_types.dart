class Axial {
  final int q, r;
  const Axial(this.q, this.r);
  @override
  bool operator ==(Object o) => o is Axial && o.q == q && o.r == r;
  @override
  int get hashCode => Object.hash(q, r);
  @override
  String toString() => '$q,$r';
  static Axial parse(String key) {
    final sp = key.split(',');
    return Axial(int.parse(sp[0]), int.parse(sp[1]));
  }
}

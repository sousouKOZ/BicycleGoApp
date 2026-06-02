void main() {
  var t1 = DateTime.parse('2026-05-28T10:50:00');
  var t2 = DateTime.parse('2026-05-28T10:50:00+00:00');
  var t3 = DateTime.parse('2026-05-28T10:50:00Z');
  print('t1: $t1 (isUtc: ${t1.isUtc})');
  print('t2: $t2 (isUtc: ${t2.isUtc})');
  print('t3: $t3 (isUtc: ${t3.isUtc})');
  print('now: ${DateTime.now()} (isUtc: ${DateTime.now().isUtc})');
}

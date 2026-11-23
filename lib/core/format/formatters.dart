/// "350 m" under a kilometre, then kilometres to one place without a
/// trailing zero: "1.1 km", "2 km".
String formatDistance(int metres) {
  if (metres < 1000) return '$metres m';
  final String km = (metres / 1000).toStringAsFixed(1);
  return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} km';
}

/// Whole numbers with a thousands separator: 5420 as "5,420".
String formatCount(int n) {
  final String digits = n.abs().toString();
  final StringBuffer out = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Locale-free number formatting shared by the number surfaces.
library;

/// Groups [digits] (an unsigned integer string) into thousands with commas,
/// matching the source's `toLocaleString()` default on a server.
String beuiGroupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

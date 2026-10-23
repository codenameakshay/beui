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

/// Shortens a long address to `0x1234…cdef` (6 leading + 4 trailing chars),
/// matching the wallet-card source's `truncateAddress`. Addresses of 12
/// characters or fewer are returned unchanged.
String beuiTruncateAddress(String address) {
  if (address.length > 12) {
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
  return address;
}

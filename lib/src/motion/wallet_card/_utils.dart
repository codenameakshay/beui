// Port of the source's `utils.ts` helpers (the DiceBear URL builder is dropped
// — the Flutter port generates avatars locally instead of hitting the network,
// see `account_avatar.dart`).

/// Shortens a long address to `0x1234…cdef`, matching the source
/// `truncateAddress`.
String truncateAddress(String address) {
  if (address.length > 12) {
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
  return address;
}

/// A short code for a game hosted on the local network, for friends to type
/// in to join: the host's IPv4 address, written in Crockford's base 32 as
/// 7 characters split 3–4, such as `K7Q-2XB4`.
///
/// Crockford's alphabet leaves out I, L, O and U, so a code can't be
/// misread, and reading one back forgives the usual slips: lower case, no
/// dash, O for zero, I or L for one. The port is always [hostPort], so it
/// isn't part of the code.
library;

/// The port every host listens on.
const hostPort = 47123;

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// The code for the host at [address], such as `192.168.1.23`.
String roomCodeFor(String address) {
  final parts = address.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
    throw ArgumentError.value(address, 'address', 'is not an IPv4 address');
  }
  var value = parts.fold(0, (sum, part) => sum * 256 + part!);
  final digits = List.filled(7, '0');
  for (var i = 6; i >= 0; i--) {
    digits[i] = _alphabet[value % 32];
    value ~/= 32;
  }
  final code = digits.join();
  return '${code.substring(0, 3)}-${code.substring(3)}';
}

/// The host address in [code], or `null` if it isn't a room code.
String? addressFromRoomCode(String code) {
  final cleaned = code
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  if (cleaned.length != 7) return null;
  var value = 0;
  for (final char in cleaned.split('')) {
    final digit = _alphabet.indexOf(char);
    if (digit < 0) return null;
    value = value * 32 + digit;
  }
  // 7 digits hold 35 bits; an address needs only 32.
  if (value >= 1 << 32) return null;
  return [
    for (var shift = 24; shift >= 0; shift -= 8) (value >> shift) & 0xFF,
  ].join('.');
}

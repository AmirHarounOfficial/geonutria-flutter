import 'dart:convert';

/// Truncates a password to bcrypt's effective limit of 72 **bytes**.
///
/// bcrypt only ever hashes the first 72 bytes of a password; older versions
/// truncated silently while newer ones raise `ValueError: password cannot be
/// longer than 72 bytes`. The GeoNutria backend passes passwords to bcrypt
/// without truncating, so we do it here — sending the same 72-byte prefix the
/// stored hash was derived from. For the common ASCII password this is a no-op.
String bcryptSafePassword(String password) {
  final bytes = utf8.encode(password);
  if (bytes.length <= 72) return password;
  // Cut at 72 bytes, then back off any partial trailing multibyte sequence so
  // we end on a valid UTF-8 character boundary.
  var len = 72;
  while (len > 0 && (bytes[len] & 0xC0) == 0x80) {
    len--;
  }
  return utf8.decode(bytes.sublist(0, len));
}

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  const secret = 'DWeisApp2026';
  final key = args.isNotEmpty ? args.first : '77a29ddbfb6fce339b7e989ecd734e40';

  // XOR encrypt
  final bytes = <int>[];
  for (var i = 0; i < key.length; i++) {
    bytes.add(key.codeUnitAt(i) ^ secret.codeUnitAt(i % secret.length));
  }

  final encrypted = base64Encode(bytes);
  print('ENCRYPTED: $encrypted');

  // Verify decrypt
  final dec = base64Decode(encrypted);
  final out = StringBuffer();
  for (var i = 0; i < dec.length; i++) {
    out.writeCharCode(dec[i] ^ secret.codeUnitAt(i % secret.length));
  }
  print('DECRYPTED: $out');
  assert(out.toString() == key, 'Round-trip failed!');
  print('Round-trip OK ✓');
}

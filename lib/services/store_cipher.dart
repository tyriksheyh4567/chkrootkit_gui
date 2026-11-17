import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class StoreCipher {
  StoreCipher._(this._key);
  final SecretKey _key;
  static final _aes = AesGcm.with256bits();
  static Future<StoreCipher> derive(String password, List<int> salt) async {
    if (password.length < 8) {
      throw const FormatException(
        'Пароль должен содержать минимум 8 символов.',
      );
    }
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    return StoreCipher._(key);
  }

  static Future<List<int>> newSalt() async =>
      (await _aes.newSecretKey()).extractBytes();
  Future<String> seal(String value, String context) async {
    final box = await _aes.encrypt(
      utf8.encode(value),
      secretKey: _key,
      aad: utf8.encode(context),
    );
    return jsonEncode({
      'v': 1,
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> open(String value, String context) async {
    final data = jsonDecode(value) as Map<String, dynamic>;
    if (data['v'] != 1) {
      throw const FormatException('Неизвестный формат шифрования');
    }
    final clear = await _aes.decrypt(
      SecretBox(
        base64Decode(data['cipher'] as String),
        nonce: base64Decode(data['nonce'] as String),
        mac: Mac(base64Decode(data['mac'] as String)),
      ),
      secretKey: _key,
      aad: utf8.encode(context),
    );
    return utf8.decode(clear);
  }
}

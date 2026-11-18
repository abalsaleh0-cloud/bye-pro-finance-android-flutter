import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppSecurityService {
  AppSecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? authentication,
  }) : _storage = storage ?? FlutterSecureStorage(),
       _authentication = authentication ?? LocalAuthentication();

  static const _pinHashKey = 'bye_pro_pin_hash';
  static const _pinSaltKey = 'bye_pro_pin_salt';
  static const _biometricEnabledKey = 'bye_pro_biometric_enabled';
  static const _iterations = 120000;

  final FlutterSecureStorage _storage;
  final LocalAuthentication _authentication;

  final Pbkdf2 _pinKdf = Pbkdf2.hmacSha256(
    iterations: _iterations,
    bits: 256,
  );

  Future<bool> get hasPin async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<bool> get isBiometricEnabled async =>
      await _storage.read(key: _biometricEnabledKey) == 'true';

  Future<void> savePin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('يجب أن يتكون رمز PIN من 4 إلى 8 أرقام.');
    }

    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final encodedSalt = base64UrlEncode(salt);
    final hash = await _derivePinHash(pin, salt);

    await _storage.write(key: _pinSaltKey, value: encodedSalt);
    await _storage.write(key: _pinHashKey, value: base64UrlEncode(hash));
  }

  Future<bool> verifyPin(String pin) async {
    final encodedSalt = await _storage.read(key: _pinSaltKey);
    final encodedHash = await _storage.read(key: _pinHashKey);
    if (encodedSalt == null || encodedHash == null ||
        !RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return false;
    }

    try {
      final salt = base64Url.decode(base64Url.normalize(encodedSalt));
      final expected = base64Url.decode(base64Url.normalize(encodedHash));
      final actual = await _derivePinHash(pin, salt);
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  Future<void> removePin(String currentPin) async {
    if (!await verifyPin(currentPin)) {
      throw const FormatException('رمز PIN غير صحيح.');
    }
    await disableBiometrics();
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _authentication.canCheckBiometrics;
      final enrolled = await _authentication.getAvailableBiometrics();
      return canCheck && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enableBiometrics() async {
    if (!await hasPin) {
      throw StateError('يجب تعيين رمز PIN قبل تفعيل البصمة.');
    }
    if (!await isBiometricAvailable()) return false;

    final authenticated = await _authentication.authenticate(
      localizedReason: 'أكد هويتك لتفعيل البصمة في Bye Pro Finance',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
    if (authenticated) {
      await _storage.write(key: _biometricEnabledKey, value: 'true');
    }
    return authenticated;
  }

  Future<void> disableBiometrics() async {
    await _storage.delete(key: _biometricEnabledKey);
  }

  Future<bool> authenticateBiometrics() async {
    if (!await isBiometricEnabled || !await isBiometricAvailable()) {
      return false;
    }
    return _authentication.authenticate(
      localizedReason: 'استخدم البصمة لفتح Bye Pro Finance',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<List<int>> _derivePinHash(String pin, List<int> salt) async {
    final secret = await _pinKdf.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return secret.extractBytes();
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

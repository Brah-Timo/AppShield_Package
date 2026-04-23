// lib/src/core/encryption_service.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart' as asn1;

import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Provides AES-256-GCM encryption/decryption for local license storage,
/// RSA signature verification for server-issued license tokens, and
/// HMAC-SHA-256 integrity checking.
class EncryptionService {
  EncryptionService._();

  static final EncryptionService _instance = EncryptionService._();
  static EncryptionService get instance => _instance;

  // ── AES-256-GCM  ──────────────────────────────────────────────────────────

  /// Encrypts [plaintext] with AES-256-GCM.
  /// The returned string is Base64-encoded: [16-byte salt][12-byte IV][ciphertext].
  String encrypt(String plaintext, String passphrase) {
    try {
      final salt = _randomBytes(16);
      final key  = _deriveKey(passphrase, salt);
      final iv   = enc.IV(_randomBytes(AppShieldConstants.aesIvLength));

      final encrypter = enc.Encrypter(
          enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // Combine: salt(16) + iv(12) + ciphertext
      final combined = Uint8List.fromList(
          [...salt, ...iv.bytes, ...encrypted.bytes]);
      return base64Encode(combined);
    } catch (e) {
      AppShieldLogger.e('Encryption failed', error: e);
      throw const EncryptionException('Encryption failed.');
    }
  }

  /// Decrypts a Base64 string previously encrypted with [encrypt].
  /// Returns null if decryption fails (tampered data).
  String? decrypt(String ciphertext, String passphrase) {
    try {
      final combined = base64Decode(ciphertext);
      if (combined.length < 28) return null; // salt(16) + iv(12) minimum

      final salt       = combined.sublist(0, 16);
      final ivBytes    = combined.sublist(16, 28);
      final cipherOnly = combined.sublist(28);

      final key = _deriveKey(passphrase, salt);
      final iv  = enc.IV(Uint8List.fromList(ivBytes));

      final encrypter = enc.Encrypter(
          enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
      return encrypter.decrypt(enc.Encrypted(Uint8List.fromList(cipherOnly)),
          iv: iv);
    } catch (e) {
      AppShieldLogger.w('Decryption failed (data may be tampered)', error: e);
      return null;
    }
  }

  // ── Key derivation (PBKDF2) ────────────────────────────────────────────────

  /// Derives a 256-bit key from [passphrase] + [salt] using PBKDF2-HMAC-SHA256.
  Uint8List _deriveKey(String passphrase, List<int> salt) {
    final params = pc.Pbkdf2Parameters(
      Uint8List.fromList(salt),
      AppShieldConstants.pbkdf2Rounds,
      AppShieldConstants.pbkdf2Length,
    );
    final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(params);
    final passwordBytes = Uint8List.fromList(utf8.encode(passphrase));
    return pbkdf2.process(passwordBytes);
  }

  // ── HMAC-SHA-256 integrity ────────────────────────────────────────────────

  /// Generates an HMAC-SHA-256 tag for [data] using [secret].
  String generateHmac(String data, String secret) {
    final key  = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Returns true if [data] matches [expectedHmac] for [secret].
  bool verifyHmac(String data, String expectedHmac, String secret) {
    final actual = generateHmac(data, secret);
    return _constantTimeCompare(actual, expectedHmac);
  }

  // ── RSA signature verification ────────────────────────────────────────────

  /// Verifies [signature] (Base64-encoded) against [payload] using
  /// the RSA public key in PEM format [publicKeyPem].
  bool verifyRsaSignature({
    required String payload,
    required String signature,
    required String publicKeyPem,
  }) {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      final signer    = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201');
      signer.init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));

      final payloadBytes   = Uint8List.fromList(utf8.encode(payload));
      final signatureBytes  = base64Decode(signature);
      final rsaSig = pc.RSASignature(Uint8List.fromList(signatureBytes));

      return signer.verifySignature(payloadBytes, rsaSig);
    } catch (e) {
      AppShieldLogger.w('RSA signature verification failed', error: e);
      return false;
    }
  }

  // ── Hash utilities ────────────────────────────────────────────────────────

  /// Returns the SHA-256 hex digest of [input].
  String sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Returns a SHA-256-based short hash (first [length] chars).
  String shortHash(String input, {int length = 8}) =>
      sha256Hex(input).substring(0, length).toUpperCase();

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uint8List _randomBytes(int length) {
    final rng   = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) bytes[i] = rng.nextInt(256);
    return bytes;
  }

  /// Parses a PEM-encoded RSA public key (PKCS#8 SubjectPublicKeyInfo format).
  ///
  /// pointycastle ≥3.7 removed `ASN1BitString.contentBytes()`.
  /// The bit-string value bytes start at index 1 (skip the unused-bits octet).
  pc.RSAPublicKey _parsePublicKey(String pem) {
    final stripped = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s'), '');
    final derBytes = base64Decode(stripped);

    // Top-level SEQUENCE: { AlgorithmIdentifier, BIT STRING }
    final topParser = asn1.ASN1Parser(Uint8List.fromList(derBytes));
    final topSeq    = topParser.nextObject() as asn1.ASN1Sequence;
    final bitString = topSeq.elements![1] as asn1.ASN1BitString;

    // valueBytes starts after the tag+length+unused-bits octet (skip 1 byte).
    final bitStringContent = Uint8List.fromList(
        bitString.valueBytes!.sublist(1));

    // Inner SEQUENCE: { INTEGER modulus, INTEGER publicExponent }
    final innerParser = asn1.ASN1Parser(bitStringContent);
    final keySeq  = innerParser.nextObject() as asn1.ASN1Sequence;
    final modulus  = (keySeq.elements![0] as asn1.ASN1Integer).integer!;
    final exponent = (keySeq.elements![1] as asn1.ASN1Integer).integer!;
    return pc.RSAPublicKey(modulus, exponent);
  }

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ── Passphrase derivation ─────────────────────────────────────────────────

  /// Derives a storage passphrase from [deviceId] + [appId] + [appSecret].
  String deriveStoragePassphrase({
    required String deviceId,
    required String appId,
    required String appSecret,
  }) {
    return sha256Hex('$appId:$deviceId:$appSecret:app_shield_v1');
  }
}

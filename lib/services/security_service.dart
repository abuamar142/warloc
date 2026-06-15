import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._internal();

  SecurityService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  SharedPreferences? _prefs;

  // Cache settings in memory
  bool _isLockEnabled = false;
  bool _isBiometricsEnabled = false;
  String _pinCode = '';
  String _securityQuestion = '';
  String _securityAnswer = '';
  int _lockTimeoutSeconds = 0;

  bool get isLockEnabled => _isLockEnabled;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  String get pinCode => _pinCode;
  String get securityQuestion => _securityQuestion;
  String get securityAnswer => _securityAnswer;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isLockEnabled = _prefs?.getBool('lock_enabled') ?? false;
    _isBiometricsEnabled = _prefs?.getBool('biometrics_enabled') ?? false;
    _pinCode = _prefs?.getString('pin_code') ?? '';
    _securityQuestion = _prefs?.getString('security_question') ?? '';
    _securityAnswer = _prefs?.getString('security_answer') ?? '';
    _lockTimeoutSeconds = _prefs?.getInt('lock_timeout_seconds') ?? 0;
  }

  // BIOMETRICS
  Future<bool> get canCheckBiometrics async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  // SETTINGS SETTERS
  Future<void> setLockSettings({
    required bool enabled,
    required String pin,
    required String question,
    required String answer,
  }) async {
    _isLockEnabled = enabled;
    _pinCode = pin;
    _securityQuestion = question;
    // Normalize security answer: lowercase & trimmed spacing
    _securityAnswer = answer.toLowerCase().trim();

    await _prefs?.setBool('lock_enabled', enabled);
    await _prefs?.setString('pin_code', pin);
    await _prefs?.setString('security_question', question);
    await _prefs?.setString('security_answer', _securityAnswer);

    if (!enabled) {
      await setBiometricsEnabled(false);
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    _isBiometricsEnabled = enabled;
    await _prefs?.setBool('biometrics_enabled', enabled);
  }

  Future<void> setLockTimeout(int seconds) async {
    _lockTimeoutSeconds = seconds;
    await _prefs?.setInt('lock_timeout_seconds', seconds);
  }

  // PIN VALIDATION
  bool validatePin(String enteredPin) {
    if (!_isLockEnabled || _pinCode.isEmpty) return true;
    return _pinCode == enteredPin;
  }

  bool validateSecurityAnswer(String enteredAnswer) {
    if (_securityAnswer.isEmpty) return false;
    return _securityAnswer == enteredAnswer.toLowerCase().trim();
  }

  // APP LIFECYCLE TIMEOUT LOCK
  Future<void> updateLastActiveTime() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt('last_active_time', now);
  }

  bool shouldLockOnResume() {
    if (!_isLockEnabled || _pinCode.isEmpty) return false;

    final lastActive = _prefs?.getInt('last_active_time') ?? 0;
    if (lastActive == 0) return true;

    final elapsedSeconds = (DateTime.now().millisecondsSinceEpoch - lastActive) ~/ 1000;
    return elapsedSeconds >= _lockTimeoutSeconds;
  }

  // WIPE APPLICATION DATA
  Future<void> resetApplicationData() async {
    try {
      // 1. Close SQLite DB
      await DatabaseHelper.instance.close();

      // 2. Delete SQLite DB File
      final dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
      await deleteDatabase(dbPath);

      // 3. Delete physical Media directory
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }

      // 4. Clear SharedPreferences
      await _prefs?.clear();
      
      // 5. Reinitialize SecurityService state
      await init();
      
      // 6. Re-open DB
      await DatabaseHelper.instance.database;
    } catch (e) {
      debugPrint("Gagal melakukan setel ulang aplikasi: $e");
      rethrow;
    }
  }
}

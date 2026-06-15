import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warloc/services/security_service.dart';

void main() {
  group('SecurityService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SecurityService.instance.init();
    });

    test('Initial state is disabled', () {
      expect(SecurityService.instance.isLockEnabled, false);
      expect(SecurityService.instance.isBiometricsEnabled, false);
      expect(SecurityService.instance.pinCode, '');
      expect(SecurityService.instance.securityQuestion, '');
      expect(SecurityService.instance.securityAnswer, '');
      expect(SecurityService.instance.lockTimeoutSeconds, 0);
    });

    test('Set lock settings saves to memory and preferences', () async {
      await SecurityService.instance.setLockSettings(
        enabled: true,
        pin: '1234',
        question: 'Who?',
        answer: ' Me ',
      );

      expect(SecurityService.instance.isLockEnabled, true);
      expect(SecurityService.instance.pinCode, '1234');
      expect(SecurityService.instance.securityQuestion, 'Who?');
      // Normalize security answer: lowercase & trimmed spacing
      expect(SecurityService.instance.securityAnswer, 'me');
    });

    test('validatePin validates pin code correctly', () async {
      await SecurityService.instance.setLockSettings(
        enabled: true,
        pin: '1234',
        question: 'Who?',
        answer: 'Me',
      );

      expect(SecurityService.instance.validatePin('1234'), true);
      expect(SecurityService.instance.validatePin('4321'), false);
    });

    test('validateSecurityAnswer normalizes and validates answer correctly', () async {
      await SecurityService.instance.setLockSettings(
        enabled: true,
        pin: '1234',
        question: 'Who?',
        answer: ' Me ',
      );

      expect(SecurityService.instance.validateSecurityAnswer('me'), true);
      expect(SecurityService.instance.validateSecurityAnswer(' ME '), true);
      expect(SecurityService.instance.validateSecurityAnswer('not me'), false);
    });

    test('setBiometricsEnabled updates state correctly', () async {
      await SecurityService.instance.setBiometricsEnabled(true);
      expect(SecurityService.instance.isBiometricsEnabled, true);
      
      await SecurityService.instance.setBiometricsEnabled(false);
      expect(SecurityService.instance.isBiometricsEnabled, false);
    });

    test('setLockTimeout updates timeout state correctly', () async {
      await SecurityService.instance.setLockTimeout(60);
      expect(SecurityService.instance.lockTimeoutSeconds, 60);
    });

    test('shouldLockOnResume returns correct lock status based on timeout', () async {
      // 1. If disabled, should not lock
      expect(SecurityService.instance.shouldLockOnResume(), false);

      // 2. Enable and set timeout
      await SecurityService.instance.setLockSettings(
        enabled: true,
        pin: '1234',
        question: 'Who?',
        answer: 'Me',
      );
      await SecurityService.instance.setLockTimeout(30);

      // 3. No last active time recorded yet -> should lock
      expect(SecurityService.instance.shouldLockOnResume(), true);

      // 4. Update active time now -> should not lock immediately
      await SecurityService.instance.updateLastActiveTime();
      expect(SecurityService.instance.shouldLockOnResume(), false);
    });
  });
}

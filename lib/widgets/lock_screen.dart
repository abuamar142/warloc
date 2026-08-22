import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:warloc/services/security_service.dart';
import 'security/lock_recovery_dialogs.dart';
import 'package:warloc/core/theme/app_colors.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String _errorMessage = '';
  bool _isBiometricChecking = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger biometric on load if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAuto();
    });
  }

  Future<void> _checkBiometricAuto() async {
    final security = SecurityService.instance;
    if (security.isBiometricsEnabled) {
      final canAuth = await security.canCheckBiometrics;
      if (canAuth) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isBiometricChecking) return;
    setState(() {
      _isBiometricChecking = true;
    });

    final success = await SecurityService.instance.authenticateBiometric(
      reason: 'Buka kunci aplikasi Warloc',
    );

    setState(() {
      _isBiometricChecking = false;
    });

    if (success) {
      widget.onUnlocked();
    }
  }

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = '';
      if (_enteredPin.length < SecurityService.instance.pinCode.length) {
        _enteredPin += val;
      }
    });

    // Auto submit when length is reached
    if (_enteredPin.length == SecurityService.instance.pinCode.length) {
      _submitPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _submitPin() {
    final isValid = SecurityService.instance.validatePin(_enteredPin);
    if (isValid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage = 'PIN yang Anda masukkan salah.';
      });
    }
  }

  void _showRecoveryDialog() {
    showRecoveryDialog(context, widget.onUnlocked);
  }

  Widget _buildKey(String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 72,
        width: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetLength = SecurityService.instance.pinCode.length;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          color: isDark ? AppColors.darkBackground.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.75),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Lock Icon
                Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Aplikasi Terkunci",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Masukkan PIN keamanan Anda",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // PIN dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(targetLength, (index) {
                    final filled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      height: 16,
                      width: 16,
                      decoration: BoxDecoration(
                        color: filled ? theme.colorScheme.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: filled ? theme.colorScheme.primary : (isDark ? Colors.white54 : Colors.grey[400]!),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],

                const Spacer(flex: 1),

                // Keyboard grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['1', '2', '3'].map(_buildKey).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['4', '5', '6'].map(_buildKey).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['7', '8', '9'].map(_buildKey).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Biometric button (or empty spacer)
                          SecurityService.instance.isBiometricsEnabled
                              ? IconButton(
                                  icon: Icon(Icons.fingerprint_rounded, size: 40, color: theme.colorScheme.primary),
                                  onPressed: _authenticate,
                                )
                              : const SizedBox(width: 72, height: 72),
                          _buildKey('0'),
                          // Backspace button
                          IconButton(
                            icon: Icon(Icons.backspace_outlined, size: 28, color: isDark ? Colors.grey[300] : Colors.grey[600]),
                            onPressed: _onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                TextButton(
                  onPressed: _showRecoveryDialog,
                  child: Text(
                    "Lupa PIN?",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

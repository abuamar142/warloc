import 'package:flutter/material.dart';
import '../services/security_service.dart';
import 'lock_screen.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLockState();
  }

  Future<void> _initLockState() async {
    await SecurityService.instance.init();
    setState(() {
      _isLocked = SecurityService.instance.isLockEnabled && SecurityService.instance.pinCode.isNotEmpty;
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!_isInitialized) return;

    final security = SecurityService.instance;
    if (!security.isLockEnabled || security.pinCode.isEmpty) return;

    if (security.isAuthenticatingBiometric) return;

    if (state == AppLifecycleState.paused) {
      security.updateLastActiveTime();
    } else if (state == AppLifecycleState.resumed) {
      if (security.shouldLockOnResume()) {
        setState(() {
          _isLocked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF008069)),
        ),
      );
    }

    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () {
                setState(() {
                  _isLocked = false;
                });
                SecurityService.instance.updateLastActiveTime();
              },
            ),
          ),
      ],
    );
  }
}

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
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF008069)),
          ),
        ),
      );
    }

    if (_isLocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: const Color(0xFF008069),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF008069),
            primary: const Color(0xFF008069),
          ),
        ),
        home: LockScreen(
          onUnlocked: () {
            setState(() {
              _isLocked = false;
            });
            SecurityService.instance.updateLastActiveTime();
          },
        ),
      );
    }

    return widget.child;
  }
}

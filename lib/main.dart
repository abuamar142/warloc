import 'package:flutter/material.dart';
import 'package:warloc/screens/chat_list_screen.dart';
import 'widgets/app_lock_wrapper.dart';
import 'package:warloc/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warloc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return AppLockWrapper(child: child!);
      },
      home: const ChatListScreen(),
    );
  }
}

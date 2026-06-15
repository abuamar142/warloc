import 'package:flutter/material.dart';
import 'screens/chat_list_screen.dart';
import 'widgets/app_lock_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const AppLockWrapper(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warloc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF008069),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008069),
          primary: const Color(0xFF008069),
          secondary: const Color(0xFF00A884),
        ),
      ),
      home: const ChatListScreen(),
    );
  }
}

import 'package:bop_or_drop/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // 1. Tell Flutter to hold off on drawing the UI until we are ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Wake up Firebase and give it your secret keys
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Now it's safe to run the app
  runApp(const BopOrDropApp());
}

class BopOrDropApp extends StatelessWidget {
  const BopOrDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BopOrDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.redAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const LoginScreen(),
    );
  }
}
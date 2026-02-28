import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // This is the file FlutterFire just generated for you!

void main() async {
  // 1. Tell Flutter to hold off on drawing the UI until we are ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Wake up Firebase and give it your secret keys
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 3. Now it's safe to run the app
  runApp(const BopOrDropApp());
}

class BopOrDropApp extends StatelessWidget {
  const BopOrDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BopOrDrop',
      debugShowCheckedModeBanner: false, // Hides that little "DEBUG" banner
      theme: ThemeData(
        brightness: Brightness.dark, // Dark mode fits the music vibe perfectly
        primaryColor: Colors.redAccent,
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep Spotify/YTM style background
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            '🔥 Firebase Initialized!\nReady to Bop or Drop.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // These functions are placeholders. We will add the actual 
  // Firebase/OAuth login logic to them in the next steps!
  void _loginWithSpotify(BuildContext context) {
    print("Spotify button pressed!");
    // TODO: Implement Spotify Auth
  }

  void _loginWithYouTube(BuildContext context) {
    print("YouTube button pressed!");
    // TODO: Implement YouTube/Google Auth
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. App Logo / Title
              const Icon(
                Icons.headphones_rounded,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'BopOrDrop',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Discover your next favorite track.\nChoose your provider to start swiping.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),

              // 2. Spotify Button
              ElevatedButton.icon(
                onPressed: () => _loginWithSpotify(context),
                icon: const FaIcon(FontAwesomeIcons.spotify, color: Colors.white),
                label: const Text(
                  'Continue with Spotify',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954), // Official Spotify Green
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 20),

              // 3. YouTube Music Button
              ElevatedButton.icon(
                onPressed: () => _loginWithYouTube(context),
                icon: const FaIcon(FontAwesomeIcons.youtube, color: Colors.white),
                label: const Text(
                  'Continue with YouTube',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000), // Official YouTube Red
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
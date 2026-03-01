import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget{
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Grab the currently logged-in Firebase user
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile Picture
            if (user?.photoURL != null)
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(user!.photoURL!),
              )
            else
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            
            const SizedBox(height: 20),

            // Display Name
            Text(
              user?.displayName ?? 'Spotify User',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // Email
            if (user?.email != null)
              Text(
                user!.email!,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            
            const SizedBox(height: 40),

            // Sign out Button
            ElevatedButton.icon(
              onPressed: () async {
                // 1. Instantly show a loading wheel so they know it's working
                showDialog(
                  context: context,
                  barrierDismissible: false, // Prevents them from tapping outside to close it
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ),
                );

                // 2. Call our sign out service (takes 1-2 seconds)
                await AuthService().signOut();
                
                // 3. Teleport them back to the Login Screen
                // (pushAndRemoveUntil automatically destroys the loading dialog too!)
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false, 
                  );
                }
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
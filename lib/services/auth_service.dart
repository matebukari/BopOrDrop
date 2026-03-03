import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Google & YouTube sign in
  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      
      await googleSignIn.initialize(
        serverClientId: '503401496531-d3b7deh46v2q0ifbfqjmjejem04afism.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final List<String> scopes = [
        'https://www.googleapis.com/auth/youtube',
      ];
      
      print("BOP: Requesting YouTube permissions...");
      
      final authClient = googleUser.authorizationClient;
      GoogleSignInClientAuthorization? authorization = await authClient.authorizationForScopes(scopes);
      
      authorization ??= await authClient.authorizeScopes(scopes);

      final String youtubeAccessToken = authorization.accessToken;

      await _storage.write(key: 'youtube_access_token', value: youtubeAccessToken);
      
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: youtubeAccessToken, 
      );
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      print("BOP: SUCCESS! Logged into Google with YouTube permissions!");
      return userCredential.user;
      
    } catch (e) {
      print("BOP: Error signing in with Google: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out of Google
      await GoogleSignIn.instance.signOut();
      // Sign out of Firebase
      await _auth.signOut();

      print("BOP: Successfully signed out.");
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}
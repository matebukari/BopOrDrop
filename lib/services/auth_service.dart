import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google sign in
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Initialize the global instance
      await GoogleSignIn.instance.initialize(
        serverClientId: '503401496531-d3b7deh46v2q0ifbfqjmjejem04afism.apps.googleusercontent.com'
      );

      // 2. Trigger the Google Authentication flow
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // 3. Obtain the auth details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 4. Create a new credential that Firebase can understand
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 5. Securely sign in to Firebase with this credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      return userCredential.user;
      
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // Spotify sign in
  Future<void> signInWithSpotify() async {
    const String clientId = 'e1eaf72cd97b4e0ea69a359473c626fd'; 
    const String clientSecret = '8323a50df19d4ab9864b18c663a50043';
    const String redirectUri = 'bopordrop://callback';

    // 1. Construct the Spotify Auth URL
    final url = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      // We are asking for permission to read their email and modify their playlists!
      'scope': 'user-read-private user-read-email playlist-modify-public playlist-modify-private',
    });

    try {
      print("Opening Spotify login window...");
      // 2. Open the web browser to log in
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'bopordrop',
      );

      // 3. Extract the auth code from the URL Spotify sent back
      final code = Uri.parse(result).queryParameters['code'];

      if (code != null) {
        print("Spotify Auth Code received! Fetching Access Token...");

        // 4. Exchange the code for an Access Token
        final tokenResponse = await http.post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
          },
          body: {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirectUri,
          },
        );

        if (tokenResponse.statusCode == 200) {
          final tokenData = jsonDecode(tokenResponse.body);
          final accessToken = tokenData['access_token'];
          print("SUCCESS! Logged into Spotify!");
          print("Your Access Token: $accessToken");
          // Later, we will save this token to Firebase!
        } else {
          print("Failed to get token: ${tokenResponse.body}");
        }
      }
    } catch (e) {
      print("Spotify login canceled or failed: $e");
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out of Google
      await GoogleSignIn.instance.signOut();
      // Sign out of Firebase
      await _auth.signOut();
      // (Later, we will also clear the Spotify Access Token here!)
      print("Successfully signed out.");
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}
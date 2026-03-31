import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  final String _serverClientId = '503401496531-d3b7deh46v2q0ifbfqjmjejem04afism.apps.googleusercontent.com';
  final List<String> _scopes = [
    'https://www.googleapis.com/auth/youtube',
  ];

  // ==========================================
  // --- CORE AUTHENTICATION ---
  // ==========================================

  // Google & YouTube sign in
  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize(serverClientId: _serverClientId);
      print("BOP: Requesting YouTube permissions...");

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      final authClient = googleUser.authorizationClient;
      GoogleSignInClientAuthorization? authorization = await authClient.authorizationForScopes(_scopes);

      authorization ??= await authClient.authorizeScopes(_scopes);

      final String youtubeAccessToken = authorization.accessToken;

      // SAVE TO DEVICE: We need both the token and the ID for the background services!
      await _storage.write(key: 'youtube_access_token', value: youtubeAccessToken);
      await _storage.write(key: 'youtube_user_id', value: googleUser.id);

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
      // Clear secure storage so the next user doesn't accidentally load old data
      await _storage.delete(key: 'youtube_access_token');
      await _storage.delete(key: 'youtube_user_id');
      await _storage.delete(key: 'cached_discover_deck');

      // Use disconnect() to fully revoke Google permissions on the device
      await _googleSignIn.disconnect();
      await _auth.signOut();

      print("BOP: Successfully signed out.");
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  Future<String?> getYoutubeUserId() async {
    String? id = await _storage.read(key: 'youtube_user_id');

    if (id == null) {
      await _googleSignIn.initialize(serverClientId: _serverClientId);
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null) {
        id = account.id;
        await _storage.write(key: 'youtube_user_id', value: id);
      }
    }
    return id;
  }

  Future<http.Response?> youtubeAuthenticatedRequest(
    Future<http.Response> Function(String token) requestFunc,
  ) async {
    String? token = await _storage.read(key: 'youtube_access_token');
    
    if (token == null) {
      token = await refreshYoutubeToken();
      if (token == null) return null;
    }

    var response = await requestFunc(token);

    // Handle expired token (401 Unauthorized)
    if (response.statusCode == 401) {
      token = await refreshYoutubeToken();
      if (token != null) {
        response = await requestFunc(token);
      } else {
        return null;
      }
    }
    return response;
  }

  Future<String?> refreshYoutubeToken() async {
    try {
      await _googleSignIn.initialize(serverClientId: _serverClientId);

      // attemptLightweightAuthentication instead of signInSilently
      final GoogleSignInAccount? account = await _googleSignIn.attemptLightweightAuthentication();
      
      if (account != null) {
        final authClient = account.authorizationClient;
        final authorization = await authClient.authorizationForScopes(_scopes);
        
        final String? newToken = authorization?.accessToken;
        if (newToken != null) {
          await _storage.write(key: 'youtube_access_token', value: newToken);
          return newToken;
        }
      }
      return null;
    } catch (e) {
      print("BOP ERROR: Could not refresh background token: $e");
      return null;
    }
  }
}
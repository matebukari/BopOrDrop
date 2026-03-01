import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
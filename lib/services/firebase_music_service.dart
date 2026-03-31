import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song_model.dart';
import 'auth_service.dart';

class FirebaseMusicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  // In-memory cache to make duplicate filtering blazing fast
  Set<String>? _cachedDroppedIds;

  // We require the AuthService to be passed in so we know who is logged in
  FirebaseMusicService(this._authService);

  // ==========================================
  // --- DROPPED SONGS (SWIPE LEFT) ---
  // ==========================================

  Future<Set<String>> getDroppedIds() async {
    // Return instantly if we already downloaded them this session
    if (_cachedDroppedIds != null) return _cachedDroppedIds!;
    
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return {};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dropped_songs')
          .get();
          
      _cachedDroppedIds = snapshot.docs.map((doc) => doc.id).toSet();
      return _cachedDroppedIds!;
    } catch (e) {
      print('BOP ERROR: Failed to fetch dropped IDs: $e');
      return {};
    }
  }

  Future<void> dropSong(SongModel song) async {
    _cachedDroppedIds?.add(song.id); // Add to local cache instantly
    
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('dropped_songs')
          .doc(song.id)
          .set(song.toJson());
    } catch (e) {
      print('BOP ERROR: Failed to save drop to Firebase: $e');
    }
  }

  Future<void> undropSong(String videoId) async {
    _cachedDroppedIds?.remove(videoId); // Remove from local cache instantly
    
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('dropped_songs')
          .doc(videoId)
          .delete();
    } catch (e) {
      print('BOP ERROR: Failed to remove drop from Firebase: $e');
    }
  }

  Future<List<SongModel>> getFirebaseDroppedSongs() async {
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return [];
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dropped_songs')
          .get();

      return snapshot.docs
          .map((doc) => SongModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('BOP ERROR: Failed to fetch full dropped songs from Firebase: $e');
      return [];
    }
  }

  // ==========================================
  // --- BOPPED SONGS (SWIPE RIGHT) ---
  // ==========================================

  Future<void> saveBoppedSong(SongModel song, String playlistId) async {
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return;
    
    try {
      // Attach the playlist ID it was saved to so we know where it lives!
      final songWithPlaylistId = song.copyWith(
        savedPlaylistId: playlistId,
      );
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bopped_songs')
          .doc(song.id)
          .set(songWithPlaylistId.toJson());
    } catch (e) {
      print('BOP ERROR: Failed to save bop to Firebase: $e');
    }
  }

  Future<void> removeBoppedSong(String videoId) async {
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bopped_songs')
          .doc(videoId)
          .delete();
    } catch (e) {
      print('BOP ERROR: Failed to remove bop from Firebase: $e');
    }
  }

  Future<List<SongModel>> getFirebaseBoppedSongs() async {
    final userId = await _authService.getYoutubeUserId();
    if (userId == null) return [];
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bopped_songs')
          .get();

      return snapshot.docs
          .map((doc) => SongModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('BOP ERROR: Failed to fetch bops from Firebase: $e');
      return [];
    }
  }
}
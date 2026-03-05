import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/song_model.dart';

class YoutubeService {
  final _storage = const FlutterSecureStorage();

  Future<String?> _refreshToken() async {
    try {      
      final googleSignIn = GoogleSignIn.instance;
      
      // Silently authenticate the currently logged-in user
      final GoogleSignInAccount? account = await googleSignIn.attemptLightweightAuthentication();
      
      if (account != null) {
        final authorization = await account.authorizationClient.authorizationForScopes([
          'https://www.googleapis.com/auth/youtube',
        ]);
        
        final String? newToken = authorization?.accessToken;
        
        if (newToken != null) {
          await _storage.write(key: 'youtube_access_token', value: newToken);
          print('BOP SUCCESS: Token refreshed and saved securely!');
          return newToken;
        }
      }
      print('BOP ERROR: Could not silently refresh token.');
      return null;
    } catch (e) {
      print('BOP EXCEPTION: Failed to refresh token: $e');
      return null;
    }
  }

  // --- NEW: Helper method to check which songs the user already liked ---
  Future<Set<String>> _getAlreadyLikedIds(List<String> videoIds, String token) async {
    if (videoIds.isEmpty) return {};

    final idString = videoIds.join(',');
    final url = Uri.parse('https://www.googleapis.com/youtube/v3/videos/getRating?id=$idString');

    var response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode == 401) {
      final newToken = await _refreshToken();
      if (newToken != null) {
        response = await http.get(url, headers: {
          'Authorization': 'Bearer $newToken',
          'Accept': 'application/json',
        });
      }
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List items = data['items'] ?? [];
      
      Set<String> likedIds = {};
      for (var item in items) {
        if (item['rating'] == 'like') {
          likedIds.add(item['videoId']);
        }
      }
      return likedIds;
    }
    return {};
  }

  Future<bool> likeVideo(String videoId) async {
    try {
      String? token = await _storage.read(key: 'youtube_access_token');
      if (token == null) return false;

      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos/rate?id=$videoId&rating=like'
      );

      var response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // Catch Expired Token & Retry
      if (response.statusCode == 401) {
        print('BOP: Token expired! Refreshing...');
        token = await _refreshToken();
        
        if (token != null) {
          response = await http.post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
        }
      }

      if (response.statusCode == 204) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('BOP EXCEPTION: Failed to make HTTP request: $e');
      return false;
    }
  }

  Future<List<SongModel>> fetchTrendingMusic() async {
    try {
      String? token = await _storage.read(key: 'youtube_access_token');
      if (token == null) return [];

      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&videoCategoryId=10&regionCode=US&maxResults=20'
      );

      var response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // Catch Expired Token & Retry
      if (response.statusCode == 401) {
        print('BOP: Token expired! Refreshing...');
        token = await _refreshToken();
        
        if (token != null) {
          response = await http.get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];
        
        List<SongModel> fetchedSongs = items.map((item) {
          final snippet = item['snippet'];
          final thumbnails = snippet['thumbnails'];
          final coverArt = thumbnails['maxres']?['url'] ?? 
                           thumbnails['high']?['url'] ?? 
                           thumbnails['default']?['url'] ?? '';

          return SongModel(
            id: item['id'],
            title: snippet['title'],
            artist: snippet['channelTitle'], 
            coverArtUrl: coverArt,
          );
        }).toList();

        // Filter out songs the user already liked
        if (token != null && fetchedSongs.isNotEmpty) {
          print('BOP: Checking for already liked songs...');
          final currentToken = await _storage.read(key: 'youtube_access_token');

          if (currentToken != null) {
            Set<String> alreadyLikedIds = await _getAlreadyLikedIds(
              fetchedSongs.map((s) => s.id).toList(),
              currentToken
            );

            fetchedSongs.removeWhere((song) => alreadyLikedIds.contains(song.id));
          }
        }

        print('BOP SUCCESS: Fetched ${fetchedSongs.length} trending songs!');
        return fetchedSongs;
      } else {
        print('BOP ERROR: Failed to fetch music. Status Code: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('BOP EXCEPTION: Failed to fetch trending music: $e');
      return [];
    }
  }
}
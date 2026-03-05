import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/song_model.dart';

class FetchResults {
  final List<SongModel> songs;
  final String? nextPageToken;

  FetchResults({required this.songs, this.nextPageToken});
}

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

  // Helper method to check which songs the user already liked
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

  Future<FetchResults> fetchTrendingMusic({String? pageToken}) async {
    try {
      String? token = await _storage.read(key: 'youtube_access_token');
      if (token == null) return FetchResults(songs: []);


      String urlString = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=UU_aEa8K-EOJ3D6gOs7HcyNg&maxResults=10';
      if (pageToken != null) {
        urlString += '&pageToken=${Uri.encodeComponent(pageToken)}';
      }

      final url = Uri.parse(urlString);

      var response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
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
        final String? nextToken = data['nextPageToken'];
        
        List<SongModel> fetchedSongs = [];

        for (var item in items) {
          final snippet = item['snippet'];
          final videoId = snippet['resourceId']?['videoId'];
          if (videoId == null) continue;
          
          final thumbnails = snippet['thumbnails'];
          if (thumbnails == null) continue;
          
          final coverArt = thumbnails['maxres']?['url'] ?? 
                           thumbnails['high']?['url'] ?? 
                           thumbnails['default']?['url'] ?? '';
                           
          String rawTitle = snippet['title'] ?? 'Unknown Title';
          String title = rawTitle;
          String artist = snippet['videoOwnerChannelTitle'] ?? 'Unknown Artist';
          
          if (rawTitle.contains(' - ')) {
            final parts = rawTitle.split(' - ');
            artist = parts[0].trim();
            // Clean up the UI by removing "[NCS Release]" and "(feat. X)"
            title = parts[1].replaceAll(RegExp(r'\[.*?\]'), '').replaceAll(RegExp(r'\(.*?\)'), '').trim();
          }

          fetchedSongs.add(SongModel(
            id: videoId,
            title: title,
            artist: artist, 
            coverArtUrl: coverArt,
          ));
        }

        if (token != null && fetchedSongs.isNotEmpty) {
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
        return FetchResults(songs: fetchedSongs, nextPageToken: nextToken);
      } else {
        print('BOP ERROR: Failed to fetch music. Status Code: ${response.statusCode}');
        print('BOP ERROR BODY: ${response.body}');
        return FetchResults(songs: []);
      }
    } catch (e) {
      print('BOP EXCEPTION: Failed to fetch trending music: $e');
      return FetchResults(songs: []);
    }
  }
}
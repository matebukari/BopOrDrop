import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'dart:ui' as ui;

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

  String _getRegionalPlaylistId() {
    // Grab the user's 2-letter country code
    String region = ui.PlatformDispatcher.instance.locale.countryCode ?? 'US';
    
    // Our custom routing dictionary! 
    Map<String, String> regionalPlaylists = {
      'AR': 'PL4fGSI1pDJn4Kd7YEG9LbUqvt64PLs9Fo', // Argentina Top 100
      'AU': 'PL4fGSI1pDJn7xvYy-bP6UFeG5tITQgScd', // Australia Top 100
      'AT': 'PL4fGSI1pDJn6fFTVP30alDfSDAkEtHaNr', // Austria Top 100
      'BE': 'PL4fGSI1pDJn64Up8Ds5BXizLBFZ922jHj', // Belgium Top 100
      'BO': 'PL4fGSI1pDJn5Vi4RJX33LnETbjMhmPc9V', // Bolivia Top 100
      'BR': 'PL4fGSI1pDJn7rGBE8kEC0CqTa1nMh9AKB', // Brazil Top 100
      'CA': 'PL4fGSI1pDJn57Q7WbODbmXjyjgXi0BTyD', // Canada Top 100
      'CL': 'PL4fGSI1pDJn777t00zYu_BKjXHUdhkXH9', // Chile Top 100
      'CO': 'PL4fGSI1pDJn6CW97F1vSZOkoU7k7VsYk9', // Colombia Top 100
      'CR': 'PL4fGSI1pDJn6U9fUfBkfy3uyXE7Rtvo4b', // Costa Rica Top 100
      'CZ': 'PL4fGSI1pDJn5wV1AgglmIN_8okwTkz9WT', // Czechia Top 100
      'DK': 'PL4fGSI1pDJn51jFsgXEIR7WdKBychJiMU', // Denmark Top 100
      'DO': 'PL4fGSI1pDJn4C36SQoHh9fII-EXde2i3k', // Dominican Republic Top 100
      'EC': 'PL4fGSI1pDJn7K4bdLZJ5GppzLDAihF58q', // Ecuador Top 100
      'EG': 'PL4fGSI1pDJn510j-1L8bMgKTyeRwPrXWY', // Egypt Top 100
      'SV': 'PL4fGSI1pDJn6ALv-WRypOl0nGaLgtW6nC', // El Salvador Top 100
      'EE': 'PL4fGSI1pDJn7uCBUO9GemJda1xfqmvV7_', // Estonia Top 100
      'FI': 'PL4fGSI1pDJn4T5TECl_90hfJsPUu1yi2y', // Finland Top 100
      'FR': 'PL4fGSI1pDJn7bK3y1Hx-qpHBqfr6cesNs', // France Top 100
      'DE': 'PL4fGSI1pDJn6KpOXlp0MH8qA9tngXaUJ-', // Germany Top 100
      'GT': 'PL4fGSI1pDJn7NCQ_U0nwlhidgZ8E3uBQw', // Guatemala Top 100
      'HN': 'PL4fGSI1pDJn5ZVtAKP9-OKnn09CJ-Znpt', // Honduras Top 100
      'HU': 'PL4fGSI1pDJn6K3QY1nHyhOGQqNCBGbMKi', // Hungary Top 100
      'IS': 'PL4fGSI1pDJn6pwJw_mb31TUqc9C_gpskG', // Iceland Top 100
      'IN': 'PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw', // India Top 100
      'ID': 'PL4fGSI1pDJn5ObxTlEPlkkornHXUiKX1z', // Indonesia Top 100
      'IE': 'PL4fGSI1pDJn5S_UFt83P-RlBC4CR3JYuo', // Ireland Top 100
      'IL': 'PL4fGSI1pDJn4ECcNLNscMAPND-Degbd5N', // Israel Top 100
      'IT': 'PL4fGSI1pDJn5JiDypHxveEplQrd7XQMlX', // Italy Top 100
      'JP': 'PL4fGSI1pDJn4-UIb6RKHdxam-oAUULIGB', // Japan Top 100
      'KE': 'PL4fGSI1pDJn7z-3xqv1Ujjobcy2pjpZAA', // Kenya Top 100
      'LU': 'PL4fGSI1pDJn4ie_xg2ndQYSEeZrFYvkQf', // Luxembourg Top 100
      'MX': 'PL4fGSI1pDJn6fko1AmNa_pdGPZr5ROFvd', // Mexico Top 100
      'NL': 'PL4fGSI1pDJn7CXu1B1U0lYQ0qfPB9TVfa', // Netherlands Top 100
      'NZ': 'PL4fGSI1pDJn6SZ8psSiS6j-QgUACJK4gC', // New Zealand Top 100
      'NI': 'PL4fGSI1pDJn7eCAxG3AuCuottnW_D5C5w', // Nicaragua Top 100
      'NG': 'PL4fGSI1pDJn6Au0oeuQPsd1iFyiU8Br9I', // Nigeria Top 100
      'NO': 'PL4fGSI1pDJn7ywehQhyuuPWo3ayrdSOHn', // Norway Top 100
      'PA': 'PL4fGSI1pDJn4G4B-V4UTrxD7l5mE9cPS-', // Panama Top 100
      'PY': 'PL4fGSI1pDJn5G0B8V2PSgs7O9EA4gF5m_', // Paraguay Top 100
      'PE': 'PL4fGSI1pDJn4k5jOJjYpq8pluME-gNAnh', // Peru Top 100
      'PL': 'PL4fGSI1pDJn68fmsRw9f6g-NzU5UA45v1', // Poland Top 100
      'PT': 'PL4fGSI1pDJn7H0X0bZN4C-I6YeldOvPku', // Portugal Top 100
      'RO': 'PL4fGSI1pDJn5G2T6hrqwSS7ajUA7y4S5l', // Romania Top 100
      'RU': 'PL4fGSI1pDJn5C8dBiYt0BTREyCHbZ47qc', // Russia Top 100
      'SA': 'PL4fGSI1pDJn7xNK-XdqvCsqa7I8Nx3IyW', // Saudi Arabia Top 100
      'RS': 'PL4fGSI1pDJn79dpGvfySMY9w43BluD4lI', // Serbia Top 100
      'ZA': 'PL4fGSI1pDJn7xvqMZR_9OgljLcMQpuKXN', // South Africa Top 100
      'KR': 'PL4fGSI1pDJn6jXS_Tv_N9B8Z0HTRVJE0m', // South Korea Top 100
      'ES': 'PL4fGSI1pDJn6sMPCoD7PdSlEgyUylgxuT', // Spain Top 100
      'SE': 'PL4fGSI1pDJn7S_JFSuBHol2RH9WphaqzS', // Sweden Top 100
      'CH': 'PL4fGSI1pDJn6Nhmcqn4xr769wwoMmS3DI', // Sweden Top 100
      'TZ': 'PL4fGSI1pDJn4CI0qH2JZYs2qGXo1itpCG', // Tanzania Top 100
      'TR': 'PL4fGSI1pDJn5tdVDtIAZArERm_vv4uFCR', // Turkey Top 100
      'UG': 'PL4fGSI1pDJn56127QXqxGADbedOpL5z5R', // Uganda Top 100
      'UA': 'PL4fGSI1pDJn4E_HoW5HB-w5vFPkYfo3dB', // Ukraine Top 100
      'AE': 'PL4fGSI1pDJn71VxNxT-PpECxHCVv8T-oX', // United Arab Emirates Top 100
      'GB': 'PL4fGSI1pDJn6_f5P3MnzXg9l3GDfnSlXa', // United Kingdom Top 100
      'US': 'PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI', // United States Top 100
      'UY': 'PL4fGSI1pDJn5caN5mlO8NWCPSyuHkQANg', // Uruguay Top 100
      'ZW': 'PL4fGSI1pDJn7PWidyUayXX6-josrejRMG', // Zimbabwe Top 100
    };

    // If we have their country, give them the local chart. 
    // If not, default to the official "Global Top 100 Songs" playlist!
    return regionalPlaylists[region] ?? 'PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i'; 
  }

  // Fetch user playlists
  Future<List<PlaylistModel>> fetchMyPlaylists() async {
    try {
      String? token = await _storage.read(key: 'youtube_access_token');
      if (token == null) return [];

      final url = Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&maxResults=50');
      var response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});

      if (response.statusCode == 401) {
        token = await _refreshToken();
        if (token != null) response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];

        List<PlaylistModel> playlists = items.map((item) {
          return PlaylistModel(
            id: item['id'],
            title: item['snippet']['title'],
          );
        }).toList();

        return  playlists;
      }
      return [];
    } catch (e) {
      print('BOP EXCEPTION: Failed to fetch playlists: $e');
      return [];
    }
  }

  // Get IDs of songs already in a specific playlist
  Future<Set<String>> _getAlreadyInPlaylistIds(String playlistId, String token) async {
    Set<String> savedIds = {};
    String? nextPageToken;

    try {
      do {
        String urlString = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$playlistId&maxResults=50';
        
        if (nextPageToken != null) {
          urlString += '&pageToken=${Uri.encodeComponent(nextPageToken)}';
        }

        final url = Uri.parse(urlString);
        var response = await http.get(url, headers: {
          'Authorization': 'Bearer $token', 
          'Accept': 'application/json'
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List items = data['items'] ?? [];

          for (var item in items) {
            final videoId = item['snippet']?['resourceId']?['videoId'];
            if (videoId != null) savedIds.add(videoId);
          }
          
          // Grab the next page token. If it's null, the loop will break!
          nextPageToken = data['nextPageToken'];
        } else {
          // If the API throws an error midway, stop looping and return what we have so far
          print('BOP ERROR: Failed to fetch playlist page. Status Code: ${response.statusCode}');
          break; 
        }
      } while (nextPageToken != null);
      
      return savedIds;
    } catch (e) {
      print('BOP EXCEPTION: Failed to paginate through playlist: $e');
      return savedIds;
    }
  }
  
  // Save router (Handles Liked Music AND Custom Playlists)
  Future<bool> saveSong(String videoId, String targetPlaylistId) async {
    // If they selected the default "Liked Music", route to our original likeVideo method
    if (targetPlaylistId == 'LIKED_MUSIC') {
      return await likeVideo(videoId);
    }

    // Otherwise, do a POST request to add it to their custom playlist
    try {
      String? token = await _storage.read(key: 'youtube_access_token');
      if (token == null) return false;

      Set<String> existingIds = await _getAlreadyInPlaylistIds(targetPlaylistId, token);
      if (existingIds.contains(videoId)) {
        print('BOP: Song is already in this playlist! Preventing duplicate.');
        return true; 
      }

      final url = Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet');
      final body = json.encode({
        'snippet': {
          'playlistId': targetPlaylistId,
          'resourceId': {
            'kind': 'youtube#video',
            'videoId': videoId
          }
        }
      });

      var response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: body,
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

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('BOP EXCEPTION: Failed to add to custom playlist: $e');
      return false;
    }
  }

  Future<FetchResults> fetchTrendingMusic({String? pageToken, String targetPlaylistId = 'LIKED_MUSIC'}) async {
    try {
      String? token = await _storage.read(key: 'youtube_access_token');
      if (token == null) return FetchResults(songs: []);

      String chartPlaylistId = _getRegionalPlaylistId();

      String urlString = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$chartPlaylistId&maxResults=50';
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
          if (videoId == null || videoId is! String) continue;
          
          final thumbnails = snippet['thumbnails'];
          if (thumbnails == null) continue;
          
          final coverArt = thumbnails['maxres']?['url'] ?? 
                           thumbnails['high']?['url'] ?? 
                           thumbnails['default']?['url'] ?? '';
                           
          String title = snippet['title'] ?? 'Unknown Title';
          String rawArtist = snippet['videoOwnerChannelTitle'] ?? 'Unknown Artist';
          final cleanArtist = rawArtist.replaceAll(' - Topic', '').replaceAll('VEVO', '').trim();

          fetchedSongs.add(SongModel(
            id: videoId,
            title: title,
            artist: cleanArtist, 
            coverArtUrl: coverArt,
          ));
        }

        // Filter out songs the user already liked
        if (token != null && fetchedSongs.isNotEmpty) {
          final currentToken = await _storage.read(key: 'youtube_access_token');

          if (currentToken != null) {
            Set<String> alreadySavedIds;

            if (targetPlaylistId == 'LIKED_MUSIC') {
              alreadySavedIds = await _getAlreadyLikedIds(fetchedSongs.map((s) => s.id).toList(), currentToken);
            } else {
              alreadySavedIds = await _getAlreadyInPlaylistIds(targetPlaylistId, currentToken);
            }

            fetchedSongs.removeWhere((song) => alreadySavedIds.contains(song.id));
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
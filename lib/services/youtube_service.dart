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

  // The Netwok Manager
  // This central wrapper handles EVERY request, checks for expired tokens, 
  // refreshes them silently, and retries the request automatically!
  Future<http.Response?> _authenticatedRequest(Future<http.Response> Function(String token) requestFunc) async {
    String? token = await _storage.read(key: 'youtube_access_token');
    if (token == null) return null;

    var response = await requestFunc(token);

    // Catch Expired Token & Retry automatically!
    if (response.statusCode == 401) {
      print('BOP: Token expired! Refreshing automatically...');
      token = await _refreshToken();
      if (token != null) {
        response = await requestFunc(token);
      } else {
        return null; // Complete failure
      }
    }
    return response;
  }

  Future<String?> _refreshToken() async {
    try {      
      final googleSignIn = GoogleSignIn.instance;
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
      return null;
    } catch (e) {
      return null;
    }
  }

  // API METHODS

  Future<Set<String>> _getAlreadyLikedIds(List<String> videoIds) async {
    if (videoIds.isEmpty) return {};

    final idString = videoIds.join(',');
    final url = Uri.parse('https://www.googleapis.com/youtube/v3/videos/getRating?id=$idString');

    var response = await _authenticatedRequest((token) => http.get(
      url, 
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}
    ));

    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      final List items = data['items'] ?? [];
      
      Set<String> likedIds = {};
      for (var item in items) {
        if (item['rating'] == 'like') likedIds.add(item['videoId']);
      }
      return likedIds;
    }
    return {};
  }

  Future<bool> likeVideo(String videoId) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/youtube/v3/videos/rate?id=$videoId&rating=like');
      var response = await _authenticatedRequest((token) => http.post(
        url, 
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}
      ));

      return response?.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<List<PlaylistModel>> fetchMyPlaylists() async {
    try {
      final url = Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&maxResults=50');
      var response = await _authenticatedRequest((token) => http.get(
        url, 
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}
      ));

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];

        return items.map((item) => PlaylistModel(
          id: item['id'],
          title: item['snippet']['title'],
        )).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Set<String>> _getAlreadyInPlaylistIds(String playlistId) async {
    Set<String> savedIds = {};
    String? nextPageToken;

    try {
      do {
        String urlString = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$playlistId&maxResults=50';
        if (nextPageToken != null) urlString += '&pageToken=${Uri.encodeComponent(nextPageToken)}';

        final url = Uri.parse(urlString);
        var response = await _authenticatedRequest((token) => http.get(
          url, 
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}
        ));

        if (response != null && response.statusCode == 200) {
          final data = json.decode(response.body);
          final List items = data['items'] ?? [];

          for (var item in items) {
            final videoId = item['snippet']?['resourceId']?['videoId'];
            if (videoId != null) savedIds.add(videoId);
          }
          nextPageToken = data['nextPageToken'];
        } else {
          break; 
        }
      } while (nextPageToken != null);
      
      return savedIds;
    } catch (e) {
      return savedIds;
    }
  }
  
  Future<bool> saveSong(String videoId, String targetPlaylistId) async {
    if (targetPlaylistId == 'LIKED_MUSIC') return await likeVideo(videoId);

    try {
      Set<String> existingIds = await _getAlreadyInPlaylistIds(targetPlaylistId);
      if (existingIds.contains(videoId)) {
        return true; 
      }

      final url = Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet');
      final body = json.encode({
        'snippet': {
          'playlistId': targetPlaylistId,
          'resourceId': {'kind': 'youtube#video', 'videoId': videoId}
        }
      });

      var response = await _authenticatedRequest((token) => http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: body,
      ));

      return response?.statusCode == 200 || response?.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unsaveSong(String videoId, String targetPlaylistId) async {
    if (targetPlaylistId == 'LIKED_MUSIC') {
      return await _removeLike(videoId);
    } else {
      return await _removeFromCustomPlaylist(videoId, targetPlaylistId);
    }
  }

  Future<bool> _removeLike(String videoId) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/youtube/v3/videos/rate?id=$videoId&rating=none');
      var response = await _authenticatedRequest((token) => http.post(
        url, 
        headers: {'Authorization': 'Bearer $token'}
      ));
      return response?.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _removeFromCustomPlaylist(String videoId, String playlistId) async {
    try {
      final searchUrl = Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=id&playlistId=$playlistId&videoId=$videoId');
      var searchResponse = await _authenticatedRequest((token) => http.get(
        searchUrl, 
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}
      ));
      
      if (searchResponse != null && searchResponse.statusCode == 200) {
        final data = json.decode(searchResponse.body);
        final items = data['items'] ?? [];
        if (items.isEmpty) return true; 

        final playlistItemId = items[0]['id'];
        final deleteUrl = Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?id=$playlistItemId');
        var deleteResponse = await _authenticatedRequest((token) => http.delete(
          deleteUrl, 
          headers: {'Authorization': 'Bearer $token'}
        ));
        
        return deleteResponse?.statusCode == 204;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Manage Drops in loacalstorage
  
  Future<Set<String>> _getDroppedSongIds() async {
    try {
      String? droppedString = await _storage.read(key: 'dropped_songs');
      if (droppedString == null || droppedString.isEmpty) return {};
      return droppedString.split(',').toSet();
    } catch (e) {
      return {};
    }
  }

  Future<void> dropSong(String videoId) async {
    try {
      Set<String> droppedIds = await _getDroppedSongIds();
      droppedIds.add(videoId);
      await _storage.write(key: 'dropped_songs', value: droppedIds.join(','));
    } catch (e) {
      return;
    }
  }

  Future<void> undropSong(String videoId) async {
    try {
      Set<String> droppedIds = await _getDroppedSongIds();
      if (droppedIds.remove(videoId)) {
        await _storage.write(key: 'dropped_songs', value: droppedIds.join(','));
      }
    } catch (e) {
      return;
    }
  }
  
  // TRENDING CHART ROUTER

  String _getRegionalPlaylistId() {
    String region = ui.PlatformDispatcher.instance.locale.countryCode ?? 'US';
    Map<String, String> regionalPlaylists = {
      'AR': 'PL4fGSI1pDJn4Kd7YEG9LbUqvt64PLs9Fo', 'AU': 'PL4fGSI1pDJn7xvYy-bP6UFeG5tITQgScd',
      'AT': 'PL4fGSI1pDJn6fFTVP30alDfSDAkEtHaNr', 'BE': 'PL4fGSI1pDJn64Up8Ds5BXizLBFZ922jHj',
      'BO': 'PL4fGSI1pDJn5Vi4RJX33LnETbjMhmPc9V', 'BR': 'PL4fGSI1pDJn7rGBE8kEC0CqTa1nMh9AKB',
      'CA': 'PL4fGSI1pDJn57Q7WbODbmXjyjgXi0BTyD', 'CL': 'PL4fGSI1pDJn777t00zYu_BKjXHUdhkXH9',
      'CO': 'PL4fGSI1pDJn6CW97F1vSZOkoU7k7VsYk9', 'CR': 'PL4fGSI1pDJn6U9fUfBkfy3uyXE7Rtvo4b',
      'CZ': 'PL4fGSI1pDJn5wV1AgglmIN_8okwTkz9WT', 'DK': 'PL4fGSI1pDJn51jFsgXEIR7WdKBychJiMU',
      'DO': 'PL4fGSI1pDJn4C36SQoHh9fII-EXde2i3k', 'EC': 'PL4fGSI1pDJn7K4bdLZJ5GppzLDAihF58q',
      'EG': 'PL4fGSI1pDJn510j-1L8bMgKTyeRwPrXWY', 'SV': 'PL4fGSI1pDJn6ALv-WRypOl0nGaLgtW6nC',
      'EE': 'PL4fGSI1pDJn7uCBUO9GemJda1xfqmvV7_', 'FI': 'PL4fGSI1pDJn4T5TECl_90hfJsPUu1yi2y',
      'FR': 'PL4fGSI1pDJn7bK3y1Hx-qpHBqfr6cesNs', 'DE': 'PL4fGSI1pDJn6KpOXlp0MH8qA9tngXaUJ-',
      'GT': 'PL4fGSI1pDJn7NCQ_U0nwlhidgZ8E3uBQw', 'HN': 'PL4fGSI1pDJn5ZVtAKP9-OKnn09CJ-Znpt',
      'HU': 'PL4fGSI1pDJn6K3QY1nHyhOGQqNCBGbMKi', 'IS': 'PL4fGSI1pDJn6pwJw_mb31TUqc9C_gpskG',
      'IN': 'PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw', 'ID': 'PL4fGSI1pDJn5ObxTlEPlkkornHXUiKX1z',
      'IE': 'PL4fGSI1pDJn5S_UFt83P-RlBC4CR3JYuo', 'IL': 'PL4fGSI1pDJn4ECcNLNscMAPND-Degbd5N',
      'IT': 'PL4fGSI1pDJn5JiDypHxveEplQrd7XQMlX', 'JP': 'PL4fGSI1pDJn4-UIb6RKHdxam-oAUULIGB',
      'KE': 'PL4fGSI1pDJn7z-3xqv1Ujjobcy2pjpZAA', 'LU': 'PL4fGSI1pDJn4ie_xg2ndQYSEeZrFYvkQf',
      'MX': 'PL4fGSI1pDJn6fko1AmNa_pdGPZr5ROFvd', 'NL': 'PL4fGSI1pDJn7CXu1B1U0lYQ0qfPB9TVfa',
      'NZ': 'PL4fGSI1pDJn6SZ8psSiS6j-QgUACJK4gC', 'NI': 'PL4fGSI1pDJn7eCAxG3AuCuottnW_D5C5w',
      'NG': 'PL4fGSI1pDJn6Au0oeuQPsd1iFyiU8Br9I', 'NO': 'PL4fGSI1pDJn7ywehQhyuuPWo3ayrdSOHn',
      'PA': 'PL4fGSI1pDJn4G4B-V4UTrxD7l5mE9cPS-', 'PY': 'PL4fGSI1pDJn5G0B8V2PSgs7O9EA4gF5m_',
      'PE': 'PL4fGSI1pDJn4k5jOJjYpq8pluME-gNAnh', 'PL': 'PL4fGSI1pDJn68fmsRw9f6g-NzU5UA45v1',
      'PT': 'PL4fGSI1pDJn7H0X0bZN4C-I6YeldOvPku', 'RO': 'PL4fGSI1pDJn5G2T6hrqwSS7ajUA7y4S5l',
      'RU': 'PL4fGSI1pDJn5C8dBiYt0BTREyCHbZ47qc', 'SA': 'PL4fGSI1pDJn7xNK-XdqvCsqa7I8Nx3IyW',
      'RS': 'PL4fGSI1pDJn79dpGvfySMY9w43BluD4lI', 'ZA': 'PL4fGSI1pDJn7xvqMZR_9OgljLcMQpuKXN',
      'KR': 'PL4fGSI1pDJn6jXS_Tv_N9B8Z0HTRVJE0m', 'ES': 'PL4fGSI1pDJn6sMPCoD7PdSlEgyUylgxuT',
      'SE': 'PL4fGSI1pDJn7S_JFSuBHol2RH9WphaqzS', 'CH': 'PL4fGSI1pDJn6Nhmcqn4xr769wwoMmS3DI',
      'TZ': 'PL4fGSI1pDJn4CI0qH2JZYs2qGXo1itpCG', 'TR': 'PL4fGSI1pDJn5tdVDtIAZArERm_vv4uFCR',
      'UG': 'PL4fGSI1pDJn56127QXqxGADbedOpL5z5R', 'UA': 'PL4fGSI1pDJn4E_HoW5HB-w5vFPkYfo3dB',
      'AE': 'PL4fGSI1pDJn71VxNxT-PpECxHCVv8T-oX', 'GB': 'PL4fGSI1pDJn6_f5P3MnzXg9l3GDfnSlXa',
      'US': 'PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI', 'UY': 'PL4fGSI1pDJn5caN5mlO8NWCPSyuHkQANg',
      'ZW': 'PL4fGSI1pDJn7PWidyUayXX6-josrejRMG',
    };
    return regionalPlaylists[region] ?? 'PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i'; 
  }

  Future<FetchResults> fetchTrendingMusic({String? pageToken, String targetPlaylistId = 'LIKED_MUSIC'}) async {
    try {
      String chartPlaylistId = _getRegionalPlaylistId();
      String urlString = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$chartPlaylistId&maxResults=50';
      if (pageToken != null) urlString += '&pageToken=${Uri.encodeComponent(pageToken)}';

      final url = Uri.parse(urlString);

      var response = await _authenticatedRequest((token) => http.get(
        url,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ));

      if (response != null && response.statusCode == 200) {
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
            id: videoId, title: title, artist: cleanArtist, coverArtUrl: coverArt,
          ));
        }

        // Filter out songs the user already liked
        if (fetchedSongs.isNotEmpty) {
          Set<String> alreadySavedIds;
          if (targetPlaylistId == 'LIKED_MUSIC') {
            alreadySavedIds = await _getAlreadyLikedIds(fetchedSongs.map((s) => s.id).toList());
          } else {
            alreadySavedIds = await _getAlreadyInPlaylistIds(targetPlaylistId);
          }
          fetchedSongs.removeWhere((song) => alreadySavedIds.contains(song.id));
        }

        // Filter out locally dropped songs
        Set<String> droppedIds = await _getDroppedSongIds();
        fetchedSongs.removeWhere((song) => droppedIds.contains(song.id));

        return FetchResults(songs: fetchedSongs, nextPageToken: nextToken);
      } else {
        return FetchResults(songs: []);
      }
    } catch (e) {
      return FetchResults(songs: []);
    }
  }
}
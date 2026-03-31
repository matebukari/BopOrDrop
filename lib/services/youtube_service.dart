import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:ui' as ui;

import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/fetch_results.dart';
import 'auth_service.dart';
import 'firebase_music_service.dart';

class YoutubeService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // 1. Instantiate our background services
  final AuthService _authService = AuthService();
  late final FirebaseMusicService _firebaseService;

  YoutubeService() {
    _firebaseService = FirebaseMusicService(_authService);
  }

  // ==========================================
  // --- FIREBASE DELEGATES ---
  // ==========================================

  Future<List<SongModel>> getFirebaseBoppedSongs() => _firebaseService.getFirebaseBoppedSongs();
  Future<List<SongModel>> getFirebaseDroppedSongs() => _firebaseService.getFirebaseDroppedSongs();
  Future<void> dropSong(SongModel song) => _firebaseService.dropSong(song);
  Future<void> undropSong(String videoId) => _firebaseService.undropSong(videoId);

  // ==========================================
  // --- YOUTUBE API: PLAYLISTS & SAVING ---
  // ==========================================

  Future<List<PlaylistModel>> fetchUserPlaylists() async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&maxResults=50',
      );
      var response = await _authService.youtubeAuthenticatedRequest(
        (token) => http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];

        return items
          .map(
            (item) => PlaylistModel(
              id: item['id'],
              title: item['snippet']['title'],
            ),
          )
          .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<FetchResults> fetchPlaylistSongs(
    String playlistId, {
    String? pageToken,
  }) async {
    try {
      List<SongModel> fetchedSongs = [];
      String urlString =
        'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$playlistId&maxResults=50';

      if (pageToken != null) {
        urlString += '&pageToken=${Uri.encodeComponent(pageToken)}';
      }

      final url = Uri.parse(urlString);
      var response = await _authService.youtubeAuthenticatedRequest(
        (token) => http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];
        final String? nextToken = data['nextPageToken'];

        for (var item in items) {
          final snippet = item['snippet'];
          final videoId = snippet['resourceId']?['videoId'];
          if (videoId == null || videoId is! String) continue;

          final thumbnails = snippet['thumbnails'];
          final coverArt = thumbnails?['maxres']?['url'] ??
              thumbnails?['high']?['url'] ??
              thumbnails?['default']?['url'] ??
              '';
          String title = snippet['title'] ?? 'Unknown Title';
          String cleanArtist = (snippet['videoOwnerChannelTitle'] ?? 'Unknown Artist')
              .replaceAll(' - Topic', '')
              .replaceAll('VEVO', '')
              .trim();

          fetchedSongs.add(
            SongModel(
              id: videoId,
              title: title,
              artist: cleanArtist,
              coverArtUrl: coverArt,
            ),
          );
        }

        return FetchResults(songs: fetchedSongs, nextPageToken: nextToken);
      }
      return FetchResults(songs: []);
    } catch (e) {
      return FetchResults(songs: []);
    }
  }

  Future<bool> saveSong(SongModel song, String targetPlaylistId) async {
    // 1. Save to Firebase Database securely using the delegate
    await _firebaseService.saveBoppedSong(song, targetPlaylistId);

    // 2. Save to YouTube Custom Playlist
    try {
      Set<String> existingIds = await _getAlreadyInPlaylistIds(targetPlaylistId);
      if (existingIds.contains(song.id)) return true;

      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet',
      );
      final body = json.encode({
        'snippet': {
          'playlistId': targetPlaylistId,
          'resourceId': {'kind': 'youtube#video', 'videoId': song.id},
        },
      });

      var response = await _authService.youtubeAuthenticatedRequest(
        (token) => http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: body,
        ),
      );

      print('BOP DEBUG: YouTube Save Status Code: ${response?.statusCode}');
      return response?.statusCode == 200 || response?.statusCode == 201;
    } catch (e) {
      print('BOP DEBUG: Crash inside saveSong: $e');
      return false;
    }
  }

  Future<bool> unsaveSong(String videoId, String targetPlaylistId) async {
    // 1. Remove from Firebase Database securely using the delegate
    await _firebaseService.removeBoppedSong(videoId);

    // 2. Remove from YouTube Custom Playlist
    return await _removeFromCustomPlaylist(videoId, targetPlaylistId);
  }

  Future<bool> _removeFromCustomPlaylist(
    String videoId,
    String playlistId,
  ) async {
    try {
      final searchUrl = Uri.parse(
        'https://www.googleapis.com/youtube/v3/playlistItems?part=id&playlistId=$playlistId&videoId=$videoId',
      );
      var searchResponse = await _authService.youtubeAuthenticatedRequest(
        (token) => http.get(
          searchUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (searchResponse != null && searchResponse.statusCode == 200) {
        final data = json.decode(searchResponse.body);
        final items = data['items'] ?? [];
        if (items.isEmpty) return true;

        final playlistItemId = items[0]['id'];
        final deleteUrl = Uri.parse(
          'https://www.googleapis.com/youtube/v3/playlistItems?id=$playlistItemId',
        );
        var deleteResponse = await _authService.youtubeAuthenticatedRequest(
          (token) => http.delete(
            deleteUrl,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );

        return deleteResponse?.statusCode == 204;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // --- UTILS: DUPLICATE PREVENTION ---
  // ==========================================

  Future<Set<String>> _getAlreadyInPlaylistIds(String playlistId) async {
    Set<String> savedIds = {};
    String? nextPageToken;

    try {
      do {
        String urlString =
            'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$playlistId&maxResults=50';
        if (nextPageToken != null) {
          urlString += '&pageToken=${Uri.encodeComponent(nextPageToken)}';
        }
        final url = Uri.parse(urlString);
        var response = await _authService.youtubeAuthenticatedRequest(
          (token) => http.get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
        );

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

  // ==========================================
  // --- DISCOVERY & TRENDING CHARTS ---
  // ==========================================

  String _getRegionalPlaylistId() {
    String region = ui.PlatformDispatcher.instance.locale.countryCode ?? 'US';
    Map<String, String> regionalPlaylists = {
      'AR': 'PL4fGSI1pDJn4Kd7YEG9LbUqvt64PLs9Fo',
      'AU': 'PL4fGSI1pDJn7xvYy-bP6UFeG5tITQgScd',
      'AT': 'PL4fGSI1pDJn6fFTVP30alDfSDAkEtHaNr',
      'BE': 'PL4fGSI1pDJn64Up8Ds5BXizLBFZ922jHj',
      'BO': 'PL4fGSI1pDJn5Vi4RJX33LnETbjMhmPc9V',
      'BR': 'PL4fGSI1pDJn7rGBE8kEC0CqTa1nMh9AKB',
      'CA': 'PL4fGSI1pDJn57Q7WbODbmXjyjgXi0BTyD',
      'CL': 'PL4fGSI1pDJn777t00zYu_BKjXHUdhkXH9',
      'CO': 'PL4fGSI1pDJn6CW97F1vSZOkoU7k7VsYk9',
      'CR': 'PL4fGSI1pDJn6U9fUfBkfy3uyXE7Rtvo4b',
      'CZ': 'PL4fGSI1pDJn5wV1AgglmIN_8okwTkz9WT',
      'DK': 'PL4fGSI1pDJn51jFsgXEIR7WdKBychJiMU',
      'DO': 'PL4fGSI1pDJn4C36SQoHh9fII-EXde2i3k',
      'EC': 'PL4fGSI1pDJn7K4bdLZJ5GppzLDAihF58q',
      'EG': 'PL4fGSI1pDJn510j-1L8bMgKTyeRwPrXWY',
      'SV': 'PL4fGSI1pDJn6ALv-WRypOl0nGaLgtW6nC',
      'EE': 'PL4fGSI1pDJn7uCBUO9GemJda1xfqmvV7_',
      'FI': 'PL4fGSI1pDJn4T5TECl_90hfJsPUu1yi2y',
      'FR': 'PL4fGSI1pDJn7bK3y1Hx-qpHBqfr6cesNs',
      'DE': 'PL4fGSI1pDJn6KpOXlp0MH8qA9tngXaUJ-',
      'GT': 'PL4fGSI1pDJn7NCQ_U0nwlhidgZ8E3uBQw',
      'HN': 'PL4fGSI1pDJn5ZVtAKP9-OKnn09CJ-Znpt',
      'HU': 'PL4fGSI1pDJn6K3QY1nHyhOGQqNCBGbMKi',
      'IS': 'PL4fGSI1pDJn6pwJw_mb31TUqc9C_gpskG',
      'IN': 'PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw',
      'ID': 'PL4fGSI1pDJn5ObxTlEPlkkornHXUiKX1z',
      'IE': 'PL4fGSI1pDJn5S_UFt83P-RlBC4CR3JYuo',
      'IL': 'PL4fGSI1pDJn4ECcNLNscMAPND-Degbd5N',
      'IT': 'PL4fGSI1pDJn5JiDypHxveEplQrd7XQMlX',
      'JP': 'PL4fGSI1pDJn4-UIb6RKHdxam-oAUULIGB',
      'KE': 'PL4fGSI1pDJn7z-3xqv1Ujjobcy2pjpZAA',
      'LU': 'PL4fGSI1pDJn4ie_xg2ndQYSEeZrFYvkQf',
      'MX': 'PL4fGSI1pDJn6fko1AmNa_pdGPZr5ROFvd',
      'NL': 'PL4fGSI1pDJn7CXu1B1U0lYQ0qfPB9TVfa',
      'NZ': 'PL4fGSI1pDJn6SZ8psSiS6j-QgUACJK4gC',
      'NI': 'PL4fGSI1pDJn7eCAxG3AuCuottnW_D5C5w',
      'NG': 'PL4fGSI1pDJn6Au0oeuQPsd1iFyiU8Br9I',
      'NO': 'PL4fGSI1pDJn7ywehQhyuuPWo3ayrdSOHn',
      'PA': 'PL4fGSI1pDJn4G4B-V4UTrxD7l5mE9cPS-',
      'PY': 'PL4fGSI1pDJn5G0B8V2PSgs7O9EA4gF5m_',
      'PE': 'PL4fGSI1pDJn4k5jOJjYpq8pluME-gNAnh',
      'PL': 'PL4fGSI1pDJn68fmsRw9f6g-NzU5UA45v1',
      'PT': 'PL4fGSI1pDJn7H0X0bZN4C-I6YeldOvPku',
      'RO': 'PL4fGSI1pDJn5G2T6hrqwSS7ajUA7y4S5l',
      'RU': 'PL4fGSI1pDJn5C8dBiYt0BTREyCHbZ47qc',
      'SA': 'PL4fGSI1pDJn7xNK-XdqvCsqa7I8Nx3IyW',
      'RS': 'PL4fGSI1pDJn79dpGvfySMY9w43BluD4lI',
      'ZA': 'PL4fGSI1pDJn7xvqMZR_9OgljLcMQpuKXN',
      'KR': 'PL4fGSI1pDJn6jXS_Tv_N9B8Z0HTRVJE0m',
      'ES': 'PL4fGSI1pDJn6sMPCoD7PdSlEgyUylgxuT',
      'SE': 'PL4fGSI1pDJn7S_JFSuBHol2RH9WphaqzS',
      'CH': 'PL4fGSI1pDJn6Nhmcqn4xr769wwoMmS3DI',
      'TZ': 'PL4fGSI1pDJn4CI0qH2JZYs2qGXo1itpCG',
      'TR': 'PL4fGSI1pDJn5tdVDtIAZArERm_vv4uFCR',
      'UG': 'PL4fGSI1pDJn56127QXqxGADbedOpL5z5R',
      'UA': 'PL4fGSI1pDJn4E_HoW5HB-w5vFPkYfo3dB',
      'AE': 'PL4fGSI1pDJn71VxNxT-PpECxHCVv8T-oX',
      'GB': 'PL4fGSI1pDJn6_f5P3MnzXg9l3GDfnSlXa',
      'US': 'PL4fGSI1pDJn6O1LS0XSdF3RyO0Rq_LDeI',
      'UY': 'PL4fGSI1pDJn5caN5mlO8NWCPSyuHkQANg',
      'ZW': 'PL4fGSI1pDJn7PWidyUayXX6-josrejRMG',
    };
    return regionalPlaylists[region] ?? 'PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i';
  }

  Future<FetchResults> fetchTrendingMusic({
    String? pageToken,
    String targetPlaylistId = '',
  }) async {
    try {
      String chartPlaylistId = _getRegionalPlaylistId();

      List<SongModel> finalSongs = [];
      String? currentToken = pageToken;

      // Safety net: Max 4 pages (200 songs) checked per fetch 
      // to prevent infinite API looping if they've dropped everything
      int maxPagesToFetch = 4; 
      int pagesFetched = 0;
      
      while (finalSongs.isEmpty && pagesFetched < maxPagesToFetch) {
        String urlString =
          'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$chartPlaylistId&maxResults=50';

        if (pageToken != null) {
          urlString += '&pageToken=${Uri.encodeComponent(pageToken)}';
        }

        final url = Uri.parse(urlString);

        var response = await _authService.youtubeAuthenticatedRequest(
          (token) => http.get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
        );

        if (response != null && response.statusCode == 200) {
          final data = json.decode(response.body);
          final List items = data['items'] ?? [];
          currentToken = data['nextPageToken'];

          List<SongModel> fetchedPage = [];

          for (var item in items) {
            final snippet = item['snippet'];
            final videoId = snippet['resourceId']?['videoId'];
            if (videoId == null || videoId is! String) continue;

            final thumbnails = snippet['thumbnails'];
            if (thumbnails == null) continue;

            final coverArt =
                thumbnails['maxres']?['url'] ??
                thumbnails['high']?['url'] ??
                thumbnails['default']?['url'] ??
                '';

            String title = snippet['title'] ?? 'Unknown Title';
            String rawArtist =
                snippet['videoOwnerChannelTitle'] ?? 'Unknown Artist';
            final cleanArtist = rawArtist
                .replaceAll(' - Topic', '')
                .replaceAll('VEVO', '')
                .trim();

            fetchedPage.add(
              SongModel(
                id: videoId,
                title: title,
                artist: cleanArtist,
                coverArtUrl: coverArt,
              ),
            );
          }

          // Filter out existing saved and dropped songs
          if (fetchedPage.isNotEmpty) {
            Set<String> alreadySavedIds = {};
            Set<String> droppedIds = {};

            await Future.wait([
              () async {
                alreadySavedIds = await _getAlreadyInPlaylistIds(targetPlaylistId);
              }(),
              () async {
                droppedIds = await _firebaseService.getDroppedIds();
              }(),
            ]);

            // Filter out dropped songs
            fetchedPage.removeWhere(
              (song) =>
                  alreadySavedIds.contains(song.id) ||
                  droppedIds.contains(song.id),
            );
          }

          // Add whatever fresh songs survived the filter to our final list!
          finalSongs.addAll(fetchedPage);
          pagesFetched++;

          // If there is no next page (we reached song #100), break out early
          if (currentToken == null) break;

        } else {
          // If the API crashes or returns an error, stop looping
          break;
        }
      }
      
      // Cache the newly pulled and filtered deck to local storage
      if (finalSongs.isNotEmpty) {
        try {
          final cacheData = json.encode(
            finalSongs.map((s) => s.toJson()).toList(),
          );
          await _storage.write(key: 'cached_discover_deck', value: cacheData);
        } catch (e) {
          print('Failed to cache deck: $e');
        }
      }

      return FetchResults(songs: finalSongs, nextPageToken: currentToken);

    } catch (e) {
      print('BOP ERROR: Crash inside fetchTrendingMusic: $e');
      return FetchResults(songs: []);
    }
  }

  Future<List<SongModel>> getCachedDeck() async {
    try {
      final cachedData = await _storage.read(key: 'cached_discover_deck');
      if (cachedData != null) {
        final List decoded = json.decode(cachedData);
        return decoded.map((item) => SongModel.fromJson(item)).toList();
      }
    } catch (e) {}
    return [];
  }
}

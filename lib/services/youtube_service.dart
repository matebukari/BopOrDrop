import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/song_model.dart';

class YoutubeService {
  final _storage = const FlutterSecureStorage();

  Future<bool> likeVideo(String videoId) async {
    try {
      // Grab YouTube Access Token from secure vault
      final token = await _storage.read(key: 'youtube_access_token');

      if (token == null) {
        print('BOP ERROR: No YouTube access token found. User might need to log in again.');
        return false;
      }

      // YouTube API endpoint to "rate" (like/dislike) a video
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos/rate?id=$videoId&rating=like'
      );

      print('BOP: Sending "Like" request to YouTube for video ID: $videoId...');

      // 3. Fire POST request with the token
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // YouTube returns '204 No Content' status code if it was successful!
      if (response.statusCode == 204) {
        print('BOP SUCCESS: 🎵 Successfully added to Liked Music! 🎵');
        return true;
      } else {
        print('BOP ERROR: Failed to like video. Status Code: ${response.statusCode}');
        print('BOP Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('BOP EXCEPTION: Failed to make HTTP request: $e');
      return false;
    }
  }

  Future<List<SongModel>> fetchTrendingMusic() async {
    try {
      final token = await _storage.read(key: 'youtube_access_token');

      if (token == null) {
        print('BOP ERROR: No YouTube access token found.');
        return [];
      }

      // YouTube API endpoint for most popular videos in the Music category (10)
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&videoCategoryId=10&regionCode=US&maxResults=20'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['items'] ?? [];

        // Convert the YouTube JSON data into the SongModel list
        List<SongModel> fetchedSongs = items.map((item) {
          final snippet = item['snippet'];

          final thumbnails = snippet['thumbnails'];
          final coverArt = thumbnails['maxres']?['url'] ?? 
                           thumbnails['high']?['url'] ?? 
                           thumbnails['default']?['url'] ?? '';

          return SongModel(
            id: item['id'],
            title: snippet['title'],
            artist: snippet['channelTitle'], // The channel name is usually the artist
            coverArtUrl: coverArt,
          );
        }).toList();

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
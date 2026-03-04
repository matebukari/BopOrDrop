import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
}
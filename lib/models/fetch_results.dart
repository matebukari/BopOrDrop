import 'song_model.dart';

class FetchResults {
  final List<SongModel> songs;
  final String? nextPageToken;

  FetchResults({required this.songs, this.nextPageToken});
}
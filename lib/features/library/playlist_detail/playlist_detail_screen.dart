import 'package:flutter/material.dart';
import '../../../models/playlist_model.dart';
import '../../../models/song_model.dart';
import '../../../services/youtube_service.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final YoutubeService _youtubeService = YoutubeService();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  List<SongModel> _songs = [];
  String? _nextPageToken;

  @override
  void initState() {
    super.initState();
    _loadInitialSongs();
  }

  Future<void> _loadInitialSongs() async {
    final results = await _youtubeService.fetchPlaylistSongs(
      widget.playlist.id,
    );
    if (mounted) {
      setState(() {
        _songs = results.songs;
        _nextPageToken = results.nextPageToken;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isFetchingMore || _nextPageToken == null) return;

    setState(() => _isFetchingMore = true);

    final results = await _youtubeService.fetchPlaylistSongs(
      widget.playlist.id,
      pageToken: _nextPageToken,
    );

    if (mounted) {
      setState(() {
        _songs.addAll(results.songs);
        _nextPageToken = results.nextPageToken;
        _isFetchingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.playlist.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : _songs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 60, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    "This playlist is empty.",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // If we scroll near the bottom, trigger the fetch!
                if (!_isFetchingMore &&
                    scrollInfo.metrics.pixels >=
                        scrollInfo.metrics.maxScrollExtent - 200) {
                  _loadMoreSongs();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                itemCount: _songs.length + (_nextPageToken != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _songs.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.greenAccent,
                        ),
                      ),
                    );
                  }
                  final song = _songs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8.0),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          song.coverArtUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: Icon(Icons.more_vert, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

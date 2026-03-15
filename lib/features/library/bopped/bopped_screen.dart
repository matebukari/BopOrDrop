import 'package:flutter/material.dart';
import '../../../models/song_model.dart';
import '../../../services/youtube_service.dart';
import '../../../utils/song_action_sheet.dart';

class BoppedScreen extends StatefulWidget {
  const BoppedScreen({super.key});

  @override
  State<BoppedScreen> createState() => _BoppedScreenState();
}

class _BoppedScreenState extends State<BoppedScreen> {
  final YoutubeService _youtubeService = YoutubeService();

  bool _isLoading = true;
  List<SongModel> _boppedSongs = [];

  @override
  void initState() {
    super.initState();
    _loadBoppedMusic();
  }

  Future<void> _loadBoppedMusic() async {
    final songs = await _youtubeService.getFirebaseBoppedSongs();
    final reversedSongs = songs.reversed.toList();

    if (mounted) {
      setState(() {
        _boppedSongs = reversedSongs;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBop(SongModel song) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removing ${song.title}...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final targetPlaylist = song.savedPlaylistId ?? 'LIKED_MUSIC';
    final success = await _youtubeService.unsaveSong(song.id, targetPlaylist);

    if (success && mounted) {
      setState(() {
        _boppedSongs.removeWhere((s) => s.id == song.id);
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
        title: const Text(
          'Bopped Music',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : _boppedSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text(
                    "No bopped music yet.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Go to the Discover tab and start swiping right!",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                itemCount: _boppedSongs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 Columns!
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      0.75, // Makes the cards slightly taller than they are wide
                ),
                itemBuilder: (context, index) {
                  final song = _boppedSongs[index];
                  return GestureDetector(
                    onTap: () {
                      SongActionSheet.show(
                        context: context,
                        song: song,
                        actionText: 'Remove Bop',
                        actionIcon: Icons.favorite_border,
                        onAction: () => _removeBop(song),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. The Album Cover
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(song.coverArtUrl),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 2. The Song Title
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        // 3. The Artist Name
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../models/song_model.dart';
import '../../../services/youtube_service.dart';

class DroppedScreen extends StatefulWidget {
  const DroppedScreen({super.key});

  @override
  State<DroppedScreen> createState() => _DroppedScreenState();
}

class _DroppedScreenState extends State<DroppedScreen> {
  final YoutubeService _youtubeService = YoutubeService();
  
  bool _isLoading = true;
  List<SongModel> _droppedSongs = [];

  @override
  void initState() {
    super.initState();
    _loadDroppedMusic();
  }

  Future<void> _loadDroppedMusic() async {
    final songs = await _youtubeService.getLocalDroppedSongs();
    
    // Show newest drops at the top
    final reversedSongs = songs.reversed.toList();

    if (mounted) {
      setState(() {
        _droppedSongs = reversedSongs;
        _isLoading = false;
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
        title: const Text('Dropped Music', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _droppedSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 80, color: Colors.grey[800]),
                      const SizedBox(height: 16),
                      const Text(
                        "No dropped music yet.",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Songs you swipe left on will appear here.",
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    itemCount: _droppedSongs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 Columns for the grid!
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75, // Matches the Bopped screen proportions
                    ),
                    itemBuilder: (context, index) {
                      final song = _droppedSongs[index];
                      return Column(
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          // 3. The Artist Name
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
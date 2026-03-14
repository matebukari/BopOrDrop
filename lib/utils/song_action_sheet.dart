import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/song_model.dart';

class SongActionSheet {
  static void show({
    required BuildContext context,
    required SongModel song,
    required VoidCallback onRemove,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ), 
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.coverArtUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60, height: 60, color: Colors.grey[800],
                          child: const Icon(Icons.music_note, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ), 
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),

                // --- ACTIONS ---

                // Open in YouTube
                ListTile(
                  leading: const Icon(Icons.ondemand_video, color: Colors.redAccent, size: 28),
                  title: const Text('Open in YouTube', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final url = Uri.parse('https://www.youtube.com/watch?v=${song.id}');
                    if (await canLaunchUrl(url)) {
                      // Forces it to open the actual YouTube app if installed
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),

                // Remove from Playlist
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.grey, size: 28),
                  title: const Text('Remove from Playlist', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    onRemove();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
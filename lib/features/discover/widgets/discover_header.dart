import 'package:flutter/material.dart';

class DiscoverHeader extends StatelessWidget {
  final String playlistName;

  const DiscoverHeader({super.key, required this.playlistName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        children: [
          const Text(
            'BopOrDrop',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_music, color: Colors.grey[400], size: 16),
              const SizedBox(width: 6),
              Text(
                'Saving to $playlistName on YouTube',
                style: TextStyle(
                  color: Colors.grey[400], 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
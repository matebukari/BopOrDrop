// lib/features/discover/discover_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../models/song_model.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final CardSwiperController _swiperController = CardSwiperController();

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final swipedSong = dummySongs[previousIndex];

    if (direction == CardSwiperDirection.left) {
      print('Dropped: ${swipedSong.title}');
    } else if (direction == CardSwiperDirection.right) {
      print('Bopped (Saved): ${swipedSong.title}');
    }
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CardSwiper(
                controller: _swiperController,
                cardsCount: dummySongs.length,
                onSwipe: _onSwipe,
                allowedSwipeDirection: const AllowedSwipeDirection.symmetric(
                  horizontal: true,
                ),
                cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                  return _buildCard(dummySongs[index]);
                },
              ),
            ),
            const SizedBox(height: 20),
            // Manual Buttons for tapping instead of dragging
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'drop',
                  onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.close, size: 30, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: 'bop',
                  onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
                  backgroundColor: Colors.greenAccent[400],
                  child: const Icon(Icons.favorite, size: 30, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // The visual design of the physical card
  Widget _buildCard(SongModel song) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(song.coverArtUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Colors.transparent, Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.6, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              song.artist,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
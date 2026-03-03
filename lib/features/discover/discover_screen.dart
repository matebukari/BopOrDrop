import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:async';
import '../../models/song_model.dart';
import '../profile/profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final CardSwiperController _swiperController = CardSwiperController();

  late YoutubePlayerController _ytController;
  Timer? _playbackTimer;
  
  bool _isPlaying = true;
  bool _previewFinished = false; 
  
  String _currentVideoId = ''; 

  @override
  void initState() {
    super.initState();

    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        mute: false,
        showFullscreenButton: false,
        loop: false,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );

    if (dummySongs.isNotEmpty) {
      _currentVideoId = dummySongs[0].id;
      _loadAndPlayPreview(_currentVideoId);
    }
  }

  void _loadAndPlayPreview(String videoId) async {
    _playbackTimer?.cancel();
    
    setState(() {
      _isPlaying = true;
      _previewFinished = false;
    });

    await _ytController.loadVideoById(videoId: videoId, startSeconds: 45);
    _ytController.playVideo();

    _startPreviewTimer();
  }

  void _startPreviewTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer(const Duration(seconds: 30), () {
      _ytController.pauseVideo();
      
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _previewFinished = true; 
        });
      }
      print("Preview finished. Awaiting next swipe or replay.");
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      // Just pause it
      _ytController.pauseVideo();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // If they press play...
      if (_previewFinished) {
        print("Replaying the exact 30-second preview...");
        _loadAndPlayPreview(_currentVideoId); 
      } else {
        // NORMAL PLAY LOGIC: Just resume where they paused
        _ytController.playVideo();
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _ytController.close();
    super.dispose();
  }

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

    if (currentIndex != null && currentIndex < dummySongs.length) {
      _currentVideoId = dummySongs[currentIndex].id;
      _loadAndPlayPreview(_currentVideoId);
    } else {
      _ytController.pauseVideo();
      _playbackTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _previewFinished = false;
      });
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
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Offstage(
              offstage: true,
              child: YoutubePlayer(controller: _ytController),
            ),

            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BopOrDrop',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person, size: 30),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: dummySongs.length,
                    onSwipe: _onSwipe,
                    allowedSwipeDirection:
                        const AllowedSwipeDirection.symmetric(horizontal: true),
                    cardBuilder:
                        (context, index, percentThresholdX, percentThresholdY) {
                          return _buildCard(dummySongs[index]);
                        },
                  ),
                ),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'drop',
                      onPressed: () =>
                          _swiperController.swipe(CardSwiperDirection.left),
                      backgroundColor: Colors.redAccent,
                      child: const Icon(
                        Icons.close,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    
                    FloatingActionButton(
                      heroTag: 'play_pause',
                      onPressed: _togglePlayPause,
                      backgroundColor: Colors.white,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 35,
                        color: Colors.black,
                      ),
                    ),

                    FloatingActionButton(
                      heroTag: 'bop',
                      onPressed: () =>
                          _swiperController.swipe(CardSwiperDirection.right),
                      backgroundColor: Colors.greenAccent[400],
                      child: const Icon(
                        Icons.favorite,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
            color: Colors.black.withValues(alpha: 0.5),
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
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
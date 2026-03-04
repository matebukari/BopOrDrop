import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:async';

import '../../models/song_model.dart';
import 'widgets/song_card.dart';
import 'widgets/swipe_controls.dart';

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

    // Load the video and start playing at 0:45
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
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      // Just pause it
      _ytController.pauseVideo();
      setState(() => _isPlaying = false);
    } else {
      // If they press play...
      if (_previewFinished) {
        _loadAndPlayPreview(_currentVideoId); 
      } else {
        // NORMAL PLAY LOGIC: Just resume where they paused
        _ytController.playVideo();
        setState(() => _isPlaying = true);
      }
    }
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
  void dispose() {
    _playbackTimer?.cancel();
    _ytController.close();
    super.dispose();
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
                  child: Center(
                    child: const Text(
                      'BopOrDrop',
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: dummySongs.length,
                    onSwipe: _onSwipe,
                    allowedSwipeDirection:
                      const AllowedSwipeDirection.symmetric(horizontal: true),
                    cardBuilder: (context, index, percentX, percentY) {
                      return SongCard(song: dummySongs[index]);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                SwipeControls(
                  onDrop: () => _swiperController.swipe(CardSwiperDirection.left),
                  onBop: () => _swiperController.swipe(CardSwiperDirection.right),
                  onPlayPause: _togglePlayPause,
                  isPlaying: _isPlaying,
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
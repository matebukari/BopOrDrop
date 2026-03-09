import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:async';

import '../../models/song_model.dart';
import '../../models/playlist_model.dart';
import '../../services/youtube_service.dart';
import 'widgets/song_card.dart';
import 'widgets/swipe_controls.dart';
import 'widgets/discover_header.dart';
import 'widgets/empty_deck_view.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _storage = const FlutterSecureStorage();
  final CardSwiperController _swiperController = CardSwiperController();
  final YoutubeService _youtubeService = YoutubeService();
  late YoutubePlayerController _ytController;
  Timer? _playbackTimer;
  
  bool _isPlaying = true;
  bool _previewFinished = false; 
  String _currentVideoId = '';

  bool _isLoading = true;
  List<SongModel> _liveSongs = [];

  String? _nextPageToken;
  bool _isFetchingMore = false;

  bool _isDeckEmpty = false;

  List<PlaylistModel> _myPlaylists = [];
  String _selectedDestinationId = 'LIKED_MUSIC';
  String get _selectedPlaylistName {
    if (_selectedDestinationId == 'LIKED_MUSIC') {
      return '"Liked Music"';
    }
    try {
      final playlist = _myPlaylists.firstWhere((p) => p.id == _selectedDestinationId);
      return '"${playlist.title}"';
    } catch (e) {
      return 'selected playlist';
    }
  }

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
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Read their saved preference!
    String? savedPlaylistId = await _storage.read(key: 'preferred_save_destination');
    if (savedPlaylistId != null) {
      _selectedDestinationId = savedPlaylistId;
    }

    // Fetch their personal playlists for the dropdown
    final playlists = await _youtubeService.fetchMyPlaylists();
    if (mounted) {
      setState(() {
        _myPlaylists = playlists;
      });
    }
    // Load the initial deck
    _loadTrendingMusic();
  }

  Future<void> _loadTrendingMusic() async {
    final results = await _youtubeService.fetchTrendingMusic(targetPlaylistId: _selectedDestinationId);

    if (mounted) {
      setState(() {
        _liveSongs = results.songs;
        _nextPageToken = results.nextPageToken;
        _isLoading = false;
      });

      // Start the music if we actually got songs back
      if (_liveSongs.isNotEmpty) {
        _currentVideoId = _liveSongs[0].id;
        _loadAndPlayPreview(_currentVideoId);
      }

      if (_liveSongs.length < 15 && _nextPageToken != null) {
        _fetchMoreMusic();
      }
    }
  }

  // The function that secretly grabs more songs in the background
  Future<void> _fetchMoreMusic() async {
    if (_isFetchingMore || _nextPageToken == null) return;

    setState(() {
      _isFetchingMore = true;
    });

    final result = await _youtubeService.fetchTrendingMusic(pageToken: _nextPageToken, targetPlaylistId: _selectedDestinationId);

    if (mounted) {
      setState(() {
        _liveSongs.addAll(result.songs);
        _nextPageToken = result.nextPageToken;
        _isFetchingMore = false;
      });
    }

    if ((result.songs.isEmpty || _liveSongs.length < 15) && _nextPageToken != null) {
      _fetchMoreMusic();
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
    });
  }

  void _togglePlayPause() {
    if (_isLoading || _liveSongs.isEmpty || _isDeckEmpty) return;

    if (_isPlaying) {
      _ytController.pauseVideo();
      setState(() => _isPlaying = false);
    } else {
      if (_previewFinished) {
        _loadAndPlayPreview(_currentVideoId); 
      } else {
        _ytController.playVideo();
        setState(() => _isPlaying = true);
      }
    }
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    final swipedSong = _liveSongs[previousIndex];

    if (direction == CardSwiperDirection.right) {
      _youtubeService.saveSong(swipedSong, _selectedDestinationId);
    } else if (direction == CardSwiperDirection.left) {
      _youtubeService.dropSong(swipedSong.id);
    }

    if (currentIndex != null) {
      // If the user is 10 cards away from the end of the deck, go fetch more!
      if (currentIndex >= _liveSongs.length - 10) {
        _fetchMoreMusic();
      }

      if (currentIndex < _liveSongs.length) {
        _currentVideoId = _liveSongs[currentIndex].id;
        _loadAndPlayPreview(_currentVideoId);
      }
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

  bool _onUndo(int? previousIndex, int currentIndex, CardSwiperDirection direction) {
    if (currentIndex < _liveSongs.length) {
      _currentVideoId = _liveSongs[currentIndex].id;
      _loadAndPlayPreview(_currentVideoId);

      // Undo Router
      if (direction == CardSwiperDirection.right) {
        _youtubeService.unsaveSong(_currentVideoId, _selectedDestinationId);
      } else if (direction == CardSwiperDirection.left) {
        _youtubeService.undropSong(_currentVideoId);
      }

      if (_isDeckEmpty) {
        setState(() => _isDeckEmpty = false);
      }
    }
    return true;
  }

  Future<void> _onDestinationChanged(String? newValue) async {
    if (newValue != null && newValue != _selectedDestinationId) {
      // Save their choice to the phone's memory permanently
      await _storage.write(key: 'preferred_save_destination', value: newValue);

      setState(() {
        _selectedDestinationId = newValue;
      });
    }
  }

  void _onDeckEmpty() {
    setState(() => _isDeckEmpty = true);
    _ytController.pauseVideo();
    _playbackTimer?.cancel();
  }
  
  Widget _buildBottomControls() {
    if (_isDeckEmpty || _liveSongs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 20),
        SwipeControls(
          isPlaying: _isPlaying,
          onDrop: () => _swiperController.swipe(CardSwiperDirection.left),
          onBop: () => _swiperController.swipe(CardSwiperDirection.right),
          onPlayPause: _togglePlayPause,
          onUndo: () => _swiperController.undo(),
        ),
        const SizedBox(height: 40),
      ],
    );
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
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedDestinationId,
            dropdownColor: const Color(0xFF1E1E1E),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            items: [
              // The default "Liked Music" option
              const DropdownMenuItem(
                value: 'LIKED_MUSIC',
                child: Text('Liked Music'),
              ),
              // Map their actual YouTube playlists
              ..._myPlaylists.map((playlist) {
                return DropdownMenuItem(
                  value: playlist.id,
                  child: Text(playlist.title),
                );
              }),
            ],
            onChanged: _onDestinationChanged,
          ),
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
                DiscoverHeader(playlistName: _selectedPlaylistName),

                const SizedBox(height: 10),

                Expanded(
                  child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                    : _isDeckEmpty
                      ? const EmptyDeckView()
                      : _liveSongs.isEmpty
                        ? const Center(child: Text("No songs found.", style: TextStyle(color: Colors.white)))
                        : CardSwiper(
                            controller: _swiperController,
                            cardsCount: _liveSongs.length,
                            numberOfCardsDisplayed: _liveSongs.length == 1 ? 1 : 2,
                            isLoop: false,
                            onEnd: _onDeckEmpty,                            
                            onSwipe: _onSwipe,
                            onUndo: _onUndo,
                            allowedSwipeDirection: const AllowedSwipeDirection.symmetric(horizontal: true),
                            cardBuilder: (context, index, percentX, percentY) {
                              return SongCard(song: _liveSongs[index]); 
                            },
                          ),
                ),
                _buildBottomControls(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
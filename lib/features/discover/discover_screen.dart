import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
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
  State<DiscoverScreen> createState() => DiscoverScreenState();
}

class DiscoverScreenState extends State<DiscoverScreen> {
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

  String _selectedDestinationId = '';

  String get _selectedPlaylistName {
    if (_myPlaylists.isEmpty || _selectedDestinationId.isEmpty) {
      return '"Your Playlist"';
    }
    try {
      final playlist = _myPlaylists.firstWhere(
        (p) => p.id == _selectedDestinationId,
      );
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
    // 1. Fetch their personal playlists first
    final playlists = await _youtubeService.fetchUserPlaylists();
    if (mounted) {
      setState(() {
        _myPlaylists = playlists;
      });
    }

    // 2. Figure out which playlist to select
    String? savedPlaylistId = await _storage.read(
      key: 'preferred_save_destination',
    );
    bool playlistStillExists = playlists.any((p) => p.id == savedPlaylistId);

    if (mounted) {
      setState(() {
        if (savedPlaylistId != null && playlistStillExists) {
          _selectedDestinationId = savedPlaylistId;
        } else if (playlists.isNotEmpty) {
          // If no save preference, default to their very first custom playlist
          _selectedDestinationId = playlists.first.id;
          _storage.write(
            key: 'preferred_save_destination',
            value: _selectedDestinationId,
          );
        }
      });
    }

    // 3. Now fetch the music!
    await _loadTrendingMusic();
  }

  Future<void> _loadTrendingMusic() async {
    final cachedSongs = await _youtubeService.getCachedDeck();

    if (cachedSongs.isNotEmpty && mounted) {
      precacheImage(NetworkImage(cachedSongs[0].coverArtUrl), context);
      setState(() {
        _liveSongs = cachedSongs;
        _isLoading = false;
      });

      _currentVideoId = _liveSongs[0].id;
      _loadAndPlayPreview(_currentVideoId);
    }

    final results = await _youtubeService.fetchTrendingMusic(
      targetPlaylistId: _selectedDestinationId,
    );

    if (mounted) {
      for (var song in results.songs.take(3)) {
        precacheImage(NetworkImage(song.coverArtUrl), context);
      }

      setState(() {
        // If we had cached songs, append the new ones. Otherwise, just use the new ones.
        if (cachedSongs.isNotEmpty) {
          final existingIds = _liveSongs.map((s) => s.id).toSet();
          final newSongs = results.songs
              .where((s) => !existingIds.contains(s.id))
              .toList();
          _liveSongs.addAll(newSongs);
        } else {
          _liveSongs = results.songs;
        }

        _nextPageToken = results.nextPageToken;
        _isLoading = false;
      });

      // If we didn't have a cache, start playing the freshly fetched song now
      if (cachedSongs.isEmpty && _liveSongs.isNotEmpty) {
        _currentVideoId = _liveSongs[0].id;
        _loadAndPlayPreview(_currentVideoId);
      }
    }
  }

  // The function that secretly grabs more songs in the background
  Future<void> _fetchMoreMusic() async {
    if (_isFetchingMore || _nextPageToken == null) return;

    setState(() {
      _isFetchingMore = true;
    });

    final result = await _youtubeService.fetchTrendingMusic(
      pageToken: _nextPageToken,
      targetPlaylistId: _selectedDestinationId,
    );

    if (mounted) {
      setState(() {
        _liveSongs.addAll(result.songs);
        _nextPageToken = result.nextPageToken;
        _isFetchingMore = false;
      });
    }

    if ((result.songs.isEmpty || _liveSongs.length < 15) &&
        _nextPageToken != null) {
      _fetchMoreMusic();
    }
  }

  void _loadAndPlayPreview(String videoId) async {
    if (videoId.isEmpty) return;

    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = true;
      _previewFinished = false;
    });

    try {
      await _ytController.loadVideoById(videoId: videoId, startSeconds: 45);
      _ytController.playVideo();
      _startPreviewTimer();
    } catch (e) {
      print('BOP DEBUG: YouTube Player not ready to load yet: $e');
    }
  }

  void _startPreviewTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer(const Duration(seconds: 30), () {
      try {
        _ytController.pauseVideo();
      } catch (e) {
        // Silently catch
      }

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

  void pauseMusicSilently() {
    if (_isPlaying) {
      try {
        _ytController.pauseVideo();
      } catch (e) {
        // Silently catch
      }
      setState(() {
        _isPlaying = false;
      });
    }
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final swipedSong = _liveSongs[previousIndex];

    if (direction == CardSwiperDirection.right) {
      _youtubeService.saveSong(swipedSong, _selectedDestinationId);
    } else if (direction == CardSwiperDirection.left) {
      _youtubeService.dropSong(swipedSong);
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
      try {
        _ytController.pauseVideo();
      } catch (e) {
        // Silently catch
      }
      _playbackTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _previewFinished = false;
      });
    }
    return true;
  }

  bool _onUndo(
    int? previousIndex,
    int currentIndex,
    CardSwiperDirection direction,
  ) {
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
    try {
      _ytController.pauseVideo();
    } catch (e) {
      // Silently catch
    }
    _playbackTimer?.cancel();
  }

  Future<void> _openInYouTube() async {
    if (_currentVideoId.isEmpty) return;

    // Pause the app's preview since they are leaving the app
    if (_isPlaying) {
      _togglePlayPause();
    }

    final url = Uri.parse('https://www.youtube.com/watch?v=$_currentVideoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
          onOpenYouTube: _openInYouTube,
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
            value: _selectedDestinationId.isEmpty
                ? null
                : _selectedDestinationId,
            dropdownColor: const Color(0xFF1E1E1E),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            items: _myPlaylists.isEmpty
                ? [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No Playlists Found'),
                    ),
                  ]
                : [
                    // Map their actual YouTube playlists
                    ..._myPlaylists.map((playlist) {
                      return DropdownMenuItem(
                        value: playlist.id,
                        child: Text(playlist.title),
                      );
                    }),

                    // Temporarily inject the saved ID so Flutter doesn't crash while loading
                    if (_selectedDestinationId.isNotEmpty &&
                        !_myPlaylists.any(
                          (p) => p.id == _selectedDestinationId,
                        ))
                      DropdownMenuItem(
                        value: _selectedDestinationId,
                        child: const Text('Loading...'),
                      ),
                  ],
            onChanged: _onDestinationChanged,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_currentVideoId.isNotEmpty)
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
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.greenAccent,
                          ),
                        )
                      : _isDeckEmpty
                      ? const EmptyDeckView()
                      : _liveSongs.isEmpty
                      ? const Center(
                          child: Text(
                            "No songs found.",
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : CardSwiper(
                          controller: _swiperController,
                          cardsCount: _liveSongs.length,
                          numberOfCardsDisplayed: _liveSongs.length == 1
                              ? 1
                              : 2,
                          isLoop: false,
                          onEnd: _onDeckEmpty,
                          onSwipe: _onSwipe,
                          onUndo: _onUndo,
                          allowedSwipeDirection:
                              const AllowedSwipeDirection.symmetric(
                                horizontal: true,
                              ),
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

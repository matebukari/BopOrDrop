class SongModel {
  final String id;
  final String title;
  final String artist;
  final String coverArtUrl;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverArtUrl,
  });
}

// DUMMY DATA: Now with real YouTube Video IDs!
final List<SongModel> dummySongs = [
  SongModel(
    id: 'K4DyBUG242c',
    title: 'On & On',
    artist: 'Cartoon',
    coverArtUrl: 'https://img.youtube.com/vi/K4DyBUG242c/hqdefault.jpg', 
  ),
  SongModel(
    id: 'jfKfPfyJRdk',
    title: 'Lofi Test',
    artist: 'Test Artist',
    coverArtUrl: 'https://img.youtube.com/vi/jfKfPfyJRdk/hqdefault.jpg', 
  ),
  SongModel(
    id: '4NRXx6U8ABQ', 
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    coverArtUrl: 'https://img.youtube.com/vi/4NRXx6U8ABQ/hqdefault.jpg', // Changed here
  ),
  SongModel(
    id: 'TUVcZfQe-Kw', 
    title: 'Levitating',
    artist: 'Dua Lipa',
    coverArtUrl: 'https://img.youtube.com/vi/TUVcZfQe-Kw/hqdefault.jpg', // Changed here
  ),
  SongModel(
    id: 'ic8j13piAhQ', 
    title: 'Cruel Summer',
    artist: 'Taylor Swift',
    coverArtUrl: 'https://img.youtube.com/vi/ic8j13piAhQ/hqdefault.jpg', // Changed here
  ),
];
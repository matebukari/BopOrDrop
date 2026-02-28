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

// DUMMY DATA:
final List<SongModel> dummySongs = [
  SongModel(
    id: '1',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    coverArtUrl: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36', 
  ),
  SongModel(
    id: '2',
    title: 'Levitating',
    artist: 'Dua Lipa',
    coverArtUrl: 'https://i.scdn.co/image/ab67616d0000b273bd26ede1ae69327010d49946',
  ),
  SongModel(
    id: '3',
    title: 'Cruel Summer',
    artist: 'Taylor Swift',
    coverArtUrl: 'https://i.scdn.co/image/ab67616d0000b273e787cffec20aa2a396a61647',
  ),
];
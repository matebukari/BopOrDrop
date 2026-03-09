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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'coverArtUrl': coverArtUrl,
  };

  factory SongModel.fromJson(Map<String, dynamic> json) => SongModel(
    id: json['id'],
    title: json['title'],
    artist: json['artist'],
    coverArtUrl: json['coverArtUrl'],
  );
}
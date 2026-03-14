class SongModel {
  final String id;
  final String title;
  final String artist;
  final String coverArtUrl;
  final String? savedPlaylistId;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverArtUrl,
    this.savedPlaylistId,
  });

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? coverArtUrl,
    String? savedPlaylistId,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      savedPlaylistId: savedPlaylistId ?? this.savedPlaylistId,
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      coverArtUrl: json['coverArtUrl'],
      savedPlaylistId: json['savedPlaylistId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'coverArtUrl': coverArtUrl,
    'savedPlaylistId': savedPlaylistId,
  };
}
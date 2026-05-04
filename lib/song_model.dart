import 'package:on_audio_query/on_audio_query.dart';

class SongModelSimple {
  final int id;
  final String title;
  final String artist;
  final String uri;
  final int duration;

  SongModelSimple({
    required this.id,
    required this.title,
    required this.artist,
    required this.uri,
    required this.duration,
  });

  factory SongModelSimple.fromOnAudioQuery(SongModel song) {
    return SongModelSimple(
      id: song.id,
      title: song.title,
      artist: song.artist ?? 'Artista Desconocido',
      uri: song.uri ?? '',
      duration: song.duration ?? 0,
    );
  }

  String get formattedDuration {
    final durationInSeconds = duration ~/ 1000;
    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

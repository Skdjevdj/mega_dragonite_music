import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mega Dragonite Music',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      debugShowCheckedModeBanner: false,
      home: const MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<SongModel> _songs = [];
  bool _isPermissionGranted = false;
  bool _isLoading = true;
  int _currentIndex = -1;

  Stream<Duration> get _positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get _durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get _playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get _isPlayingStream =>
      _playerStateStream.map((state) => state.playing);

  @override
  void initState() {
    super.initState();
    _setupEdgeToEdge();
    _checkPermissionsAndLoadSongs();
    _setupAudioPlayerListeners();
  }

  void _setupEdgeToEdge() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _checkPermissionsAndLoadSongs() async {
    await Permission.storage.request();
    
    if (await _audioQuery.permissionsStatus()) {
      setState(() => _isPermissionGranted = true);
      await _loadSongs();
    } else {
      setState(() => _isLoading = false);
      _showPermissionDialog();
    }
  }

  Future<void> _loadSongs() async {
    try {
      List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _nextSong();
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permiso Necesario'),
        content: const Text('Necesitamos acceso a tu almacenamiento para mostrar tus canciones.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermissionsAndLoadSongs();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    try {
      SongModel song = _songs[index];
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      await _audioPlayer.play();
      setState(() => _currentIndex = index);
    } catch (e) {}
  }

  void _nextSong() {
    if (_songs.isEmpty) return;
    _playSong((_currentIndex + 1) % _songs.length);
  }

  void _previousSong() {
    if (_songs.isEmpty) return;
    _playSong(_currentIndex - 1 < 0 ? _songs.length - 1 : _currentIndex - 1);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  String getSongDuration(int milliseconds) {
    Duration duration = Duration(milliseconds: milliseconds);
    return _formatDuration(duration);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A4D4D), Color(0xFF0F2E2E), Color(0xFF0A4A4A)],
        ),
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00))))
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_isPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off, size: 64, color: Color(0xFFF5DEB3)),
            const SizedBox(height: 16),
            const Text('Sin acceso a las canciones', style: TextStyle(color: Color(0xFFF5DEB3), fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPermissionsAndLoadSongs,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00)),
              child: const Text('Conceder Permiso'),
            ),
          ],
        ),
      );
    }
    if (_songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 64, color: Color(0xFFF5DEB3)),
            SizedBox(height: 16),
            Text('No se encontraron canciones', style: TextStyle(color: Color(0xFFF5DEB3), fontSize: 16)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(flex: 2, child: _buildPlayerControls()),
        Expanded(flex: 3, child: _buildSongList()),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFF1A4D4D).withOpacity(0.7),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(6, 6), blurRadius: 12),
            BoxShadow(color: const Color(0xFF2A6D6D).withOpacity(0.5), offset: const Offset(-4, -4), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentIndex != -1) ...[
              const Icon(Icons.audiotrack, size: 60, color: Color(0xFFF5DEB3)),
              const SizedBox(height: 16),
              Text(_songs[_currentIndex].title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF5DEB3)), maxLines: 1),
              Text(_songs[_currentIndex].artist ?? 'Desconocido', style: const TextStyle(fontSize: 14, color: Color(0xFFF5DEB3)), maxLines: 1),
            ] else ...[
              const Icon(Icons.music_note, size: 60, color: Color(0xFFF5DEB3)),
              const SizedBox(height: 16),
              const Text('Selecciona una canción', style: TextStyle(fontSize: 18, color: Color(0xFFF5DEB3))),
            ],
            const SizedBox(height: 24),
            StreamBuilder<Duration?>(
              stream: _durationStream,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    return Column(
                      children: [
                        Slider(
                          value: position.inMilliseconds.toDouble(),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (value) => _audioPlayer.seek(Duration(milliseconds: value.toInt())),
                          activeColor: const Color(0xFFFF8C00),
                          inactiveColor: const Color(0xFFF5DEB3).withOpacity(0.3),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position), style: const TextStyle(color: Color(0xFFF5DEB3))),
                              Text(_formatDuration(duration), style: const TextStyle(color: Color(0xFFF5DEB3))),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNeumorphicButton(Icons.skip_previous, _previousSong, 50),
                const SizedBox(width: 24),
                StreamBuilder<bool>(
                  stream: _isPlayingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFFF8C00).withOpacity(0.6), blurRadius: 20, spreadRadius: 5)],
                      ),
                      child: FloatingActionButton(
                        onPressed: () {
                          if (_currentIndex == -1 && _songs.isNotEmpty) _playSong(0);
                          else if (isPlaying) _audioPlayer.pause();
                          else _audioPlayer.play();
                        },
                        backgroundColor: const Color(0xFFFF8C00),
                        child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 24),
                _buildNeumorphicButton(Icons.skip_next, _nextSong, 50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicButton(IconData icon, VoidCallback onPressed, double size) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(4, 4), blurRadius: 8),
          BoxShadow(color: const Color(0xFF2A6D6D).withOpacity(0.5), offset: const Offset(-2, -2), blurRadius: 6),
        ],
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFF1A4D4D),
        child: IconButton(icon: Icon(icon, color: const Color(0xFFFF8C00), size: size * 0.5), onPressed: onPressed),
      ),
    );
  }

  Widget _buildSongList() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        color: Color(0xFF0F2E2E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tu Biblioteca', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF5DEB3))),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                final isSelected = _currentIndex == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSelected ? const Color(0xFFFF8C00).withOpacity(0.2) : Colors.transparent,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? const Color(0xFFFF8C00) : const Color(0xFF1A4D4D),
                      child: Icon(Icons.music_note, color: isSelected ? Colors.white : const Color(0xFFF5DEB3)),
                    ),
                    title: Text(song.title, style: TextStyle(color: isSelected ? const Color(0xFFFF8C00) : const Color(0xFFF5DEB3), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(song.artist ?? 'Desconocido', style: const TextStyle(color: Color(0xFFF5DEB3))),
                    trailing: Text(getSongDuration(song.duration!), style: const TextStyle(color: Color(0xFFF5DEB3))),
                    onTap: () => _playSong(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

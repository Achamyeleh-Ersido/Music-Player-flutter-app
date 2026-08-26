import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/firebase_options.dart';
import 'package:just_audio/just_audio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AuraApp());
}

//void main() => runApp(const AuraApp());

class AuraApp extends StatelessWidget {
  const AuraApp({super.key, this.enableAudio = true});

  final bool enableAudio;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Aura',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'sans-serif',
      scaffoldBackgroundColor: const Color(0xFF11141F),
    ),
    home: PlayerScreen(enableAudio: enableAudio),
  );
}

class Track {
  const Track({
    required this.title,
    required this.artist,
    required this.album,
    required this.url,
    required this.colors,
    required this.durationLabel,
  });

  final String title;
  final String artist;
  final String album;
  final String url;
  final List<Color> colors;
  final String durationLabel;
}

const _tracks = [
  Track(
    title: 'Afterglow',
    artist: 'The Late Nights',
    album: 'Echoes',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    colors: [
      Color.fromARGB(255, 227, 224, 225),
      Color.fromARGB(255, 7, 3, 23),
      Color.fromARGB(255, 216, 219, 223),
    ],
    durationLabel: '3:52',
  ),
  Track(
    title: 'Neon Skies',
    artist: 'Mira Sol',
    album: 'City Lights',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    colors: [
      Color.fromARGB(255, 145, 134, 128),
      Color(0xFFD23C88),
      Color(0xFF302063),
    ],
    durationLabel: '4:16',
  ),
  Track(
    title: 'Slow Motion',
    artist: 'Rhea & Co.',
    album: 'Undercurrent',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    colors: [Color(0xFF1FB8AF), Color(0xFF2873A5), Color(0xFF18234B)],
    durationLabel: '3:41',
  ),
  Track(
    title: 'Open Water',
    artist: 'Aster',
    album: 'Blue Hours',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    colors: [Color(0xFF52A6ED), Color(0xFF4451B8), Color(0xFF24205B)],
    durationLabel: '4:04',
  ),
];

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, this.enableAudio = true});

  final bool enableAudio;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  final Set<int> _likedTrackIndexes = <int>{};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final AnimationController _artController;

  int _selectedTab = 0;
  int _trackIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLooping = false;
  bool _isShuffle = false;
  bool _isLoading = true;

  Track get _track => _tracks[_trackIndex];
  bool get _isLiked => _likedTrackIndexes.contains(_trackIndex);

  @override
  void initState() {
    super.initState();
    _artController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.enableAudio) {
      _listenToPlayer();
      _loadPlaylist();
    } else {
      _isLoading = false;
    }
  }

  void _listenToPlayer() {
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isPlaying = state.playing);
        if (state.playing) {
          _artController.repeat();
        } else {
          _artController.stop();
        }
      }),
    );
    _subscriptions.add(
      _player.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (mounted && duration != null) setState(() => _duration = duration);
      }),
    );
    _subscriptions.add(
      _player.currentIndexStream.listen((index) {
        if (mounted && index != null) {
          setState(() {
            _trackIndex = index;
            _position = Duration.zero;
          });
        }
      }),
    );
    _subscriptions.add(
      _player.errorStream.listen((error) {
        if (mounted) {
          _toast('Could not play this track. Check your connection.');
        }
      }),
    );
  }

  Future<void> _loadPlaylist() async {
    try {
      await _player.setAudioSources([
        for (final track in _tracks) AudioSource.uri(Uri.parse(track.url)),
      ]);
    } catch (_) {
      if (mounted) _toast('Audio is unavailable right now.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _artController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _togglePlayback() async {
    if (_isLoading) return;
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) _toast('Playback could not start. Check your connection.');
    }
  }

  Future<void> _skip(int direction) async {
    try {
      if (direction > 0 && _player.hasNext) {
        await _player.seekToNext();
      } else if (direction < 0 && _player.hasPrevious) {
        await _player.seekToPrevious();
      } else {
        await _player.seek(Duration.zero);
        _toast(
          direction > 0 ? 'You are at the end of the queue' : 'Restarted track',
        );
      }
    } catch (_) {
      _toast('The queue is still loading.');
    }
  }

  Future<void> _playTrack(int index) async {
    setState(() => _selectedTab = 0);
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (_) {
      _toast('This track is not ready yet.');
    }
  }

  Future<void> _setShuffle() async {
    final enabled = !_isShuffle;
    setState(() => _isShuffle = enabled);
    try {
      if (enabled) await _player.shuffle();
      await _player.setShuffleModeEnabled(enabled);
      _toast(enabled ? 'Shuffle is on' : 'Shuffle is off');
    } catch (_) {
      _toast('Shuffle will be ready once the queue loads.');
    }
  }

  Future<void> _setLoop() async {
    final enabled = !_isLooping;
    setState(() => _isLooping = enabled);
    await _player.setLoopMode(enabled ? LoopMode.all : LoopMode.off);
    _toast(enabled ? 'Repeating queue' : 'Repeat is off');
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF242738),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: const Text('Open queue'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openQueue();
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Share track'),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: '${_track.title} — ${_track.artist} on Aura',
                    ),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  _toast('Track details copied to your clipboard');
                },
              ),
              ListTile(
                leading: Icon(
                  _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                title: Text(
                  _isLiked ? 'Remove from favorites' : 'Add to favorites',
                ),
                onTap: () {
                  setState(() {
                    if (_isLiked) {
                      _likedTrackIndexes.remove(_trackIndex);
                    } else {
                      _likedTrackIndexes.add(_trackIndex);
                    }
                  });
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202333),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 430,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Up next',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text('4 songs', style: TextStyle(color: Color(0xFFB2B6C7))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _tracks.length,
                  itemBuilder: (_, index) => _TrackTile(
                    track: _tracks[index],
                    active: index == _trackIndex,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _playTrack(index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF202342), Color(0xFF11141F), Color(0xFF0E1018)],
          stops: [0, .52, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              title: _selectedTab == 0
                  ? 'NOW PLAYING'
                  : ['HOME', 'DISCOVER', 'LIBRARY', 'PROFILE'][_selectedTab],
              subtitle: _selectedTab == 0 ? _track.album : 'Aura music Zone',
              onClose: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  _toast('You are already on the player');
                }
              },
              onMore: _openMenu,
            ),
            Expanded(child: _buildBody()),
            _BottomNavigation(
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildBody() {
    switch (_selectedTab) {
      case 1:
        return _DiscoverView(onPlay: _playTrack);
      case 2:
        return _LibraryView(
          likedIndexes: _likedTrackIndexes,
          onPlay: _playTrack,
          onBrowse: () => setState(() => _selectedTab = 1),
        );
      case 3:
        return const _ProfileView();
      default:
        return _NowPlayingView(
          track: _track,
          isPlaying: _isPlaying,
          isLiked: _isLiked,
          isLooping: _isLooping,
          isShuffle: _isShuffle,
          isLoading: _isLoading,
          position: _position,
          duration: _duration,
          artAnimation: _artController,
          onLike: () => setState(() {
            if (_isLiked) {
              _likedTrackIndexes.remove(_trackIndex);
            } else {
              _likedTrackIndexes.add(_trackIndex);
            }
          }),
          onSeek: (value) =>
              _player.seek(Duration(milliseconds: value.toInt())),
          onPlay: _togglePlayback,
          onLoop: _setLoop,
          onShuffle: _setShuffle,
          onSkip: _skip,
          onQuality: () => _toast('Streaming at the highest available quality'),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onMore,
  });
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: onClose,
          tooltip: 'Minimize player',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  color: Color(0xFFAAAFC4),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onMore,
          tooltip: 'More actions',
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    ),
  );
}

class _NowPlayingView extends StatelessWidget {
  const _NowPlayingView({
    required this.track,
    required this.isPlaying,
    required this.isLiked,
    required this.isLooping,
    required this.isShuffle,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.artAnimation,
    required this.onLike,
    required this.onSeek,
    required this.onPlay,
    required this.onLoop,
    required this.onShuffle,
    required this.onSkip,
    required this.onQuality,
  });
  final Track track;
  final bool isPlaying, isLiked, isLooping, isShuffle, isLoading;
  final Duration position, duration;
  final Animation<double> artAnimation;
  final VoidCallback onLike, onPlay, onLoop, onShuffle, onQuality;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onSkip;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, compact ? 8 : 20, 24, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: artAnimation,
              builder: (context, child) => Transform.rotate(
                angle: artAnimation.value * math.pi * 2,
                child: child,
              ),
              child: AlbumArtwork(track: track),
            ),
            SizedBox(height: compact ? 24 : 36),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${track.artist}  •  ${track.album}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFA8ADC0),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onLike,
                  tooltip: isLiked
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  icon: Icon(
                    isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isLiked
                        ? const Color(0xFFFF6D9B)
                        : const Color(0xFFD3D6E3),
                    size: 27,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _ProgressSection(
              position: position,
              duration: duration,
              onChanged: onSeek,
            ),
            const SizedBox(height: 16),
            _Controls(
              isPlaying: isPlaying,
              isLooping: isLooping,
              isShuffle: isShuffle,
              isLoading: isLoading,
              onPlay: onPlay,
              onLoop: onLoop,
              onShuffle: onShuffle,
              onSkip: onSkip,
            ),
            const SizedBox(height: 22),
            _QualityCard(onTap: onQuality),
          ],
        ),
      ),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 48, 335.0);
    return Container(
      width: width,
      height: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
          BoxShadow(color: Color(0x33148CFF), blurRadius: 50, spreadRadius: 4),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: track.colors,
              ),
            ),
          ),
          Positioned(
            top: -width * .22,
            right: -width * .12,
            child: _GlowOrb(size: width * .78, color: const Color(0xFFFFB35B)),
          ),
          Positioned(
            bottom: -width * .24,
            left: -width * .18,
            child: _GlowOrb(size: width * .84, color: const Color(0xFF00C2FF)),
          ),
          Positioned(
            right: width * .1,
            bottom: width * .11,
            child: Transform.rotate(
              angle: -.35,
              child: Icon(
                Icons.bolt_rounded,
                size: width * .58,
                color: const Color(0xFFFFD082),
              ),
            ),
          ),
          Container(color: const Color(0x2206162D)),
          Positioned(
            left: 22,
            bottom: 19,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.album.toUpperCase(),
                  style: TextStyle(
                    fontSize: width * .13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: .82,
                  ),
                ),
                Text(
                  track.artist.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 18,
            left: 19,
            child: Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white70,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.position,
    required this.duration,
    required this.onChanged,
  });
  final Duration position, duration;
  final ValueChanged<double> onChanged;

  String _format(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final max = math.max(duration.inMilliseconds.toDouble(), 1.0);
    final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
            activeTrackColor: const Color(0xFFFA7EAD),
            inactiveTrackColor: const Color(0xFF474C61),
            thumbColor: const Color(0xFFFFF5F8),
          ),
          child: Slider(
            value: value,
            max: max,
            onChanged: duration == Duration.zero ? null : onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(position),
                style: const TextStyle(fontSize: 12, color: Color(0xFFB1B5C6)),
              ),
              Text(
                duration == Duration.zero
                    ? '--:--'
                    : '-${_format(duration - position)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB1B5C6)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.account_circle_rounded, size: 100, color: Color(0xFFB4B8C9)),
        SizedBox(height: 16),
        Text(
          'Profile',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.isLooping,
    required this.isShuffle,
    required this.isLoading,
    required this.onPlay,
    required this.onLoop,
    required this.onShuffle,
    required this.onSkip,
  });
  final bool isPlaying, isLooping, isShuffle, isLoading;
  final VoidCallback onPlay, onLoop, onShuffle;
  final ValueChanged<int> onSkip;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _SmallControl(
        icon: Icons.shuffle_rounded,
        tooltip: 'Shuffle queue',
        selected: isShuffle,
        onTap: onShuffle,
      ),
      IconButton(
        onPressed: () => onSkip(-1),
        tooltip: 'Previous track',
        icon: const Icon(Icons.skip_previous_rounded, size: 43),
      ),
      GestureDetector(
        onTap: isLoading ? null : onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEF4),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x55FF72A7),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(23),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF242638),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: const Color(0xFF242638),
                  size: 39,
                ),
        ),
      ),
      IconButton(
        onPressed: () => onSkip(1),
        tooltip: 'Next track',
        icon: const Icon(Icons.skip_next_rounded, size: 43),
      ),
      _SmallControl(
        icon: Icons.repeat_rounded,
        tooltip: 'Repeat queue',
        selected: isLooping,
        onTap: onLoop,
      ),
    ],
  );
}

class _SmallControl extends StatelessWidget {
  const _SmallControl({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    icon: Icon(
      icon,
      size: 22,
      color: selected ? const Color(0xFFFF7DAC) : const Color(0xFFB4B8C9),
    ),
  );
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF232637),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF363A50)),
      ),
      child: const Row(
        children: [
          Icon(Icons.high_quality_rounded, color: Color(0xFFB7A5FF)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'High quality audio',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'Adaptive',
            style: TextStyle(fontSize: 12, color: Color(0xFFADB1C2)),
          ),
        ],
      ),
    ),
  );
}

class _DiscoverView extends StatelessWidget {
  const _DiscoverView({required this.onPlay});
  final ValueChanged<int> onPlay;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
    children: [
      const Text(
        'Find your next sound',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Fresh music picked for your night.',
        style: TextStyle(color: Color(0xFFA8ADC0)),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 156,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _tracks.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, index) =>
              _DiscoverCard(track: _tracks[index], onTap: () => onPlay(index)),
        ),
      ),
      const SizedBox(height: 26),
      const Text(
        'Made for you',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 9),
      for (var i = 0; i < _tracks.length; i++)
        _TrackTile(track: _tracks[i], onTap: () => onPlay(i)),
    ],
  );
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: track.colors),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded, size: 42),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFFA8ADC0)),
          ),
        ],
      ),
    ),
  );
}

class _LibraryView extends StatelessWidget {
  const _LibraryView({
    required this.likedIndexes,
    required this.onPlay,
    required this.onBrowse,
  });
  final Set<int> likedIndexes;
  final ValueChanged<int> onPlay;
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
    children: [
      const Text(
        'Your library',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF29243C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF83B2),
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liked songs',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${likedIndexes.length} saved ${likedIndexes.length == 1 ? 'song' : 'songs'}',
                    style: const TextStyle(color: Color(0xFFA8ADC0)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (likedIndexes.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 42),
            child: Column(
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  size: 48,
                  color: Color(0xFF858A9F),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No favorites yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Save songs you love and find them here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA8ADC0)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onBrowse,
                  child: const Text('Discover music'),
                ),
              ],
            ),
          ),
        )
      else ...[
        const Text(
          'Favorites',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final index in likedIndexes)
          _TrackTile(track: _tracks[index], onTap: () => onPlay(index)),
      ],
    ],
  );
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    this.active = false,
  });
  final Track track;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
    onTap: onTap,
    leading: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: track.colors),
      ),
      child: Icon(
        active ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
      ),
    ),
    title: Text(
      track.title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: active ? const Color(0xFFFF91BC) : null,
      ),
    ),
    subtitle: Text(track.artist),
    trailing: Text(
      track.durationLabel,
      style: const TextStyle(fontSize: 12, color: Color(0xFFA8ADC0)),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_rounded,
      Icons.explore_rounded,
      Icons.library_music_rounded,
      Icons.account_circle_rounded,
    ];
    const labels = ['Home', 'Discover', 'Library', 'Profile'];
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 13),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD9232636),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (index) {
          final selected = index == selectedIndex;
          return InkWell(
            onTap: () => onChanged(index),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF494362) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    icons[index],
                    color: selected
                        ? const Color.fromARGB(255, 62, 56, 58)
                        : const Color(0xFFB4B8C9),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

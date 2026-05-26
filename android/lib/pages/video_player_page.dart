import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_client.dart';

class VideoPlayerPage extends StatefulWidget {
  final String? videoUuid;
  const VideoPlayerPage({super.key, this.videoUuid});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _video;
  Player? _player;
  VideoController? _videoController;
  bool _loading = true;
  String? _error;
  bool _isPlaying = false;
  StreamSubscription<bool>? _playSub;

  String get _videoUrl {
    final token = _api.token ?? '';
    return '${_api.serverUrl}/api/videos/${widget.videoUuid}/stream?token=$token';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.videoUuid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // Check local download first
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/downloads/${widget.videoUuid}.mp4';
    if (await File(localPath).exists()) {
      await _initPlayer(localPath: localPath);
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final v = await _api.getVideoDetail(widget.videoUuid!);
      if (!mounted) return;
      setState(() => _video = v);
      await _initPlayer();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载视频信息失败';
        });
      }
    }
  }

  Future<void> _initPlayer({String? localPath}) async {
    try {
      _player = Player();
      _videoController = VideoController(_player!);
      _playSub = _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });

      if (localPath != null) {
        await _player!.open(Media('file://$localPath'));
      } else {
        await _player!.open(Media(
          _videoUrl,
          httpHeaders: _api.token != null
              ? {'Authorization': 'Bearer ${_api.token}'}
              : null,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '视频加载失败: $e');
    }
  }

  void _togglePlay() {
    if (_player == null) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  void _toggleFullscreen() {
    if (_player == null) return;
    final wasPlaying = _isPlaying;
    if (wasPlaying) _player!.pause();

    _videoController = null;
    Navigator.of(context)
        .push(
      PageRouteBuilder(
        pageBuilder: (context, _, _) => _FullScreenPlayer(
          player: _player!,
          title: _video?['title'] as String? ?? '',
          wasPlaying: wasPlaying,
        ),
      ),
    )
        .then((_) {
      if (_player != null) {
        _videoController = VideoController(_player!);
        if (mounted) setState(() {});
      }
      if (wasPlaying) _player?.play();
    });
  }

  @override
  void dispose() {
    _playSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    final title = _video?['title'] as String? ?? '视频播放';
    final padTop = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: padTop),
      color: const Color(0xFF000000),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(FIcons.arrowLeft,
                    color: Color(0xFFFFFFFF), size: 24),
              ),
            ),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF), fontSize: 17),
                  overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: _toggleFullscreen,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(FIcons.maximize,
                    color: Color(0xFFFFFFFF), size: 22),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: FCircularProgress())
                : widget.videoUuid == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FIcons.video,
                                color: Color(0x61FFFFFF), size: 64),
                            SizedBox(height: 16),
                            Text('请从课程页面选择视频播放',
                                style: TextStyle(
                                    color: Color(0x8AFFFFFF),
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    style: const TextStyle(
                                        color: Color(0xB3FFFFFF))),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: _loadData,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFFFF),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Text('重试',
                                        style: TextStyle(
                                            color: Color(0xFF000000))),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildPlayer(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    if (_player == null || _videoController == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Video(controller: _videoController!),
          if (!_isPlaying)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xC4FFFFFF),
              ),
              child: const Icon(FIcons.play,
                  color: Color(0xFFFFFFFF), size: 40),
            ),
        ],
      ),
    );
  }
}

class _FullScreenPlayer extends StatefulWidget {
  final Player player;
  final String title;
  final bool wasPlaying;

  const _FullScreenPlayer({
    required this.player,
    required this.title,
    required this.wasPlaying,
  });

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  late VideoController _controller;
  bool _playing = false;
  StreamSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    _controller = VideoController(widget.player);
    _playSub = widget.player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    if (widget.wasPlaying) widget.player.play();
  }

  void _togglePlay() {
    if (_playing) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
  }

  void _exitFullscreen() {
    _playSub?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _playSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000),
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Video(controller: _controller),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x8A000000), Color(0x00000000)],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _exitFullscreen,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(FIcons.arrowLeft,
                            color: Color(0xFFFFFFFF), size: 24),
                      ),
                    ),
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              color: Color(0xFFFFFFFF), fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
            if (!_playing)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xC4FFFFFF),
                ),
                child: const Icon(FIcons.play,
                    color: Color(0xFFFFFFFF), size: 40),
              ),
          ],
        ),
      ),
    );
  }
}

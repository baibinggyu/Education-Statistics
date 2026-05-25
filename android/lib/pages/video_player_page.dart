import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

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
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _videoReady = false;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;
  Duration _position = Duration.zero;
  bool _wasPlaying = false;

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
    try {
      final v = await _api.getVideoDetail(widget.videoUuid!);
      if (mounted) {
        setState(() {
          _video = v;
          _loading = false;
        });
        _initPlayer();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '加载视频信息失败'; });
    }
  }

  Future<void> _initPlayer() async {
    try {
      final uri = Uri.parse(_videoUrl);
      _controller = VideoPlayerController.networkUrl(uri);
      await _controller!.initialize();
      _controller!.addListener(_onPlayerUpdate);
      if (mounted) setState(() => _videoReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = '视频加载失败: $e');
    }
  }

  void _onPlayerUpdate() {
    if (_controller == null || !mounted) return;
    final pos = _controller!.value.position;
    if (pos != _position) {
      setState(() => _position = pos);
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    var newPos = _controller!.value.position + Duration(seconds: seconds);
    final max = _controller!.value.duration;
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > max) newPos = max;
    _controller!.seekTo(newPos);
  }

  void _toggleFullscreen() {
    _wasPlaying = _controller?.value.isPlaying ?? false;
    if (_controller != null && _wasPlaying) _controller!.pause();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPlayer(
          controller: _controller!,
          title: _video?['title'] as String? ?? '',
          wasPlaying: _wasPlaying,
        ),
      ),
    ).then((_) {
      if (_wasPlaying) _controller?.play();
    });
  }

  void _onTapVideo() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetHideTimer();
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _video?['title'] as String? ?? '视频播放';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildPlayer(context),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final r = context.responsive;
    if (!_videoReady || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _controller!.value.duration;
    final progress = _position.inMilliseconds / (total.inMilliseconds > 0 ? total.inMilliseconds : 1);
    final isPlaying = _controller!.value.isPlaying;

    return Column(
      children: [
        // Video area
        Expanded(
          child: GestureDetector(
            onTap: _onTapVideo,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                if (_showControls && !isPlaying)
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(77),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                  ),
                // Top info bar
                if (_showControls)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.all(r.clamped(12, 8, 16)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _video?['title'] as String? ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                                onPressed: _toggleFullscreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Controls
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showControls ? null : 0,
          child: _showControls
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: r.clamped(12, 8, 16), vertical: r.clamped(8, 4, 12)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Progress slider
                      Row(
                        children: [
                          Text(_fmt(_position), style: AppTextStyles.small),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: AppColors.primary,
                              ),
                              child: Slider(
                                value: (progress * 1000).clamp(0, 1000).toDouble(),
                                max: 1000,
                                onChanged: (v) {
                                  final ms = (total.inMilliseconds * v / 1000).round();
                                  _controller!.seekTo(Duration(milliseconds: ms));
                                },
                              ),
                            ),
                          ),
                          Text(_fmt(total), style: AppTextStyles.small),
                        ],
                      ),
                      // Play controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white),
                            onPressed: () => _seekRelative(-10),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white),
                            onPressed: () {},
                          ),
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlay,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, color: Colors.white),
                            onPressed: () => _seekRelative(10),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FullScreenPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final bool wasPlaying;

  const _FullScreenPlayer({
    required this.controller,
    required this.title,
    required this.wasPlaying,
  });

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _hideTimer;
  Duration _pos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onUpdate);
    if (widget.wasPlaying) _controller.play();
    _resetTimer();
  }

  void _onUpdate() {
    if (!mounted) return;
    final pos = _controller.value.position;
    if (pos != _pos) setState(() => _pos = pos);
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  void _seekRelative(int seconds) {
    var np = _controller.value.position + Duration(seconds: seconds);
    if (np < Duration.zero) np = Duration.zero;
    if (np > _controller.value.duration) np = _controller.value.duration;
    _controller.seekTo(np);
  }

  void _exitFullscreen() {
    _controller.removeListener(_onUpdate);
    Navigator.of(context).pop();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller.value.isPlaying;
    final total = _controller.value.duration;
    final progress = total.inMilliseconds > 0
        ? _pos.inMilliseconds / total.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _resetTimer();
        },
        child: Stack(
          children: [
            Center(child: VideoPlayer(_controller)),
            // Controls overlay
            if (_showControls)
              Column(
                children: [
                  // Top bar
                  Container(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _exitFullscreen,
                          ),
                          Expanded(
                            child: Text(widget.title,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Bottom controls
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(_fmt(_pos), style: AppTextStyles.small),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                    activeTrackColor: AppColors.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: AppColors.primary,
                                  ),
                                  child: Slider(
                                    value: (progress * 1000).clamp(0, 1000).toDouble(),
                                    max: 1000,
                                    onChanged: (v) {
                                      final ms = (total.inMilliseconds * v / 1000).round();
                                      _controller.seekTo(Duration(milliseconds: ms));
                                    },
                                  ),
                                ),
                              ),
                              Text(_fmt(total), style: AppTextStyles.small),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                                onPressed: () => _seekRelative(-10),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 30),
                                onPressed: () {},
                              ),
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white, size: 32,
                                  ),
                                  onPressed: _togglePlay,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next, color: Colors.white, size: 30),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

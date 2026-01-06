import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A full-screen looping video background widget
/// Used for personal account screens
class VideoBackground extends StatefulWidget {
  final Widget child;
  final String? videoUrl;
  final String? assetPath;
  final Color overlayColor;
  final double overlayOpacity;

  const VideoBackground({
    super.key,
    required this.child,
    this.videoUrl,
    this.assetPath,
    this.overlayColor = const Color(0xFF0f0f23),
    this.overlayOpacity = 0.7,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.assetPath != null) {
        _controller = VideoPlayerController.asset(widget.assetPath!);
      } else if (widget.videoUrl != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      } else {
        // Default video - you can replace this with your own video URL
        _controller = VideoPlayerController.networkUrl(
          Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
        );
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Mute the video
      _controller!.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      // Video initialization failed - will show solid color background
      debugPrint('Video background initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or fallback background
        if (_isInitialized && _controller != null)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else
          Container(
            color: widget.overlayColor,
          ),

        // Dark overlay for readability
        Container(
          color: widget.overlayColor.withValues(alpha: widget.overlayOpacity),
        ),

        // Child content
        widget.child,
      ],
    );
  }
}

/// A wrapper that provides a shared video background controller
/// to avoid recreating the video on every screen change
class SharedVideoBackground extends StatefulWidget {
  final Widget child;
  final String? videoUrl;
  final String? assetPath;
  final Color overlayColor;
  final double overlayOpacity;
  final bool showVideo;

  const SharedVideoBackground({
    super.key,
    required this.child,
    this.videoUrl,
    this.assetPath,
    this.overlayColor = const Color(0xFF0f0f23),
    this.overlayOpacity = 0.7,
    this.showVideo = true,
  });

  @override
  State<SharedVideoBackground> createState() => _SharedVideoBackgroundState();
}

class _SharedVideoBackgroundState extends State<SharedVideoBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _controller!.pause();
    } else if (state == AppLifecycleState.resumed && widget.showVideo) {
      _controller!.play();
    }
  }

  @override
  void didUpdateWidget(SharedVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Resume/pause video based on showVideo
    if (_isInitialized && _controller != null) {
      if (widget.showVideo && !oldWidget.showVideo) {
        _controller!.play();
      } else if (!widget.showVideo && oldWidget.showVideo) {
        _controller!.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.assetPath != null) {
        _controller = VideoPlayerController.asset(widget.assetPath!);
      } else if (widget.videoUrl != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      } else {
        // Default demo video
        _controller = VideoPlayerController.networkUrl(
          Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
        );
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Mute the video

      if (widget.showVideo) {
        _controller!.play();
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Video background initialization failed: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video background (always rendered to keep state)
        if (_isInitialized && _controller != null && !_hasError)
          Opacity(
            opacity: widget.showVideo ? 1.0 : 0.0,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          )
        else
          Container(
            color: widget.overlayColor,
          ),

        // Dark overlay for readability
        if (widget.showVideo)
          Container(
            color: widget.overlayColor.withValues(alpha: widget.overlayOpacity),
          ),

        // Child content
        widget.child,
      ],
    );
  }
}

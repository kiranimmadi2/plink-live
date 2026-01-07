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
        // Gradient background (always shown as base layer)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E1E1E), // Top color
                Color(0xFF000814), // Bottom color
              ],
            ),
          ),
        ),

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

/// A wrapper that provides a gradient background
/// Simple gradient from dark gray to dark blue
class SharedVideoBackground extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background only (no video, no overlay)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E1E1E), // Top color
                Color(0xFF000814), // Bottom color
              ],
            ),
          ),
        ),

        // Child content
        child,
      ],
    );
  }
}

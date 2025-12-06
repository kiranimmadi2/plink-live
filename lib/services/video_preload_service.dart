import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Singleton service to preload and manage the home screen background video.
/// This ensures the video is initialized before the HomeScreen is shown,
/// preventing the flash of grey background.
class VideoPreloadService {
  static final VideoPreloadService _instance = VideoPreloadService._internal();
  factory VideoPreloadService() => _instance;
  VideoPreloadService._internal();

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Callbacks to notify listeners when video is ready
  final List<VoidCallback> _onReadyCallbacks = [];

  /// Returns true if video is ready to play
  bool get isReady =>
      _isInitialized && _controller != null && _controller!.value.isInitialized;

  /// Returns the video controller (may be null if not initialized)
  VideoPlayerController? get controller => _controller;

  /// Add a callback to be called when video is ready
  void addOnReadyCallback(VoidCallback callback) {
    if (isReady) {
      // Already ready, call immediately
      callback();
    } else {
      _onReadyCallbacks.add(callback);
    }
  }

  /// Remove a callback
  void removeOnReadyCallback(VoidCallback callback) {
    _onReadyCallbacks.remove(callback);
  }

  /// Notify all listeners that video is ready
  void _notifyReady() {
    for (final callback in _onReadyCallbacks) {
      callback();
    }
    _onReadyCallbacks.clear();
  }

  /// Preload the video. Call this early (e.g., in splash screen or main navigation)
  Future<bool> preload() async {
    if (_isInitialized || _isInitializing) {
      return _isInitialized;
    }

    _isInitializing = true;
    debugPrint(' VideoPreloadService: Starting video preload...');

    try {
      _controller = VideoPlayerController.asset(
        'assets/logo/home_background.mp4',
      );

      await _controller!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(' VideoPreloadService: Video initialization timed out');
          throw Exception('Video initialization timeout');
        },
      );

      if (_controller!.value.isInitialized) {
        _controller!.setLooping(true);
        _controller!.setVolume(0);
        await _controller!.play();
        _isInitialized = true;
        debugPrint(' VideoPreloadService: Video preloaded successfully');
        _notifyReady();
        return true;
      } else {
        debugPrint(' VideoPreloadService: Video failed to initialize');
        _disposeController();
        return false;
      }
    } catch (e) {
      debugPrint(' VideoPreloadService: Error preloading video: $e');
      _disposeController();
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Safely dispose controller
  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  /// Dispose the video controller (call on app exit)
  void dispose() {
    _disposeController();
    _isInitialized = false;
    _isInitializing = false;
  }

  /// Pause the video (when HomeScreen is not visible)
  void pause() {
    try {
      _controller?.pause();
    } catch (e) {
      debugPrint('Error pausing video: $e');
    }
  }

  /// Resume the video (when HomeScreen becomes visible)
  void resume() {
    try {
      if (_isInitialized && _controller != null && _controller!.value.isInitialized) {
        _controller!.play();
      }
    } catch (e) {
      debugPrint('Error resuming video: $e');
    }
  }
}

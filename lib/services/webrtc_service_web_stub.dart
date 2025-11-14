// Web stub for Agora RTC Engine
// This file provides dummy implementations for web platform

import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

// Export platformViewRegistry for web compatibility
final platformViewRegistry = ui_web.platformViewRegistry;

// Global function to create engine
RtcEngine createAgoraRtcEngine() {
  return RtcEngine();
}

class RtcEngine {
  static Future<RtcEngine> createWithContext(dynamic config) async {
    return RtcEngine();
  }
  
  Future<void> initialize(dynamic config) async {}
  Future<void> enableVideo() async {}
  Future<void> disableVideo() async {}
  Future<void> enableAudio() async {}
  Future<void> enableLocalVideo(bool enabled) async {}
  Future<void> muteLocalAudioStream(bool mute) async {}
  Future<void> joinChannel({
    required String? token,
    required String channelId,
    required int uid,
    required dynamic options,
  }) async {}
  Future<void> leaveChannel([dynamic options]) async {}
  Future<void> release() async {}
  Future<void> setChannelProfile(dynamic profile) async {}
  Future<void> setClientRole({required dynamic role, dynamic options}) async {}
  Future<void> enableDualStreamMode({required bool enabled, dynamic streamConfig}) async {}
  Future<void> setVideoEncoderConfiguration(dynamic config) async {}
  Future<void> startPreview([dynamic sourceType]) async {}
  Future<void> stopPreview([dynamic sourceType]) async {}
  Future<void> switchCamera() async {}
  Future<bool> isSpeakerphoneEnabled() async => false;
  Future<void> setEnableSpeakerphone(bool enabled) async {}
  Future<void> setDefaultAudioRouteToSpeakerphone(bool enabled) async {}
  
  void registerEventHandler(RtcEngineEventHandler handler) {}
  void unregisterEventHandler(RtcEngineEventHandler handler) {}
}

class RtcEngineContext {
  final String appId;
  final int? areaCode;
  final ChannelProfileType? channelProfile;
  final AudioScenarioType? audioScenario;
  final LogConfig? logConfig;
  
  const RtcEngineContext({required this.appId, this.areaCode, this.channelProfile, this.audioScenario, this.logConfig});
}

class ChannelProfileType {
  static const liveBroadcasting = ChannelProfileType._('liveBroadcasting');
  static const communication = ChannelProfileType._('communication');
  static const channelProfileCommunication = ChannelProfileType._('communication');
  
  final String value;
  const ChannelProfileType._(this.value);
}

class ClientRoleType {
  static const broadcaster = ClientRoleType._('broadcaster');
  static const audience = ClientRoleType._('audience');
  static const clientRoleBroadcaster = ClientRoleType._('broadcaster');
  
  final String value;
  const ClientRoleType._(this.value);
}

class ChannelMediaOptions {
  final bool? publishMicrophoneTrack;
  final bool? publishCameraTrack;
  final bool? autoSubscribeVideo;
  final bool? autoSubscribeAudio;
  final ClientRoleType? clientRoleType;
  final ChannelProfileType? channelProfile;
  final bool? enableAudioRecordingOrPlayout;
  
  const ChannelMediaOptions({
    this.publishMicrophoneTrack,
    this.publishCameraTrack,
    this.autoSubscribeVideo,
    this.autoSubscribeAudio,
    this.clientRoleType,
    this.channelProfile,
    this.enableAudioRecordingOrPlayout,
  });
}

class VideoEncoderConfiguration {
  final VideoDimensions? dimensions;
  final int? frameRate;
  final int? bitrate;
  
  VideoEncoderConfiguration({
    this.dimensions,
    this.frameRate,
    this.bitrate,
  });
}

class VideoDimensions {
  final int width;
  final int height;
  
  VideoDimensions({required this.width, required this.height});
}

class SimulcastStreamConfig {
  final VideoDimensions? dimensions;
  final int? framerate;
  final int? bitrate;
  
  SimulcastStreamConfig({this.dimensions, this.framerate, this.bitrate});
}

class VideoSourceType {
  static const camera = VideoSourceType._('camera');
  static const cameraSecondary = VideoSourceType._('cameraSecondary');
  
  final String value;
  const VideoSourceType._(this.value);
}

class RtcEngineEventHandler {
  final void Function(RtcConnection connection, int uid, int elapsed)? onUserJoined;
  final void Function(RtcConnection connection, int elapsed)? onJoinChannelSuccess;
  final void Function(RtcConnection connection, int uid, UserOfflineReasonType reason)? onUserOffline;
  final void Function(ErrorCodeType err, String msg)? onError;
  final void Function(RtcConnection connection, RtcStats stats)? onRtcStats;
  final void Function(RtcConnection connection, int uid)? onActiveSpeaker;
  final void Function(RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason)? onConnectionStateChanged;
  
  RtcEngineEventHandler({
    this.onUserJoined,
    this.onJoinChannelSuccess,
    this.onUserOffline,
    this.onError,
    this.onRtcStats,
    this.onActiveSpeaker,
    this.onConnectionStateChanged,
  });
}

class RtcConnection {
  final String channelId;
  final int localUid;
  
  RtcConnection({required this.channelId, required this.localUid});
}

class UserOfflineReasonType {
  static const quit = UserOfflineReasonType._('quit');
  static const dropped = UserOfflineReasonType._('dropped');
  
  final String value;
  const UserOfflineReasonType._(this.value);
}

class ErrorCodeType {
  static const noError = ErrorCodeType._('noError');
  static const errTokenExpired = ErrorCodeType._('errTokenExpired');
  static const errInvalidToken = ErrorCodeType._('errInvalidToken');
  
  final String value;
  const ErrorCodeType._(this.value);
}

class RtcStats {
  final int duration;
  final int txBytes;
  final int rxBytes;
  final int txKBitRate;
  final int rxKBitRate;
  final int users;
  
  RtcStats({
    required this.duration,
    required this.txBytes,
    required this.rxBytes,
    required this.txKBitRate,
    required this.rxKBitRate,
    required this.users,
  });
}

// Export necessary UI components
class AgoraVideoView extends StatelessWidget {
  final VideoViewController? controller;
  
  const AgoraVideoView({Key? key, this.controller}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'Video not available on web',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class VideoViewController {
  final RtcEngine? rtcEngine;
  final VideoCanvas? canvas;
  final RtcConnection? connection;
  
  VideoViewController({this.rtcEngine, this.canvas, this.connection});
  
  static VideoViewController remote({
    required RtcEngine rtcEngine,
    required VideoCanvas canvas,
    required RtcConnection connection,
  }) {
    return VideoViewController(rtcEngine: rtcEngine, canvas: canvas, connection: connection);
  }
  
  factory VideoViewController.local({
    required RtcEngine rtcEngine,
    required VideoCanvas canvas,
  }) {
    return VideoViewController(rtcEngine: rtcEngine, canvas: canvas);
  }
}

class VideoCanvas {
  final int uid;
  
  const VideoCanvas({required this.uid});
}

// Additional classes for call_service.dart compatibility
class AudioProfileType {
  static const audioProfileDefault = AudioProfileType._('default');
  final String value;
  const AudioProfileType._(this.value);
}

class AudioScenarioType {
  static const audioScenarioDefault = AudioScenarioType._('default');
  static const audioScenarioChatRoom = AudioScenarioType._('chatRoom');
  final String value;
  const AudioScenarioType._(this.value);
}

class ConnectionStateType {
  static const connectionStateFailed = ConnectionStateType._('failed');
  static const connectionStateConnected = ConnectionStateType._('connected');
  final String value;
  const ConnectionStateType._(this.value);
}

class ConnectionChangedReasonType {
  static const connectionChangedJoinSuccess = ConnectionChangedReasonType._('joinSuccess');
  final String value;
  const ConnectionChangedReasonType._(this.value);
}

class LogLevel {
  static const logLevelInfo = LogLevel._('info');
  static const logLevelWarn = LogLevel._('warn');
  final String value;
  const LogLevel._(this.value);
}

class LogConfig {
  final LogLevel? level;
  const LogConfig({this.level});
}

// Add missing methods to RtcEngine
extension RtcEngineExtensions on RtcEngine {
  Future<void> setAudioProfile({required AudioProfileType profile, required AudioScenarioType scenario}) async {}
  Future<dynamic> getConnectionState() async => ConnectionStateType.connectionStateConnected;
}
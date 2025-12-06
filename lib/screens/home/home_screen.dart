import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../enhanced_chat_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../services/realtime_matching_service.dart';
import '../profile/profile_with_history_screen.dart';
import '../../services/photo_cache_service.dart';
import '../../widgets/floating_particles.dart';
import '../../providers/discovery_providers.dart';
import 'package:lottie/lottie.dart';

@immutable
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final RealtimeMatchingService _realtimeService = RealtimeMatchingService();
  final PhotoCacheService _photoCache = PhotoCacheService();

  // Helper getter for current user photo URL
  String? get _currentUserPhotoURL => FirebaseAuth.instance.currentUser?.photoURL;

  final TextEditingController _intentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _voiceScrollController = ScrollController();

  bool _isSearchFocused = false;

  late AnimationController _controller;
  bool _visible = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _realtimeService.initialize();

    _controller = AnimationController(vsync: this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _visible = !_visible;
      });
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _intentController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _intentController.dispose();
    _searchFocusNode.dispose();
    _realtimeService.dispose();
    _controller.dispose();
    _timer.cancel();
    _voiceScrollController.dispose();
    super.dispose();
  }

  void _processIntent() async {
    if (_intentController.text.isEmpty) return;

    final userMessage = _intentController.text.trim();
    if (userMessage.isEmpty) return;

    // Add user message to conversation
    ref.read(conversationProvider.notifier).addUserMessage(userMessage);
    ref.read(homeProcessingProvider.notifier).setProcessing(true);

    _intentController.clear();

    await Future.delayed(const Duration(milliseconds: 1000));

    // Get user name from provider
    final userName = ref.read(currentUserNameProvider).maybeWhen(
      data: (name) => name,
      orElse: () => 'User',
    );

    final aiResponse = generateAIResponse(userMessage, userName);
    ref.read(conversationProvider.notifier).addAIMessage(aiResponse);
    ref.read(homeProcessingProvider.notifier).setProcessing(false);

    if (shouldProcessForMatches(userMessage)) {
      await _processWithIntent(userMessage);
    }
  }

  void _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    ref.read(homeProcessingProvider.notifier).setRecording(true);
    ref.read(homeProcessingProvider.notifier).setVoiceText('Listening... Speak now');

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _stopVoiceRecording();
    }
  }

  void _stopVoiceRecording() async {
    ref.read(homeProcessingProvider.notifier).setRecording(false);
    ref.read(homeProcessingProvider.notifier).setVoiceProcessing(true);
    ref.read(homeProcessingProvider.notifier).setVoiceText('Processing your voice...');

    await Future.delayed(const Duration(seconds: 2));

    final mockVoiceResults = [
      "I'm looking for a bicycle under 200 dollars",
      "Need a room for rent near college campus",
      "Want to buy second hand engineering books",
      "Looking for part time job on weekends",
      "Selling my old smartphone in good condition",
      "Want to find a roommate near university",
      "Looking to buy a used laptop for studies",
    ];

    final randomResult =
        mockVoiceResults[DateTime.now().millisecondsSinceEpoch %
            mockVoiceResults.length];

    ref.read(homeProcessingProvider.notifier).setVoiceProcessing(false);
    ref.read(homeProcessingProvider.notifier).setVoiceText(randomResult);
    _intentController.text = randomResult;

    // Auto-scroll to bottom when text updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_voiceScrollController.hasClients) {
        _voiceScrollController.animateTo(
          _voiceScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    await Future.delayed(const Duration(milliseconds: 500));
    _processIntent();
  }

  Future<void> _processWithIntent(String intent) async {
    ref.read(homeProcessingProvider.notifier).setProcessing(true);

    try {
      await ref.read(matchesProvider.notifier).processIntent(intent);

      if (!mounted) return;

      final matchesState = ref.read(matchesProvider);
      ref.read(homeProcessingProvider.notifier).setProcessing(false);

      if (matchesState.hasMatches) {
        ref.read(conversationProvider.notifier).addAIMessage(
          'Found ${matchesState.matchCount} potential matches for you! Tap below to view them.',
        );
      }
    } catch (e) {
      ref.read(homeProcessingProvider.notifier).setProcessing(false);
    }
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)}m away';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceInKm.toStringAsFixed(0)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Watch providers for reactive updates
    final processingState = ref.watch(homeProcessingProvider);
    final matchesState = ref.watch(matchesProvider);
    final userNameAsync = ref.watch(currentUserNameProvider);
    final currentUserName = userNameAsync.maybeWhen(
      data: (name) => name,
      orElse: () => 'User',
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 60,
        centerTitle: false,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isDarkMode
                ? [Colors.white, Colors.grey[400]!]
                : [Colors.black, Colors.grey[800]!],
          ).createShader(bounds),
          child: const Text(
            'Supper',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: 0.5,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileWithHistoryScreen(),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: UserAvatar(
                  profileImageUrl: _currentUserPhotoURL,
                  radius: 20,
                  fallbackText: currentUserName,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(color: Colors.grey.shade700),
          const Positioned.fill(child: FloatingParticles(particleCount: 12)),

          // Main content
          Column(
            children: [
              Expanded(
                child: processingState.isProcessing
                    ? _buildChatState(isDarkMode)
                    : matchesState.hasMatches
                    ? _buildMatchesList(isDarkMode)
                    : _buildChatState(isDarkMode),
              ),

              // Voice recording overlay - HALF SCREEN MODAL
              if (processingState.isRecording || processingState.isVoiceProcessing)
                _buildVoiceRecordingOverlay(isDarkMode),

              // Bottom input section
              if (!processingState.isRecording && !processingState.isVoiceProcessing)
                _buildInputSection(isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRecordingOverlay(bool isDarkMode) {
    final processingState = ref.watch(homeProcessingProvider);
    final isRecording = processingState.isRecording;
    final isVoiceProcessing = processingState.isVoiceProcessing;
    final voiceText = processingState.voiceText;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated voice waves
          Stack(
            alignment: Alignment.center,
            children: [
              if (isRecording) ...[
                _buildVoiceWave(120, 0.3, 0),
                _buildVoiceWave(100, 0.5, 500),
                _buildVoiceWave(80, 0.7, 1000),
              ],
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording ? Colors.red : Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording ? Colors.red : Colors.blue)
                          .withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                  image: !isRecording
                      ? const DecorationImage(
                          image: AssetImage('assets/logo/Clogo.jpeg'),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: isRecording
                    ? const Center(
                        child: Icon(Icons.mic, color: Colors.white, size: 40),
                      )
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Scrollable text container
          Expanded(
            child: SingleChildScrollView(
              controller: _voiceScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Status text
                  Text(
                    voiceText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Additional guidance
                  if (isRecording)
                    Text(
                      'Tap anywhere to stop recording',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      textAlign: TextAlign.center,
                    ),

                  if (isVoiceProcessing)
                    const Column(
                      children: [
                        SizedBox(height: 20),
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 219, 224, 228),
                          ),
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Close button
          if (isRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: GestureDetector(
                onTap: _stopVoiceRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'Stop Recording',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceWave(double size, double opacity, int delay) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: opacity * (1 - value),
          child: Container(
            width: size + (value * 100),
            height: size + (value * 100),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputSection(bool isDarkMode) {
    final processingState = ref.watch(homeProcessingProvider);
    final isRecording = processingState.isRecording;
    final isProcessing = processingState.isProcessing;
    final query = _intentController.text;
    final suggestions = ref.watch(filteredSuggestionsProvider(query));

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 16,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _intentController.text = suggestions[index];
                        _processIntent();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.2),
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          suggestions[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Input container
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: Colors.grey[900],
              border: Border.all(
                color: _isSearchFocused
                    ? const Color.fromARGB(255, 146, 146, 146)
                    : const Color.fromARGB(255, 146, 146, 146),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isSearchFocused
                      ? const Color.fromARGB(255, 146, 146, 146)
                      : Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      color: _isSearchFocused ? Colors.white : Colors.grey[400],
                      fontSize: _isSearchFocused ? 16 : 15,
                      fontWeight: _isSearchFocused
                          ? FontWeight.w500
                          : FontWeight.w400,
                      height: 1.4,
                    ),
                    child: TextField(
                      controller: _intentController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: null,
                      cursorColor: Colors.white,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything... What do you need?',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                      onChanged: (value) {
                        // Trigger rebuild to update suggestions via provider
                        setState(() {});
                      },
                      onSubmitted: (_) => _processIntent(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Mic button
                GestureDetector(
                  onTap: isRecording
                      ? _stopVoiceRecording
                      : _startVoiceRecording,
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(left: 6, bottom: 7.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecording ? Colors.red : Colors.grey[800],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                GestureDetector(
                  onTap: isProcessing ? null : _processIntent,
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 6, bottom: 7.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                    ),
                    child: isProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatState(bool isDarkMode) {
    final conversationState = ref.watch(conversationProvider);
    final messages = conversationState.messages;

    return Column(
      children: [
        const SizedBox(height: 110),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            reverse: false,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _buildMessageBubble(message, isDarkMode);
            },
          ),
        ),

        if (messages.length <= 1)
          AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 300),
            child: Lottie.asset(
              'assets/animation.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              animate: true,
              repeat: true,
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(ConversationMessage message, bool isDarkMode) {
    final isUser = message.isUser;
    final text = message.text;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).primaryColor
                    : Colors.grey[800]!.withValues(alpha: 0.8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: _currentUserPhotoURL != null
                    ? DecorationImage(
                        image: NetworkImage(_currentUserPhotoURL!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: _currentUserPhotoURL == null ? Colors.grey : null,
              ),
              child: _currentUserPhotoURL == null
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildMatchesList(bool isDarkMode) {
    final matchesState = ref.watch(matchesProvider);
    final matches = matchesState.matches;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(color: Colors.green.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                '${matches.length} Matches Found',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ref.read(matchesProvider.notifier).clearMatches();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              return _buildMatchCard(matches[index], isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, bool isDarkMode) {
    final userProfile = match['userProfile'] ?? {};
    final matchScore = (match['matchScore'] ?? 0.0) * 100;
    final userName = userProfile['name'] ?? 'Unknown User';
    final userId = match['userId'];

    final cachedPhoto = userId != null
        ? _photoCache.getCachedPhotoUrl(userId)
        : null;
    final photoUrl = cachedPhoto ?? userProfile['photoUrl'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();

          final otherUser = UserProfile.fromMap(userProfile, match['userId']);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: otherUser),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    profileImageUrl: photoUrl,
                    radius: 24,
                    fallbackText: userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${matchScore.toStringAsFixed(0)}% match',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userProfile['city'] != null &&
                            userProfile['city'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userProfile['city'].toString(),
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (match['distance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 14,
                                  color: Colors.orange[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDistance(match['distance'] as double),
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posted:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match['title'] ??
                          match['description'] ??
                          'Looking for match',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match['description'] != null &&
                        match['description'] != match['title'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          match['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (match['lookingFor'] != null &&
                  match['lookingFor'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Matches your search',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

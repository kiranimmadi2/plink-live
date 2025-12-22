import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../models/user_profile.dart';
import '../chat/enhanced_chat_screen.dart';
import 'my_posts_screen.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const FeedScreen({super.key, this.onBack});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Posts data
  List<DocumentSnapshot> _posts = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20;

  // Saved posts
  Set<String> _savedPostIds = {};

  // Voice search
  bool _isListening = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  Timer? _silenceTimer;

  // Categories
  String _selectedCategory = 'All';
  bool _isCategoryLoading = false;
  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.grid_view_rounded},
    {'name': 'Seeking', 'icon': Icons.search_rounded},
    {'name': 'Offering', 'icon': Icons.local_offer_rounded},
    {'name': 'Services', 'icon': Icons.handyman_rounded},
    {'name': 'Jobs', 'icon': Icons.work_rounded},
    {'name': 'Buy/Sell', 'icon': Icons.shopping_cart_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeedPosts();
    _loadSavedPosts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _initSpeech();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload saved posts when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadSavedPosts();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload saved posts when returning to this screen
    _loadSavedPosts();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            _stopVoiceSearch();
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    _silenceTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadFeedPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Simple query without compound index requirement
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          _posts = snapshot.docs;
          _isLoading = false;
          _hasMore = snapshot.docs.length == _pageSize;
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading feed posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Simple query without compound index requirement
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          _posts.addAll(snapshot.docs);
          _isLoading = false;
          _hasMore = snapshot.docs.length == _pageSize;
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedPosts() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .get();

      if (mounted) {
        setState(() {
          _savedPostIds = savedSnapshot.docs.map((doc) => doc.id).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
    }
  }

  Future<void> _toggleSavePost(String postId, Map<String, dynamic> postData) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    HapticFeedback.lightImpact();

    try {
      final savedRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .doc(postId);

      if (_savedPostIds.contains(postId)) {
        await savedRef.delete();
        if (mounted) {
          setState(() {
            _savedPostIds.remove(postId);
          });
        }
      } else {
        await savedRef.set({
          'postId': postId,
          'postData': postData,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _savedPostIds.add(postId);
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling save: $e');
    }
  }

  void _startVoiceSearch() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Request microphone permission first
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('Microphone permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice search'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if speech is available
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted && _isListening) {
            _silenceTimer?.cancel();
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (!_speechEnabled) {
        debugPrint('Speech recognition not available');
        return;
      }
    }

    setState(() {
      _isListening = true;
    });

    // Start 5-second silence timer
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isListening && _searchController.text.isEmpty) {
        _stopVoiceSearch();
      }
    });

    // Start listening
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          if (result.recognizedWords.isNotEmpty) {
            _silenceTimer?.cancel();
          }

          // Update search controller text and move cursor to end
          _searchController.text = result.recognizedWords;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );

          // Force rebuild to apply filter
          setState(() {});

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _stopVoiceSearch();
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN', // Support for Indian English
    );
  }

  void _stopVoiceSearch() async {
    if (!mounted) return;

    _silenceTimer?.cancel();
    await _speech.stop();

    setState(() {
      _isListening = false;
    });
  }

  List<DocumentSnapshot> get _filteredPosts {
    final searchQuery = _searchController.text.toLowerCase().trim();

    return _posts.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Filter out inactive posts
      if (data['isActive'] == false) return false;

      // Category filter
      if (_selectedCategory != 'All') {
        final intentAnalysis = data['intentAnalysis'] as Map<String, dynamic>?;
        // Check actionType from multiple possible locations
        final actionType = (data['actionType'] ??
                           intentAnalysis?['action_type'] ??
                           data['type'] ?? '')
                           .toString().toLowerCase();
        final domain = (intentAnalysis?['domain'] ?? '').toString().toLowerCase();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final hashtags = (data['hashtags'] as List<dynamic>?)?.join(' ').toLowerCase() ?? '';
        final combinedText = '$title $description $hashtags';

        if (_selectedCategory == 'Seeking') {
          if (actionType != 'seeking' &&
              !combinedText.contains('looking') &&
              !combinedText.contains('need') &&
              !combinedText.contains('want') &&
              !combinedText.contains('search') &&
              !combinedText.contains('find')) return false;
        }
        if (_selectedCategory == 'Offering') {
          if (actionType != 'offering' &&
              !combinedText.contains('sell') &&
              !combinedText.contains('offer') &&
              !combinedText.contains('available') &&
              !combinedText.contains('sale')) return false;
        }
        if (_selectedCategory == 'Services') {
          if (!domain.contains('service') &&
              !combinedText.contains('service') &&
              !combinedText.contains('repair') &&
              !combinedText.contains('install') &&
              !combinedText.contains('fix')) return false;
        }
        if (_selectedCategory == 'Jobs') {
          if (!domain.contains('job') &&
              !combinedText.contains('job') &&
              !combinedText.contains('hiring') &&
              !combinedText.contains('work') &&
              !combinedText.contains('vacancy') &&
              !combinedText.contains('career')) return false;
        }
        if (_selectedCategory == 'Buy/Sell') {
          if (!domain.contains('marketplace') &&
              data['price'] == null) return false;
        }
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        final title = (data['title'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final prompt = (data['originalPrompt'] ?? '').toString().toLowerCase();
        final userName = (data['userName'] ?? '').toString().toLowerCase();
        final hashtags = (data['hashtags'] as List<dynamic>?)?.join(' ').toLowerCase() ?? '';

        return title.contains(searchQuery) ||
            description.contains(searchQuery) ||
            prompt.contains(searchQuery) ||
            userName.contains(searchQuery) ||
            hashtags.contains(searchQuery);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(color: AppColors.darkOverlay()),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Search bar
                _buildGlassSearchBar(),

                // Categories
                _buildGlassCategoryChips(),

                // Posts list
                Expanded(
                  child: _isLoading && _posts.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _filteredPosts.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadFeedPosts,
                              color: Colors.white,
                              backgroundColor: AppColors.backgroundDark,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredPosts.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _filteredPosts.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }

                                  final doc = _filteredPosts[index];
                                  final data = doc.data() as Map<String, dynamic>;

                                  return _buildPostCard(
                                    postId: doc.id,
                                    post: data,
                                    isSaved: _savedPostIds.contains(doc.id),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),

          // Floating Action Button - Create Post
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _showCreatePostDialog,
              backgroundColor: AppColors.iosBlue,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );

    // Refresh feed if post was created
    if (result == true && mounted) {
      _loadFeedPosts();
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundDark(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Feed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Profile / My Posts button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPostsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundDark(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: GlassSearchField(
        controller: _searchController,
        hintText: 'Search posts...',
        borderRadius: 26,
        showMic: true,
        isListening: _isListening,
        onMicTap: _startVoiceSearch,
        onStopListening: _stopVoiceSearch,
        onChanged: (value) => setState(() {}),
        onClear: () => setState(() {}),
      ),
    );
  }

  Widget _buildGlassCategoryChips() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['name'];

          return GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              setState(() {
                _isCategoryLoading = true;
                _selectedCategory = category['name'];
              });
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) {
                setState(() {
                  _isCategoryLoading = false;
                });
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected
                    ? const Color(0xFF0051A8)
                    : AppColors.backgroundDark.withValues(alpha: 0.5),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.glassBorder(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isCategoryLoading && isSelected)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      category['icon'] as IconData,
                      size: 16,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    category['name'],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard({
    required String postId,
    required Map<String, dynamic> post,
    required bool isSaved,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    final postUserId = post['userId'] as String?;
    final isOwnPost = currentUserId == postUserId;

    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final rawDescription = post['description']?.toString() ?? '';
    final description = (rawDescription == title || rawDescription == post['originalPrompt'])
        ? ''
        : rawDescription;
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    final imageUrl = (rawImageUrl != null && rawImageUrl.toString().isNotEmpty)
        ? rawImageUrl.toString()
        : (images.isNotEmpty && images[0] != null && images[0].toString().isNotEmpty)
            ? images[0].toString()
            : null;
    final price = post['price'];
    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];
    final intentAnalysis = post['intentAnalysis'] as Map<String, dynamic>?;
    final actionType = intentAnalysis?['action_type'] as String?;
    final createdAt = post['createdAt'];

    DateTime? time;
    if (createdAt != null && createdAt is Timestamp) {
      time = createdAt.toDate();
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasDescription = description.isNotEmpty;
    final bool hasPrice = price != null;

    int contentLevel = 0;
    if (hasImage) {
      contentLevel = 3;
    } else if (hasPrice && hasDescription) {
      contentLevel = 2;
    } else if (hasPrice || hasDescription) {
      contentLevel = 1;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = contentLevel == 3 ? screenHeight * 0.16 : 0.0;
    final cardPadding = contentLevel >= 2 ? 14.0 : 12.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(
          color: AppColors.glassBorder(alpha: 0.4),
          width: contentLevel >= 2 ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(contentLevel >= 2 ? 18 : 14),
          onTap: () {
            HapticFeedback.lightImpact();
            _openUserChat(post);
          },
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info
                Row(
                  children: [
                    UserAvatar(
                      profileImageUrl: PhotoUrlHelper.fixGooglePhotoUrl(userPhoto),
                      radius: contentLevel >= 2 ? 18 : 14,
                      fallbackText: userName,
                    ),
                    SizedBox(width: contentLevel >= 2 ? 10 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: contentLevel >= 2 ? 13 : 12,
                              color: Colors.white,
                            ),
                          ),
                          if (time != null)
                            Text(
                              timeago.format(time),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (actionType != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: contentLevel >= 2 ? 8 : 6,
                          vertical: contentLevel >= 2 ? 4 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getActionColor(actionType).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getActionColor(actionType).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          actionType == 'seeking'
                              ? 'Looking'
                              : actionType == 'offering'
                                  ? 'Offering'
                                  : actionType,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _getActionColor(actionType),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: contentLevel >= 2 ? 12 : 8),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Description
                if (hasDescription) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Price
                if (hasPrice) ...[
                  SizedBox(height: contentLevel >= 2 ? 8 : 6),
                  Text(
                    '₹${price.toString()}',
                    style: TextStyle(
                      fontSize: contentLevel >= 2 ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.vibrantGreen,
                    ),
                  ),
                ],

                // Post Image
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundDark(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: AppColors.glassBackgroundDark(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textTertiaryDark,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons row
                _buildActionButtons(postId, post, isOwnPost, isSaved),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(String postId, Map<String, dynamic> post, bool isOwnPost, bool isSaved) {
    final allowCalls = post['allowCalls'] ?? true; // Default to true if not set

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Chat button (only for other's posts)
        if (!isOwnPost)
          _buildActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            color: AppColors.iosBlue,
            onTap: () => _openUserChat(post),
          ),

        // Call button (only for other's posts and if allowCalls is true)
        if (!isOwnPost && allowCalls)
          _buildActionButton(
            icon: Icons.call_outlined,
            label: 'Call',
            color: AppColors.vibrantGreen,
            onTap: () => _makeVoiceCall(post),
          ),

        // Save button (only for other's posts)
        if (!isOwnPost)
          _buildActionButton(
            icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: isSaved ? 'Saved' : 'Save',
            color: isSaved ? AppColors.iosBlue : Colors.white70,
            onTap: () => _toggleSavePost(postId, post),
          ),

        // Edit button (only for own posts)
        if (isOwnPost)
          _buildActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: Colors.amber,
            onTap: () => _editPost(postId, post),
          ),

        // Delete button (only for own posts)
        if (isOwnPost)
          _buildActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.error,
            onTap: () => _showDeleteConfirmation(postId),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _makeVoiceCall(Map<String, dynamic> post) {
    final postUserId = post['userId'] as String?;
    final currentUserId = _auth.currentUser?.uid;

    if (postUserId == null || postUserId == currentUserId) return;

    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];

    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User avatar with call icon
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.vibrantGreen.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: userPhoto != null
                              ? NetworkImage(userPhoto)
                              : null,
                          child: userPhoto == null
                              ? Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.vibrantGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Call $userName?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You are about to start a voice call.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _initiateCall(post);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.vibrantGreen,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Call',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _initiateCall(Map<String, dynamic> post) async {
    final postUserId = post['userId'] as String?;
    final currentUser = _auth.currentUser;

    if (postUserId == null || currentUser == null) return;

    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];

    try {
      // Get current user's profile for proper name
      final callerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final callerData = callerDoc.data();
      final callerName = callerData?['name'] ?? callerData?['displayName'] ?? currentUser.displayName ?? 'Unknown';
      final callerPhoto = callerData?['photoUrl'] ?? callerData?['photoURL'] ?? callerData?['profileImageUrl'] ?? currentUser.photoURL;

      // Create call record in Firestore
      final callDoc = await _firestore.collection('calls').add({
        'callerId': currentUser.uid,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'receiverId': postUserId,
        'receiverName': userName,
        'receiverPhoto': userPhoto,
        'participants': [currentUser.uid, postUserId],
        'type': 'voice',
        'status': 'calling',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Fetch full user profile for chat navigation
      final userDoc = await _firestore.collection('users').doc(postUserId).get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final userData = userDoc.data()!;
      final userProfile = UserProfile(
        uid: postUserId,
        id: postUserId,
        name: userData['name'] ?? userData['displayName'] ?? userName,
        email: userData['email'] ?? '',
        profileImageUrl: userData['photoUrl'] ?? userData['photoURL'] ?? userData['profileImageUrl'] ?? userPhoto,
        bio: userData['bio'] ?? '',
        location: userData['location'],
        interests: (userData['interests'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      // Navigate to voice call screen
      Navigator.pushNamed(
        context,
        '/voice-call',
        arguments: {
          'callId': callDoc.id,
          'otherUser': userProfile,
          'isOutgoing': true,
        },
      );
    } catch (e) {
      debugPrint('Error initiating call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editPost(String postId, Map<String, dynamic> post) async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(postId: postId, postData: post),
      ),
    );

    // Refresh feed if post was updated
    if (result == true && mounted) {
      _loadFeedPosts();
    }
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Delete Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure? This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            await _deletePost(postId);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.error,
                            ),
                            child: const Center(
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully'), backgroundColor: Colors.green),
        );
        _loadFeedPosts(); // Refresh
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete post'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'seeking':
        return AppColors.iosBlue;
      case 'offering':
        return AppColors.vibrantGreen;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openUserChat(Map<String, dynamic> post) async {
    final postUserId = post['userId'] as String?;
    final currentUserId = _auth.currentUser?.uid;

    if (postUserId == null || postUserId == currentUserId) return;

    try {
      final userDoc = await _firestore.collection('users').doc(postUserId).get();

      if (!userDoc.exists || !mounted) return;

      final userData = userDoc.data()!;
      final userProfile = UserProfile(
        uid: postUserId,
        id: postUserId,
        name: userData['name'] ?? userData['displayName'] ?? 'User',
        email: userData['email'] ?? '',
        profileImageUrl: userData['photoUrl'] ?? userData['photoURL'] ?? userData['profileImageUrl'],
        bio: userData['bio'] ?? '',
        location: userData['location'],
        interests: (userData['interests'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedChatScreen(otherUser: userProfile),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundDark(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 64,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Posts Found',
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search or category',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

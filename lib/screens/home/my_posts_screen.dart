import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/config/app_assets.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../widgets/other widgets/user_avatar.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user data
  String _currentUserName = '';
  String? _currentUserPhoto;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _currentUserName = data?['name'] ?? data?['displayName'] ?? 'You';
          _currentUserPhoto = data?['photoUrl'] ?? data?['photoURL'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundDark(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder(alpha: 0.3)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Posts',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundDark(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder(alpha: 0.2)),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.iosBlue.withValues(alpha: 0.6),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Saved Posts'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Posts'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image (same as feed screen)
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark overlay for readability
          Positioned.fill(child: Container(color: AppColors.darkOverlay())),

          // Tab content
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSavedPostsTab(), _buildMyPostsTab()],
            ),
          ),
        ],
      ),
    );
  }

  // Saved Posts Tab
  Widget _buildSavedPostsTab() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Not Logged In',
        subtitle: 'Please login to see saved posts',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading saved posts: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Saved Posts',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No Saved Posts',
            subtitle: 'Posts you save will appear here',
          );
        }

        final savedPosts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedPosts.length,
          itemBuilder: (context, index) {
            final doc = savedPosts[index];
            final data = doc.data() as Map<String, dynamic>;
            final postData = data['postData'] as Map<String, dynamic>? ?? {};
            return _buildPostCard(
              postId: doc.id,
              post: postData,
              isSaved: true,
              timestamp: data['savedAt'],
            );
          },
        );
      },
    );
  }

  // My Posts Tab
  Widget _buildMyPostsTab() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: 'Not Logged In',
        subtitle: 'Please login to see your posts',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading posts: ${snapshot.error}');
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error Loading Posts',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.article_outlined,
            title: 'No Posts Yet',
            subtitle: 'Your posts will appear here',
          );
        }

        final myPosts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myPosts.length,
          itemBuilder: (context, index) {
            final doc = myPosts[index];
            final data = doc.data() as Map<String, dynamic>;
            // Add current user data to post for display
            final postWithUserData = Map<String, dynamic>.from(data);
            postWithUserData['userName'] = _currentUserName.isNotEmpty
                ? _currentUserName
                : (data['userName'] ?? 'You');
            postWithUserData['userPhoto'] =
                _currentUserPhoto ?? data['userPhoto'];
            return _buildPostCard(
              postId: doc.id,
              post: postWithUserData,
              isSaved: false,
              timestamp: data['createdAt'],
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard({
    required String postId,
    required Map<String, dynamic> post,
    required bool isSaved,
    dynamic timestamp,
  }) {
    final title = post['title'] ?? post['originalPrompt'] ?? 'No Title';
    final rawDescription = post['description']?.toString() ?? '';
    final description =
        (rawDescription == title || rawDescription == post['originalPrompt'])
        ? ''
        : rawDescription;
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    final imageUrl = (rawImageUrl != null && rawImageUrl.toString().isNotEmpty)
        ? rawImageUrl.toString()
        : (images.isNotEmpty &&
              images[0] != null &&
              images[0].toString().isNotEmpty)
        ? images[0].toString()
        : null;
    final price = post['price'];
    final userName = post['userName'] ?? 'User';
    final userPhoto = post['userPhoto'];
    final hashtags = (post['hashtags'] as List<dynamic>?)?.cast<String>() ?? [];
    final intentAnalysis = post['intentAnalysis'] as Map<String, dynamic>?;
    final actionType = intentAnalysis?['action_type'] as String?;

    // Get timestamp
    DateTime? time;
    if (timestamp != null && timestamp is Timestamp) {
      time = timestamp.toDate();
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final bool hasDescription = description.isNotEmpty;
    final bool hasPrice = price != null;

    // Calculate content level
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
          },
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info and action badge
                Row(
                  children: [
                    UserAvatar(
                      profileImageUrl: PhotoUrlHelper.fixGooglePhotoUrl(
                        userPhoto,
                      ),
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
                          color: _getActionColor(
                            actionType,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getActionColor(
                              actionType,
                            ).withValues(alpha: 0.5),
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

                // Hashtags
                if (hashtags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: hashtags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      );
                    }).toList(),
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

                SizedBox(height: contentLevel >= 2 ? 10 : 8),

                // Action button - Remove from Saved or Delete Post
                _buildActionButton(
                  icon: isSaved
                      ? Icons.bookmark_remove_rounded
                      : Icons.delete_outline_rounded,
                  label: isSaved ? 'Remove from Saved' : 'Delete Post',
                  color: AppColors.error,
                  onTap: () {
                    if (isSaved) {
                      _removeSavedPost(postId);
                    } else {
                      _showDeleteConfirmation(postId);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              child: Icon(icon, size: 64, color: Colors.white38),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSavedPost(String postId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_posts')
          .doc(postId)
          .delete();
    } catch (e) {
      debugPrint('Error removing saved post: $e');
    }
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Post?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone. Are you sure you want to delete this post?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePost(postId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post deleted successfully');
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to delete post');
      }
    }
  }
}

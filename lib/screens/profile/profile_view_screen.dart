import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/account_badges.dart';
import '../enhanced_chat_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  final UserProfile userProfile;
  final PostModel? post;

  const ProfileViewScreen({super.key, required this.userProfile, this.post});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildImageSection(),
                  _buildProfileInfo(),
                  _buildPostDetails(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            _buildTopBar(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Row(
              children: [
                if (widget.userProfile.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Online',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: _showMoreOptions,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final images = widget.post?.images ?? [];
    final profileImage = widget.userProfile.profileImageUrl;

    // Debug logging
    debugPrint('Profile Image URL: $profileImage');
    debugPrint('Post Images: $images');

    // Build the default fallback avatar widget
    Widget buildDefaultAvatar() {
      final initial = widget.userProfile.name.isNotEmpty
          ? widget.userProfile.name[0].toUpperCase()
          : '?';
      return Container(
        height: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.3),
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.userProfile.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              if (widget.userProfile.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      widget.userProfile.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    // On Flutter Web, Google profile photos often fail due to CORS/rate limiting
    // Check if all images are Google photos and skip loading if on web
    bool hasNonGoogleImages = false;
    final allImages = <String>[];

    // Check profile image
    if (profileImage != null && profileImage.isNotEmpty) {
      if (!profileImage.contains('googleusercontent.com')) {
        hasNonGoogleImages = true;
      }
      final fixedProfileImage = PhotoUrlHelper.fixGooglePhotoUrl(profileImage);
      if (fixedProfileImage != null && fixedProfileImage.isNotEmpty) {
        allImages.add(fixedProfileImage);
      }
    }

    // Check post images
    for (final img in images) {
      if (!img.contains('googleusercontent.com')) {
        hasNonGoogleImages = true;
      }
      final fixedImg = PhotoUrlHelper.fixGooglePhotoUrl(img);
      if (fixedImg != null && fixedImg.isNotEmpty) {
        allImages.add(fixedImg);
      }
    }

    // On web, if all images are Google photos, just show fallback immediately
    // to avoid CORS errors and rate limiting
    if (kIsWeb && !hasNonGoogleImages) {
      debugPrint('Skipping Google photo loading on web - showing fallback');
      return buildDefaultAvatar();
    }

    if (allImages.isEmpty) {
      return buildDefaultAvatar();
    }

    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemCount: allImages.length,
            itemBuilder: (context, index) {
              final imageUrl = allImages[index];
              debugPrint('Loading image at index $index: $imageUrl');

              // Validate URL before loading
              if (imageUrl.isEmpty) {
                return Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          index == 0 ? 'No Profile Image' : 'No Image',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Build fallback widget showing user initial
              Widget buildFallbackAvatar() {
                final initial = widget.userProfile.name.isNotEmpty
                    ? widget.userProfile.name[0].toUpperCase()
                    : '?';
                return Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.userProfile.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Use Image.network for Flutter Web to handle CORS better
              // CachedNetworkImage uses CanvasKit which has stricter CORS
              if (kIsWeb) {
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading image: $imageUrl');
                    debugPrint('Error details: $error');
                    // Check for rate limiting (429)
                    if (error.toString().contains('429')) {
                      PhotoUrlHelper.markAsRateLimited(imageUrl);
                    } else {
                      PhotoUrlHelper.markAsFailed(imageUrl);
                    }
                    return buildFallbackAvatar();
                  },
                );
              }

              return CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading image: $url');
                  debugPrint('Error details: $error');
                  // Check for rate limiting (429)
                  if (error.toString().contains('429')) {
                    PhotoUrlHelper.markAsRateLimited(url);
                  } else {
                    PhotoUrlHelper.markAsFailed(url);
                  }
                  return buildFallbackAvatar();
                },
              );
            },
          ),
          if (allImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  allImages.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.userProfile.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    UsernameBadge(
                      accountType: widget.userProfile.accountType,
                      verificationStatus: widget.userProfile.verification.status,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Account type badge row
          if (widget.userProfile.accountType != AccountType.personal) ...[
            const SizedBox(height: 12),
            AccountTypeBadge(
              accountType: widget.userProfile.accountType,
              verificationStatus: widget.userProfile.verification.status,
              showLabel: true,
              size: 18,
            ),
          ],
          const SizedBox(height: 8),
          if (widget.userProfile.location != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.userProfile.location!,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (widget.post != null)
            Text(
              widget.post!.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _buildPostDetails() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (widget.post != null)
            Text(
              widget.post!.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          if (widget.post?.price != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price', style: TextStyle(fontSize: 16)),
                  Text(
                    '${widget.post!.currency ?? '\$'}${widget.post!.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.post?.metadata != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Additional Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.post!.metadata.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startChat,
            icon: const Icon(Icons.chat_bubble),
            label: const Text('Start Chat'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startChat() {
    // Create initial message with post context
    String? initialMessage;
    if (widget.post != null) {
      initialMessage =
          'Hi! I\'m interested in your post: "${widget.post!.title}"';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedChatScreen(
          otherUser: widget.userProfile,
          initialMessage: initialMessage,
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

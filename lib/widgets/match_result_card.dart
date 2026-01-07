import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_profile.dart';
import '../models/business_model.dart';
import '../screens/business/profile_view/business_profile_screen.dart';
import '../screens/chat/enhanced_chat_screen.dart';
import '../services/business_service.dart';

/// Unified match result card that handles both P2P user matches and business matches.
///
/// This widget automatically determines whether to display a user card or business card
/// based on the `isBusinessPost` flag in the match data.
///
/// Usage:
/// ```dart
/// MatchResultCard(
///   matchData: matchMapFromService,
///   matchScore: 0.92,
///   onTap: () => handleTap(),
/// )
/// ```
class MatchResultCard extends StatelessWidget {
  final Map<String, dynamic> matchData;
  final double matchScore;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;

  const MatchResultCard({
    super.key,
    required this.matchData,
    required this.matchScore,
    this.onTap,
    this.onMessage,
    this.onCall,
  });

  bool get isBusinessMatch => matchData['isBusinessPost'] == true;

  @override
  Widget build(BuildContext context) {
    if (isBusinessMatch) {
      return _BusinessMatchCard(
        matchData: matchData,
        matchScore: matchScore,
        onTap: onTap,
        onMessage: onMessage,
        onCall: onCall,
      );
    } else {
      return _UserMatchCard(
        matchData: matchData,
        matchScore: matchScore,
        onTap: onTap,
        onMessage: onMessage,
      );
    }
  }
}

/// Card for displaying business matches
class _BusinessMatchCard extends StatefulWidget {
  final Map<String, dynamic> matchData;
  final double matchScore;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;

  const _BusinessMatchCard({
    required this.matchData,
    required this.matchScore,
    this.onTap,
    this.onMessage,
    this.onCall,
  });

  @override
  State<_BusinessMatchCard> createState() => _BusinessMatchCardState();
}

class _BusinessMatchCardState extends State<_BusinessMatchCard> {
  BusinessModel? _business;

  @override
  void initState() {
    super.initState();
    _loadBusinessDetails();
  }

  Future<void> _loadBusinessDetails() async {
    final businessId = widget.matchData['businessId'];
    if (businessId != null) {
      try {
        final business = await BusinessService().getBusiness(businessId);
        if (mounted) {
          setState(() {
            _business = business;
          });
        }
      } catch (e) {
        // Silently handle error - will use matchData fallback
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final matchPercent = (widget.matchScore * 100).toStringAsFixed(0);

    // Use data from matchData if business not loaded yet
    final businessName = _business?.businessName ??
        widget.matchData['businessName'] ??
        'Business';
    final businessLogo =
        _business?.logo ?? widget.matchData['businessLogo'];
    final businessType = _business?.businessType ??
        widget.matchData['businessCategory'] ??
        'Business';
    final coverImage = _business?.coverImage;
    final rating = _business?.rating ?? 0.0;
    final reviewCount = _business?.reviewCount ?? 0;
    final address = _business?.address;
    final isVerified = _business?.isVerified ?? false;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onTap != null) {
          widget.onTap!();
        } else if (_business != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessProfileScreen(businessId: _business!.id),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image section
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image
                    if (coverImage != null && coverImage.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            _buildCoverPlaceholder(isDarkMode),
                        errorWidget: (context, url, error) =>
                            _buildCoverPlaceholder(isDarkMode),
                      )
                    else
                      _buildCoverPlaceholder(isDarkMode),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),

                    // Match badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.matchScore >= 0.9
                              ? const Color(0xFF00D67D)
                              : widget.matchScore >= 0.75
                                  ? Colors.blue
                                  : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$matchPercent% Match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Business type badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              businessType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Logo at bottom
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: businessLogo != null && businessLogo.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: businessLogo,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      _buildLogoPlaceholder(businessName),
                                  errorWidget: (context, url, error) =>
                                      _buildLogoPlaceholder(businessName),
                                )
                              : _buildLogoPlaceholder(businessName),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and verification
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          businessName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D67D),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : 'New',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (reviewCount > 0)
                              Text(
                                ' ($reviewCount)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Post content/what they're offering
                  if (widget.matchData['title'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white10 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_quote,
                            size: 16,
                            color: const Color(0xFF00D67D),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.matchData['title'] ??
                                  widget.matchData['description'] ??
                                  '',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Location
                  if (address != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          address.city ?? address.formattedAddress,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        if (widget.matchData['distance'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDistance(widget.matchData['distance']),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onMessage,
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D67D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onCall,
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              isDarkMode ? Colors.white70 : Colors.grey[700],
                          side: BorderSide(
                            color:
                                isDarkMode ? Colors.white24 : Colors.grey[300]!,
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D67D),
            const Color(0xFF00D67D).withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(String name) {
    return Container(
      color: const Color(0xFF00D67D).withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'B',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D67D),
          ),
        ),
      ),
    );
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return '';
    final d = distance is double ? distance : double.tryParse(distance.toString()) ?? 0;
    if (d < 1) {
      return '${(d * 1000).toStringAsFixed(0)}m';
    }
    return '${d.toStringAsFixed(1)}km';
  }
}

/// Card for displaying user (P2P) matches
class _UserMatchCard extends StatelessWidget {
  final Map<String, dynamic> matchData;
  final double matchScore;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;

  const _UserMatchCard({
    required this.matchData,
    required this.matchScore,
    this.onTap,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userProfile = matchData['userProfile'] ?? {};
    final matchPercent = (matchScore * 100).toStringAsFixed(0);
    final userName = userProfile['name'] ?? 'User';
    final photoUrl = userProfile['photoUrl'];
    final city = userProfile['city'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          final otherUser = UserProfile.fromMap(userProfile, matchData['userId']);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: otherUser),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // User avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D67D),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (city != null && city.toString().isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: isDarkMode ? Colors.white54 : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                city.toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Match badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: matchScore >= 0.9
                          ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                          : matchScore >= 0.75
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: matchScore >= 0.9
                              ? const Color(0xFF00D67D)
                              : matchScore >= 0.75
                                  ? Colors.blue
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$matchPercent%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: matchScore >= 0.9
                                ? const Color(0xFF00D67D)
                                : matchScore >= 0.75
                                    ? Colors.blue
                                    : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Post content
              if (matchData['title'] != null ||
                  matchData['description'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white10 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Looking for:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00D67D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        matchData['title'] ?? matchData['description'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onMessage ?? onTap,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Start Conversation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D67D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

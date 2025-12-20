import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/photo_url_helper.dart';

class UserAvatar extends StatefulWidget {
  final String? profileImageUrl;
  final double radius;
  final String? fallbackText;

  const UserAvatar({
    super.key,
    this.profileImageUrl,
    this.radius = 20,
    this.fallbackText,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _hasError = false;

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileImageUrl != widget.profileImageUrl) {
      _hasError = false;
    }
  }

  String? _fixPhotoUrl(String? url) {
    return PhotoUrlHelper.fixGooglePhotoUrl(url);
  }

  Widget _buildFallback() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      color: Colors.grey.shade300,
      child: Center(
        child: widget.fallbackText?.isNotEmpty == true
            ? Text(
                widget.fallbackText![0].toUpperCase(),
                style: TextStyle(
                  fontSize: widget.radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              )
            : Icon(
                Icons.person,
                size: widget.radius,
                color: Colors.grey.shade600,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixedUrl = _fixPhotoUrl(widget.profileImageUrl);

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: (fixedUrl == null || _hasError)
            ? _buildFallback()
            : kIsWeb
                ? Image.network(
                    fixedUrl,
                    width: widget.radius * 2,
                    height: widget.radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_hasError) {
                          setState(() => _hasError = true);
                        }
                      });
                      PhotoUrlHelper.markAsFailed(fixedUrl);
                      return _buildFallback();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildFallback();
                    },
                  )
                : CachedNetworkImage(
                    imageUrl: fixedUrl,
                    width: widget.radius * 2,
                    height: widget.radius * 2,
                    fit: BoxFit.cover,
                    cacheKey: fixedUrl,
                    maxWidthDiskCache: 1024,
                    maxHeightDiskCache: 1024,
                    memCacheWidth: (widget.radius * 4).round(),
                    memCacheHeight: (widget.radius * 4).round(),
                    placeholder: (context, url) => _buildFallback(),
                    errorWidget: (context, url, error) {
                      if (error.toString().contains('429') &&
                          url.contains('googleusercontent.com')) {
                        PhotoUrlHelper.markAsRateLimited(url);
                      }
                      PhotoUrlHelper.markAsFailed(url);
                      return _buildFallback();
                    },
                  ),
      ),
    );
  }
}

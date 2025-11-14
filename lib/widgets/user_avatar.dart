import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/photo_url_helper.dart';

class UserAvatar extends StatelessWidget {
  final String? profileImageUrl;
  final double radius;
  final String? fallbackText;
  
  const UserAvatar({
    Key? key,
    this.profileImageUrl,
    this.radius = 20,
    this.fallbackText,
  }) : super(key: key);

  String? _fixPhotoUrl(String? url) {
    // Use the centralized helper with rate limiting protection
    return PhotoUrlHelper.fixGooglePhotoUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final fixedUrl = _fixPhotoUrl(profileImageUrl);
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: ClipOval(
        child: fixedUrl != null
            ? CachedNetworkImage(
                imageUrl: fixedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // Add longer cache duration with higher resolution
                cacheKey: fixedUrl,
                maxWidthDiskCache: 1024,  // Increased from 400 for better quality
                maxHeightDiskCache: 1024, // Increased from 400 for better quality
                memCacheWidth: (radius * 4).round(),  // Doubled for sharper images
                memCacheHeight: (radius * 4).round(), // Doubled for sharper images
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade300,
                  child: Icon(
                    Icons.person,
                    size: radius,
                    color: Colors.grey.shade600,
                  ),
                ),
                errorWidget: (context, url, error) {
                  // Mark URL as rate-limited if it's a 429 error
                  if (error.toString().contains('429') && url.contains('googleusercontent.com')) {
                    PhotoUrlHelper.markAsRateLimited(url);
                  }
                  // Use fallback silently
                  return Container(
                    color: Colors.grey.shade300,
                    child: Center(
                      child: Text(
                        fallbackText?.isNotEmpty == true 
                            ? fallbackText![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: radius * 0.8,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey.shade300,
                child: Center(
                  child: fallbackText?.isNotEmpty == true
                      ? Text(
                          fallbackText![0].toUpperCase(),
                          style: TextStyle(
                            fontSize: radius * 0.8,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: radius,
                          color: Colors.grey.shade600,
                        ),
                ),
              ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class PhotoUrlHelper {
  // Cache for rate-limited URLs to avoid repeated requests
  static final Map<String, DateTime> _rateLimitedUrls = {};
  static const Duration _rateLimitDuration = Duration(minutes: 10);

  // Cache for failed URLs to avoid repeated loading attempts
  static final Set<String> _failedUrls = {};

  // Track base URLs that have been rate-limited (to catch all size variants)
  static final Set<String> _rateLimitedBaseUrls = {};

  /// Fix and validate Google photo URLs
  static String? fixGooglePhotoUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Remove any trailing whitespace or special characters
    url = url.trim();

    // Extract base URL for rate-limit checking
    String baseUrl = _extractBaseUrl(url);

    // Check if this base URL was rate-limited
    if (_rateLimitedBaseUrls.contains(baseUrl)) {
      debugPrint('PhotoUrlHelper: Skipping rate-limited base URL: $baseUrl');
      return null;
    }

    // Check if URL was recently rate-limited
    if (_rateLimitedUrls.containsKey(url)) {
      final limitTime = _rateLimitedUrls[url]!;
      if (DateTime.now().difference(limitTime) < _rateLimitDuration) {
        // Return null to skip loading rate-limited images
        return null;
      } else {
        // Remove from rate-limited list after cooldown
        _rateLimitedUrls.remove(url);
      }
    }

    // Check if this URL has previously failed
    if (_failedUrls.contains(url)) {
      return null;
    }

    // Check if it's a Google user content URL
    if (url.contains('googleusercontent.com')) {
      // Use a very small size to minimize rate limiting
      // s96 is Google's default avatar size and is usually cached on their CDN
      if (kIsWeb) {
        return '$baseUrl=s96-c';
      } else {
        return '$baseUrl=s96-c';
      }
    }

    // For other URLs, return as is
    return url;
  }

  /// Extract the base URL without size parameters
  static String _extractBaseUrl(String url) {
    // Handle different parameter formats at the end of URL
    // Match patterns like =s200, =s400-c, =s96-c, =s0, =s400-c-rw, =s400-c-rj, etc.
    final paramRegex = RegExp(r'=s\d+(-[a-z]+)*$');
    if (paramRegex.hasMatch(url)) {
      return url.replaceAll(paramRegex, '');
    } else if (url.contains('=s')) {
      return url.split('=s')[0];
    }
    return url;
  }

  /// Mark a URL as failed (won't be attempted again in this session)
  static void markAsFailed(String url) {
    _failedUrls.add(url);
    // Also mark the base URL to prevent other size variants
    _failedUrls.add(_extractBaseUrl(url));
  }
  
  /// Mark a URL as rate-limited (429 error)
  static void markAsRateLimited(String url) {
    _rateLimitedUrls[url] = DateTime.now();
    // Also mark the base URL to prevent retrying with different size params
    final baseUrl = _extractBaseUrl(url);
    _rateLimitedBaseUrls.add(baseUrl);
    debugPrint('PhotoUrlHelper: Marked as rate-limited: $baseUrl');
  }
  
  /// Validate if a URL is properly formatted
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  /// Get a high quality version of Google profile photo with rate limiting protection
  static String? getHighQualityGooglePhoto(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Check if URL was recently rate-limited
    if (_rateLimitedUrls.containsKey(url)) {
      final limitTime = _rateLimitedUrls[url]!;
      if (DateTime.now().difference(limitTime) < _rateLimitDuration) {
        return null;
      } else {
        _rateLimitedUrls.remove(url);
      }
    }
    
    // For Google photos, request moderate resolution to avoid rate limiting
    if (url.contains('googleusercontent.com')) {
      // Remove any size parameters and add moderate quality
      final parts = url.split('=');
      if (parts.isNotEmpty) {
        final baseUrl = parts[0];
        // Use s200 for better rate limit handling
        return '$baseUrl=s200';  // 200x200 size
      }
    }
    
    return url;
  }
  
  /// Clean URL from any special characters that might cause issues
  static String? cleanUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Remove any non-printable characters
    url = url.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // Remove any trailing/leading whitespace
    url = url.trim();
    
    // Fix common URL issues
    url = url.replaceAll(' ', '%20');
    
    return url;
  }
}
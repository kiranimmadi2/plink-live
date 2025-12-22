class PhotoUrlHelper {
  // Cache for rate-limited URLs to avoid repeated requests
  static final Map<String, DateTime> _rateLimitedUrls = {};
  static const Duration _rateLimitDuration = Duration(minutes: 5);
  
  /// Fix and validate Google photo URLs
  static String? fixGooglePhotoUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    
    // Remove any trailing whitespace or special characters
    url = url.trim();
    
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
    
    // Check if it's a Google user content URL
    if (url.contains('googleusercontent.com')) {
      // Remove any existing size parameters
      final baseUrl = url.split('=s')[0];
      
      // Use a moderate size to reduce server load
      // Avoid s400-c which seems to cause issues, use s200 instead
      return '$baseUrl=s200';
    }
    
    // For other URLs, validate they have proper scheme and host
    if (!isValidUrl(url)) {
      return null;
    }
    return url;
  }
  
  /// Mark a URL as rate-limited
  static void markAsRateLimited(String url) {
    _rateLimitedUrls[url] = DateTime.now();
  }
  
  /// Validate if a URL is properly formatted with scheme and host
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.host.isNotEmpty;
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
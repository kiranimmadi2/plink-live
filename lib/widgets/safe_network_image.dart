import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/photo_url_helper.dart';

/// A network image widget that handles CORS issues on web platform.
/// Automatically uses Image.network for web and CachedNetworkImage for mobile.
class SafeNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  bool _hasError = false;

  @override
  void didUpdateWidget(SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasError = false;
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.image,
            color: Colors.grey.shade400,
            size: (widget.width ?? 48) / 2,
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? _buildPlaceholder();
  }

  @override
  Widget build(BuildContext context) {
    final fixedUrl = PhotoUrlHelper.fixGooglePhotoUrl(widget.imageUrl);

    if (fixedUrl == null || fixedUrl.isEmpty || _hasError) {
      return _buildErrorWidget();
    }

    Widget imageWidget;

    if (kIsWeb) {
      // Use Image.network for web to avoid CORS issues
      imageWidget = Image.network(
        fixedUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasError) {
              setState(() => _hasError = true);
            }
          });
          PhotoUrlHelper.markAsFailed(fixedUrl);
          return _buildErrorWidget();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    } else {
      // Use CachedNetworkImage for mobile platforms
      imageWidget = CachedNetworkImage(
        imageUrl: fixedUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          if (error.toString().contains('429')) {
            PhotoUrlHelper.markAsRateLimited(url);
          }
          PhotoUrlHelper.markAsFailed(url);
          return _buildErrorWidget();
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

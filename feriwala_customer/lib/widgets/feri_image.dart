import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Drop-in replacement for Image.network with caching, loading indicator, and error fallback.
class FeriImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallbackWidget;
  final BorderRadius? borderRadius;

  const FeriImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackWidget,
    this.borderRadius,
  });

  Widget _fallback() =>
      fallbackWidget ??
      Container(
        width: width,
        height: height,
        color: Colors.grey.shade100,
        child: const Center(child: Icon(Icons.checkroom, color: Colors.grey, size: 32)),
      );

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    if (src.isEmpty) return _fallback();

    Widget image = CachedNetworkImage(
      imageUrl: src,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF47721)),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

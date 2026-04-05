import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Motivasyon görselleri için ortak yükleme: bazı proxy/MinIO kurulumları
/// [User-Agent] / [Accept] olmadan 403 veya boş gövde döndürebilir.
class MotivationCachedImage extends StatelessWidget {
  const MotivationCachedImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, dynamic error)? error;

  static const Map<String, String> httpHeaders = {
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'User-Agent': 'DAHA/1.0 (Flutter)',
  };

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      httpHeaders: httpHeaders,
      placeholder:
          placeholder ?? (context, url) => Container(color: const Color(0xFF27272A)),
      errorWidget: (context, url, err) {
        if (kDebugMode) {
          final u = url;
          final short = u.length > 160 ? '${u.substring(0, 160)}…' : u;
          debugPrint('MotivationCachedImage failed: $short — $err');
        }
        if (error != null) return error!(context, url, err);
        return Container(color: const Color(0xFF27272A));
      },
    );
  }
}

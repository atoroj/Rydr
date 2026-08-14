import 'package:flutter/material.dart';
import '../api/api_constants.dart';

/// Avatar circular que pinta [imageUrl] si existe (resolviendo rutas
/// relativas del backend, p.ej. `/uploads/xxx.jpg`, contra la baseUrl de la
/// API) o, si no hay foto, la inicial de [fallbackName].
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackName,
    this.radius = 20,
    this.onTap,
  });

  final String? imageUrl;
  final String fallbackName;
  final double radius;
  final VoidCallback? onTap;

  /// Convierte una URL relativa (`/uploads/...`) en absoluta usando la
  /// baseUrl de la API. Las URLs ya absolutas (http/https) se dejan tal cual.
  static String resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiConstants.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final initial =
        fallbackName.isEmpty ? '?' : fallbackName[0].toUpperCase();

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: (url == null || url.isEmpty)
          ? null
          : NetworkImage(resolveUrl(url)),
      onForegroundImageError: (url == null) ? null : (_, __) {},
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

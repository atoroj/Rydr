import 'package:flutter/material.dart';
import 'network_avatar.dart';

/// Imagen de portada usada en tarjetas de ruta y moto: pinta [imageUrl] a
/// sangre (`BoxFit.cover`) o, si no hay foto, un icono de relleno sobre un
/// fondo neutro para que la tarjeta no se vea "rota".
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.imageUrl,
    this.fallbackIcon = Icons.map_outlined,
    this.height,
    this.borderRadius,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    final child = (url == null || url.isEmpty)
        ? placeholder
        : Image.network(
            NetworkAvatar.resolveUrl(url),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
          );

    final sized = SizedBox(height: height, width: double.infinity, child: child);

    if (borderRadius == null) return sized;
    return ClipRRect(borderRadius: borderRadius!, child: sized);
  }
}

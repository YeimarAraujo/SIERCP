import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

/// Logo SICAP que cambia según el tema:
/// tema claro → logo de color, tema oscuro → logo blanco.
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Fuerza la variante blanca (útil cuando el logo va sobre un fondo de marca,
  final bool forceWhite;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.forceWhite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useWhite = forceWhite || isDark;
    final asset = useWhite
        ? 'assets/images/SICAP/webp/logo_sicap_white.webp'
        : 'assets/images/SICAP/webp/logo_sicap.webp';

    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Icon(
        Icons.favorite,
        color: useWhite ? Colors.white : Color(0xFF1800AD),
        size: (width ?? height ?? 36) * 0.6,
      ),
    );
  }
}

/// Loader ligero para cargas parciales/pequeñas: muestra el logo SICAP
/// (según tema) con un pulso suave. Sin dependencias de video.
class AppLogoLoader extends StatefulWidget {
  final double size;
  final bool forceWhite;

  const AppLogoLoader({super.key, this.size = 64, this.forceWhite = false});

  @override
  State<AppLogoLoader> createState() => _AppLogoLoaderState();
}

class _AppLogoLoaderState extends State<AppLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    return Center(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1.0).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: AppLogo(width: widget.size, forceWhite: widget.forceWhite),
        ),
      ),
    );
  }
}

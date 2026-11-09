import 'package:flutter/material.dart';

/// Reglas de pantalla para toda la app: texto del sistema acotado y contenido
/// centrado en pantallas muy anchas, sin cambiar el diseño de cada vista.
class ResponsiveAppFrame extends StatelessWidget {
  const ResponsiveAppFrame({super.key, required this.child});

  /// Más allá de este ancho las listas y formularios dejan de ser legibles.
  static const double maxContentWidth = 1200;
  static const double compactWidth = 360;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final maxText = width < compactWidth ? 1.1 : 1.3;
    final scaled = media.copyWith(
      textScaler: media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: maxText),
    );

    if (width <= maxContentWidth) {
      return MediaQuery(data: scaled, child: child);
    }

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: maxContentWidth,
          child: MediaQuery(
            data: scaled.copyWith(size: Size(maxContentWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Columna que ocupa toda la pantalla y se desplaza si el alto no alcanza,
/// por ejemplo con un teléfono pequeño o en horizontal.
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

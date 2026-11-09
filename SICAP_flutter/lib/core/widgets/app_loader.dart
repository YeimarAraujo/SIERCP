import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:siercp/core/widgets/app_logo.dart';

const _kLoaderLight = 'assets/Animation/loop_carga_sicap.json';
const _kLoaderWhite = 'assets/Animation/loop_carga_white_sicap.json';

/// Loader de pantalla completa que reproduce en bucle la animación Lottie
/// correspondiente al tema:
/// tema claro → `loop_carga_sicap.json` (logo a color, para fondos claros),
/// tema oscuro → `loop_carga_white_sicap.json` (logo blanco, para fondos oscuros).
///
/// Lottie es vectorial y transparente, así que se compone sobre el fondo del
/// scaffold sin recuadros. Si la animación fallara al cargar, se muestra un
/// [AppLogoLoader] como respaldo.
class AppLoader extends StatelessWidget {
  /// Ocupa todo el espacio disponible con el fondo del scaffold.
  final bool fullScreen;

  /// Ancho máximo de la animación en píxeles.
  final double size;

  const AppLoader({super.key, this.fullScreen = true, this.size = 260});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark ? _kLoaderWhite : _kLoaderLight;

    final Widget content = SizedBox(
      width: size,
      child: Lottie.asset(
        asset,
        repeat: true,
        fit: BoxFit.contain,
        // Respaldo si el asset no se empaqueta o el JSON es inválido.
        errorBuilder: (context, error, stackTrace) =>
            AppLogoLoader(size: size * 0.5),
      ),
    );

    if (!fullScreen) return Center(child: content);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: content,
    );
  }
}

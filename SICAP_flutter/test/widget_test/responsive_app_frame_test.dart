import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siercp/core/widgets/responsive_app_frame.dart';

const _sizes = <Size>[
  Size(320, 480),
  Size(360, 640),
  Size(412, 915),
  Size(640, 360),
  Size(768, 1024),
  Size(1280, 800),
  Size(1920, 1080),
];

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: ResponsiveAppFrame(child: child!),
      ),
      home: home,
    );

/// Pantalla con la forma de las vistas sin lista: bloques, separadores y botones.
class _TallScreen extends StatelessWidget {
  const _TallScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScrollableFill(
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.domain_disabled_outlined, size: 96),
              const Text('Institución no asignada', style: TextStyle(fontSize: 22)),
              ...List.generate(4, (i) => const Text('Descripción larga del estado de la cuenta en varias líneas de texto para probar el ajuste')),
              const Spacer(),
              FilledButton(onPressed: () {}, child: const Text('Continuar')),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  for (final size in _sizes) {
    testWidgets('sin desbordes en ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const _TallScreen(), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Continuar'), findsOneWidget);
    });
  }

  testWidgets('el texto enorme del sistema queda acotado', (tester) async {
    late double scale;
    await tester.pumpWidget(_app(
      Builder(builder: (context) {
        scale = MediaQuery.textScalerOf(context).scale(1);
        return const SizedBox();
      }),
      textScale: 3,
    ));

    expect(scale, lessThanOrEqualTo(1.3));
  });

  testWidgets('en pantallas muy anchas el contenido no pasa del máximo', (tester) async {
    tester.view.physicalSize = const Size(2560, 1440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late double width;
    await tester.pumpWidget(_app(Builder(builder: (context) {
      width = MediaQuery.sizeOf(context).width;
      return const SizedBox();
    })));

    expect(width, ResponsiveAppFrame.maxContentWidth);
  });
}

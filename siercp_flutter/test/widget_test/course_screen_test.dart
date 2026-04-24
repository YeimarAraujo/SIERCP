// test/widget_test/courses_screen_test.dart
//
// RETO 4 — Pruebas de Widgets (mínimo 3)
// Valida componentes clave de la UI
// Ejecutar con: flutter test test/widget_test/courses_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Widget bajo prueba: Join Course Dialog ─────────────────────────────────
class _JoinDialogTest extends StatelessWidget {
  final VoidCallback? onJoin;
  const _JoinDialogTest({this.onJoin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('Unirse a un curso'),
                content: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Código del curso',
                    hintText: 'Ej: X9J2P1',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: onJoin,
                    child: const Text('Unirse'),
                  ),
                ],
              ),
            ),
            child: const Text('Abrir dialog'),
          ),
        ),
      ),
    );
  }
}

// ── Widget bajo prueba: Course Card ───────────────────────────────────────────
class _CourseCardTest extends StatelessWidget {
  final String title;
  final double progress;
  const _CourseCardTest({required this.title, required this.progress});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, key: const Key('course_title')),
              LinearProgressIndicator(
                value: progress,
                key: const Key('course_progress'),
              ),
              Text(
                '${(progress * 100).toInt()}% completado',
                key: const Key('progress_label'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget bajo prueba: Score Badge ───────────────────────────────────────────
class _ScoreBadgeTest extends StatelessWidget {
  final double score;
  const _ScoreBadgeTest({required this.score});

  Color get _color {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          key: const Key('score_badge'),
          color: _color,
          child: Text(
            '${score.toStringAsFixed(0)}%',
            key: const Key('score_text'),
          ),
        ),
      ),
    );
  }
}

// ─── TESTS ────────────────────────────────────────────────────────────────────
void main() {
  // ── Widget Test 1: Dialog "Unirse a curso" se muestra correctamente ────────
  testWidgets('Join dialog muestra campo de código y botón Unirse',
      (tester) async {
    await tester.pumpWidget(const _JoinDialogTest());
    await tester.tap(find.text('Abrir dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Unirse a un curso'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Unirse'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  // ── Widget Test 2: Course Card muestra título y progreso ─────────────────
  testWidgets('Course card renderiza título y barra de progreso',
      (tester) async {
    await tester.pumpWidget(
      const _CourseCardTest(title: 'Curso RCP Básico', progress: 0.6),
    );
    await tester.pump();

    expect(find.text('Curso RCP Básico'), findsOneWidget);
    expect(find.byKey(const Key('course_progress')), findsOneWidget);
    expect(find.text('60% completado'), findsOneWidget);
  });

  // ── Widget Test 3: Score badge color correcto según puntaje ──────────────
  testWidgets('Score badge es verde cuando score >= 85', (tester) async {
    await tester.pumpWidget(const _ScoreBadgeTest(score: 92));
    await tester.pump();

    final badge =
        tester.widget<Container>(find.byKey(const Key('score_badge')));
    expect(badge.color, equals(Colors.green));
    expect(find.text('92%'), findsOneWidget);
  });

  testWidgets('Score badge es rojo cuando score < 70', (tester) async {
    await tester.pumpWidget(const _ScoreBadgeTest(score: 55));
    await tester.pump();

    final badge =
        tester.widget<Container>(find.byKey(const Key('score_badge')));
    expect(badge.color, equals(Colors.red));
  });

  // ── Widget Test 4: Dialog se cierra al presionar Cancelar ────────────────
  testWidgets('Dialog se cierra al presionar Cancelar', (tester) async {
    await tester.pumpWidget(const _JoinDialogTest());
    await tester.tap(find.text('Abrir dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Unirse a un curso'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Unirse a un curso'), findsNothing);
  });
}

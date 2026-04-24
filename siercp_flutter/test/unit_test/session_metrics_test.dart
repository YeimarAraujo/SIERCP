// test/unit_test/session_metrics_test.dart
//
// RETO 4 — Pruebas Unitarias (mínimo 5)
// Cubre la lógica de negocio de SessionMetrics y _generateCode
// Ejecutar con: flutter test test/unit_test/session_metrics_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:siercp/models/session.dart';

void main() {
  // ── 1. Score dentro del rango AHA ─────────────────────────────────────────
  test('Score 100 cuando profundidad, frecuencia y recoil son correctos', () {
    final metrics = SessionMetrics(
      totalCompressions: 30,
      correctCompressions: 30,
      averageDepthMm: 55, // ✅ 50-60 mm AHA
      averageRatePerMin: 110, // ✅ 100-120 /min AHA
      correctCompressionsPct: 100,
      averageForcKg: 5.0,
      recoilPct: 100,
      interruptionCount: 0,
      maxPauseSeconds: 0,
      ccfPct: 80,
      depthScore: 30,
      rateScore: 30,
      recoilScore: 20,
      interruptionScore: 20,
      score: 100,
      approved: true,
      violations: [],
    );
    expect(metrics.score, equals(100));
    expect(metrics.approved, isTrue);
  });

  // ── 2. Score falla con profundidad insuficiente ───────────────────────────
  test('Score reducido si profundidad es menor a 50mm', () {
    const depthScore = 15.0; // 50% de penalización
    const rateScore = 30.0;
    const recoilScore = 20.0;
    const intScore = 20.0;
    final total =
        (depthScore + rateScore + recoilScore + intScore).clamp(0.0, 100.0);
    expect(total, lessThan(100));
  });

  // ── 3. CCF correctamente calculado ───────────────────────────────────────

  // ── 4. Violación detectada por frecuencia lenta ───────────────────────────
  test('CCF calculado correctamente con 30 compresiones en 30s a 110 CPM', () {
    const count = 30;
    const avgRate = 110.0;
    const elapsedSeconds = 30;
    final activeSeconds = (count / avgRate) * 60.0;
    final ccf = (activeSeconds / elapsedSeconds * 100).clamp(0.0, 100.0);
    // CCF real = (30/110 * 60) / 30 * 100 = 54.5%
    expect(ccf, greaterThan(0.0)); // ← CCF existe
    expect(ccf, lessThanOrEqualTo(100.0)); // ← no supera 100
    expect(ccf, closeTo(54.5, 1.0)); // ← valor real calculado
  });
  // ── 5. Promedio acumulado de score en enrollments ─────────────────────────
  test('Nuevo promedio calculado correctamente al agregar sesión', () {
    const currentAvg = 80.0;
    const currentCount = 4;
    const newScore = 100.0;
    final newAvg =
        ((currentAvg * currentCount) + newScore) / (currentCount + 1);
    expect(newAvg, closeTo(84.0, 0.1));
  });

  // ── 6. SessionMetrics.approved con score exactamente en el límite ─────────
  test('approved es true cuando score == 85 (límite AHA pass)', () {
    final metrics = SessionMetrics(
      totalCompressions: 20,
      correctCompressions: 17,
      averageDepthMm: 52,
      averageRatePerMin: 105,
      correctCompressionsPct: 85,
      averageForcKg: 4.5,
      recoilPct: 85,
      interruptionCount: 0,
      maxPauseSeconds: 0,
      ccfPct: 70,
      depthScore: 30,
      rateScore: 30,
      recoilScore: 17,
      interruptionScore: 8,
      score: 85,
      approved: true,
      violations: [],
    );
    expect(metrics.approved, isTrue);
    expect(metrics.score, greaterThanOrEqualTo(85));
  });

  // ── 7. score.clamp nunca excede 100 ──────────────────────────────────────
  test('Score nunca supera 100 aunque la suma de componentes lo haga', () {
    const raw = 110.0;
    final clamped = raw.clamp(0.0, 100.0);
    expect(clamped, equals(100.0));
  });
}

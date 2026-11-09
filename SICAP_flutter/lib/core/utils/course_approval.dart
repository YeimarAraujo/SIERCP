import 'package:siercp/core/constants/constants.dart';

/// Nota oficial de una sesión, calculada por el servidor desde la señal del
/// maniquí (`sessions/{id}.officialGrade`). La app no la puede escribir.
class OfficialGrade {
  const OfficialGrade({
    required this.score,
    required this.compressions,
    required this.correctDepth,
    required this.fullRecoil,
    required this.correctRate,
  });

  final double score;
  final int compressions;
  final int correctDepth;
  final int fullRecoil;
  final int correctRate;

  /// null si el servidor no pudo calificar (sin señal guardada).
  static OfficialGrade? fromMap(Object? raw) {
    if (raw is! Map || raw['unavailable'] == true || raw['score'] is! num) return null;
    int n(String key) => (raw[key] as num?)?.toInt() ?? 0;
    return OfficialGrade(
      score: (raw['score'] as num).toDouble(),
      compressions: n('compressions'),
      correctDepth: n('correctDepth'),
      fullRecoil: n('fullRecoil'),
      correctRate: n('correctRate'),
    );
  }
}

/// Aprobación del curso y del certificado (misma regla que la web,
/// SICAP-WEB/src/lib/course-approval.ts). Decidida por el usuario el
/// 2026-11-09; debe validarla un instructor certificado:
///   - promedio de notas oficiales ≥ nota mínima del curso (80 por defecto);
///   - sumando todas las sesiones, ≥ 70 % de compresiones con profundidad
///     correcta, ≥ 70 % con retroceso completo y ≥ 70 % con ritmo correcto.
/// La sesión de práctica sigue aprobando con 70: es solo retroalimentación.
class CourseApproval {
  const CourseApproval({
    required this.approved,
    required this.sessionCount,
    required this.averageScore,
    required this.minScore,
    required this.depthPct,
    required this.recoilPct,
    required this.ratePct,
    required this.missing,
  });

  final bool approved;
  final int sessionCount;
  final double averageScore;
  final double minScore;
  final double depthPct;
  final double recoilPct;
  final double ratePct;
  final List<String> missing;

  bool get partsMet =>
      depthPct >= AppConstants.coursePartMinPct &&
      recoilPct >= AppConstants.coursePartMinPct &&
      ratePct >= AppConstants.coursePartMinPct;

  static CourseApproval evaluate(Iterable<OfficialGrade> grades, {double? courseMinScore}) {
    final list = grades.toList();
    final minScore = (courseMinScore ?? 0) > 0
        ? courseMinScore!
        : AppConstants.coursePassAverage.toDouble();
    final average = list.isEmpty
        ? 0.0
        : (list.fold<double>(0, (sum, g) => sum + g.score) / list.length).roundToDouble();
    final total = list.fold<int>(0, (sum, g) => sum + g.compressions);
    double pct(int Function(OfficialGrade) part) => total == 0
        ? 0
        : (list.fold<int>(0, (sum, g) => sum + part(g)) / total * 1000).round() / 10;
    final depth = pct((g) => g.correctDepth);
    final recoil = pct((g) => g.fullRecoil);
    final rate = pct((g) => g.correctRate);
    const partMin = AppConstants.coursePartMinPct;

    String fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
    final missing = <String>[
      if (list.isEmpty) 'Aún no hay sesiones con nota oficial.',
      if (list.isNotEmpty && average < minScore)
        'Promedio de ${fmt(average)}; se necesita ${fmt(minScore)}.',
      if (list.isNotEmpty && depth < partMin)
        'Profundidad correcta en ${fmt(depth)} % de las compresiones; se necesita $partMin %.',
      if (list.isNotEmpty && recoil < partMin)
        'Retroceso completo en ${fmt(recoil)} % de las compresiones; se necesita $partMin %.',
      if (list.isNotEmpty && rate < partMin)
        'Ritmo correcto en ${fmt(rate)} % de las compresiones; se necesita $partMin %.',
    ];

    return CourseApproval(
      approved: missing.isEmpty,
      sessionCount: list.length,
      averageScore: average,
      minScore: minScore,
      depthPct: depth,
      recoilPct: recoil,
      ratePct: rate,
      missing: missing,
    );
  }
}

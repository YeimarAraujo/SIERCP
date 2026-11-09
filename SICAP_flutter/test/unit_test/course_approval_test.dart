import 'package:flutter_test/flutter_test.dart';
import 'package:siercp/core/utils/course_approval.dart';

const good = OfficialGrade(score: 90, compressions: 100, correctDepth: 90, fullRecoil: 95, correctRate: 85);

OfficialGrade grade({double score = 90, int depth = 90, int recoil = 95, int rate = 85}) =>
    OfficialGrade(score: score, compressions: 100, correctDepth: depth, fullRecoil: recoil, correctRate: rate);

void main() {
  test('aprueba con promedio de 80 o más y 70 % en cada parte', () {
    final r = CourseApproval.evaluate([good, grade(score: 80)]);
    expect(r.approved, isTrue);
    expect(r.averageScore, 85);
    expect(r.minScore, 80);
  });

  test('sesiones que aprueban con 70 no bastan si el promedio queda bajo 80', () {
    final r = CourseApproval.evaluate([grade(score: 75), grade(score: 78)]);
    expect(r.approved, isFalse);
    expect(r.missing.first, contains('Promedio de 77'));
  });

  test('una parte bajo 70 % impide aprobar aunque el promedio sea alto', () {
    final r = CourseApproval.evaluate([grade(rate: 60)]);
    expect(r.approved, isFalse);
    expect(r.ratePct, 60);
    expect(r.partsMet, isFalse);
  });

  test('suma las compresiones de todas las sesiones', () {
    final r = CourseApproval.evaluate([grade(depth: 100), grade(depth: 40)]);
    expect(r.depthPct, 70);
    expect(r.approved, isTrue);
  });

  test('respeta la nota mínima definida por el instructor', () {
    expect(CourseApproval.evaluate([good], courseMinScore: 95).approved, isFalse);
  });

  test('sin notas oficiales no aprueba', () {
    expect(CourseApproval.evaluate([]).approved, isFalse);
    expect(OfficialGrade.fromMap({'unavailable': true}), isNull);
    expect(OfficialGrade.fromMap({'score': 88, 'compressions': 10})?.score, 88);
  });
}

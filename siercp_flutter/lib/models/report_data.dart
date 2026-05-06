import '../models/session.dart';
import '../core/constants.dart';

class StudentReportData {
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final List<SessionModel> sessions;
  final DateTime generatedAt;

  // Stats
  final double avgScore;
  final double bestScore;
  final double avgDepthMm;
  final double avgRatePerMin;
  final int approvedCount;
  final int totalCount;

  StudentReportData({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.sessions,
    required this.generatedAt,
    required this.avgScore,
    required this.bestScore,
    required this.avgDepthMm,
    required this.avgRatePerMin,
    required this.approvedCount,
    required this.totalCount,
  });

  factory StudentReportData.fromSessions({
    required String studentId,
    required String studentName,
    required String courseId,
    required String courseName,
    required List<SessionModel> sessions,
  }) {
    final completed = sessions.where((s) => s.metrics != null).toList();
    double avgScore = 0, bestScore = 0, avgDepth = 0, avgRate = 0;
    int approved = 0;

    if (completed.isNotEmpty) {
      final scores = completed.map((s) => s.metrics!.score).toList();
      avgScore = scores.reduce((a, b) => a + b) / scores.length;
      bestScore = scores.reduce((a, b) => a > b ? a : b);
      avgDepth = completed.map((s) => s.metrics!.averageDepthMm).reduce((a, b) => a + b) / completed.length;
      avgRate = completed.map((s) => s.metrics!.averageRatePerMin).reduce((a, b) => a + b) / completed.length;
      approved = completed.where((s) => s.metrics!.approved).length;
    }

    return StudentReportData(
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      courseName: courseName,
      sessions: sessions,
      generatedAt: DateTime.now(),
      avgScore: avgScore,
      bestScore: bestScore,
      avgDepthMm: avgDepth,
      avgRatePerMin: avgRate,
      approvedCount: approved,
      totalCount: completed.length,
    );
  }
}

class CourseReportData {
  final String courseId;
  final String courseTitle;
  final List<Map<String, dynamic>> students;
  final Map<String, List<SessionModel>> studentSessions;
  final DateTime generatedAt;

  // Stats
  final int totalStudents;
  final int totalSessions;
  final double globalAvgScore;
  final int totalApproved;

  CourseReportData({
    required this.courseId,
    required this.courseTitle,
    required this.students,
    required this.studentSessions,
    required this.generatedAt,
    required this.totalStudents,
    required this.totalSessions,
    required this.globalAvgScore,
    required this.totalApproved,
  });

  factory CourseReportData.fromData({
    required String courseId,
    required String courseTitle,
    required List<Map<String, dynamic>> students,
    required Map<String, List<SessionModel>> studentSessions,
  }) {
    int totalSessions = 0, totalApproved = 0;
    double sumScores = 0;
    int withScores = 0;

    for (final entry in studentSessions.entries) {
      for (final s in entry.value) {
        totalSessions++;
        if (s.metrics != null) {
          withScores++;
          sumScores += s.metrics!.score;
          if (s.metrics!.approved) totalApproved++;
        }
      }
    }

    return CourseReportData(
      courseId: courseId,
      courseTitle: courseTitle,
      students: students,
      studentSessions: studentSessions,
      generatedAt: DateTime.now(),
      totalStudents: students.length,
      totalSessions: totalSessions,
      globalAvgScore: withScores > 0 ? sumScores / withScores : 0.0,
      totalApproved: totalApproved,
    );
  }
}

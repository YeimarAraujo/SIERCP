import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_data.dart';
import '../models/session.dart';

class ReportCache {
  final Map<String, StudentReportData> studentReports;
  final Map<String, CourseReportData> courseReports;
  final Map<String, DateTime> timestamps;

  ReportCache({
    this.studentReports = const {},
    this.courseReports = const {},
    this.timestamps = const {},
  });

  ReportCache copyWith({
    Map<String, StudentReportData>? studentReports,
    Map<String, CourseReportData>? courseReports,
    Map<String, DateTime>? timestamps,
  }) {
    return ReportCache(
      studentReports: studentReports ?? this.studentReports,
      courseReports: courseReports ?? this.courseReports,
      timestamps: timestamps ?? this.timestamps,
    );
  }
}

class ReportCacheNotifier extends StateNotifier<ReportCache> {
  ReportCacheNotifier() : super(ReportCache());

  void cacheStudentReport(StudentReportData data) {
    final key = '${data.studentId}_${data.courseId}';
    state = state.copyWith(
      studentReports: {...state.studentReports, key: data},
      timestamps: {...state.timestamps, key: DateTime.now()},
    );
  }

  void cacheCourseReport(CourseReportData data) {
    final key = data.courseId;
    state = state.copyWith(
      courseReports: {...state.courseReports, key: data},
      timestamps: {...state.timestamps, key: DateTime.now()},
    );
  }

  StudentReportData? getStudentReport(String studentId, String courseId) {
    final key = '${studentId}_${courseId}';
    final report = state.studentReports[key];
    if (report == null) return null;

    // Check expiration (3 days)
    final timestamp = state.timestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp).inDays >= 3) {
      invalidateStudentReport(studentId, courseId);
      return null;
    }
    return report;
  }

  CourseReportData? getCourseReport(String courseId) {
    final key = courseId;
    final report = state.courseReports[key];
    if (report == null) return null;

    final timestamp = state.timestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp).inDays >= 3) {
      invalidateCourseReport(courseId);
      return null;
    }
    return report;
  }

  void invalidateStudentReport(String studentId, String courseId) {
    final key = '${studentId}_${courseId}';
    final newReports = Map<String, StudentReportData>.from(state.studentReports)..remove(key);
    final newTimestamps = Map<String, DateTime>.from(state.timestamps)..remove(key);
    state = state.copyWith(studentReports: newReports, timestamps: newTimestamps);
  }

  void invalidateCourseReport(String courseId) {
    final key = courseId;
    final newReports = Map<String, CourseReportData>.from(state.courseReports)..remove(key);
    final newTimestamps = Map<String, DateTime>.from(state.timestamps)..remove(key);
    state = state.copyWith(courseReports: newReports, timestamps: newTimestamps);
  }

  void clearOldReports() {
    final now = DateTime.now();
    final expiredKeys = state.timestamps.entries
        .where((e) => now.difference(e.value).inDays >= 1) // Clean daily
        .map((e) => e.key)
        .toList();

    if (expiredKeys.isEmpty) return;

    final newStudentReports = Map<String, StudentReportData>.from(state.studentReports);
    final newCourseReports = Map<String, CourseReportData>.from(state.courseReports);
    final newTimestamps = Map<String, DateTime>.from(state.timestamps);

    for (final key in expiredKeys) {
      newStudentReports.remove(key);
      newCourseReports.remove(key);
      newTimestamps.remove(key);
    }

    state = state.copyWith(
      studentReports: newStudentReports,
      courseReports: newCourseReports,
      timestamps: newTimestamps,
    );
  }
}

final reportCacheProvider = StateNotifierProvider<ReportCacheNotifier, ReportCache>((ref) {
  return ReportCacheNotifier();
});

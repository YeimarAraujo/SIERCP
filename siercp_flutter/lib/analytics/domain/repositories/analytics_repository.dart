import '../../data/models/analytics_models.dart';
import '../../data/datasources/analytics_local_datasource.dart';

class AnalyticsRepository {
  final AnalyticsLocalDatasource _datasource;

  AnalyticsRepository(this._datasource);

  Future<List<AnalyticsEvent>> getEvents(DateRangeFilter range) async {
    final now = DateTime.now();
    DateTime start;

    switch (range) {
      case DateRangeFilter.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case DateRangeFilter.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case DateRangeFilter.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case DateRangeFilter.custom: // For now fallback to last 90 days
        start = now.subtract(const Duration(days: 90));
        break;
    }

    return await _datasource.getEventsByDateRange(start, now);
  }

  Future<void> ensureDummyData() async {
    await _datasource.generateDummyData();
  }
}

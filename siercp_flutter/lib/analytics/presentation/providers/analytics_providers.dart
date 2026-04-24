import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/analytics_local_datasource.dart';
import '../../data/models/analytics_models.dart';
import '../../domain/repositories/analytics_repository.dart';

final analyticsDatasourceProvider = Provider<AnalyticsLocalDatasource>((ref) {
  return AnalyticsLocalDatasource();
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(analyticsDatasourceProvider));
});

final dateRangeProvider = StateProvider<DateRangeFilter>((ref) => DateRangeFilter.month);

final eventsProvider = FutureProvider<List<AnalyticsEvent>>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  await repo.ensureDummyData(); // Just for demonstration
  return repo.getEvents(ref.watch(dateRangeProvider));
});

final kpisProvider = FutureProvider<AnalyticsKPIs>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  if (events.isEmpty) return AnalyticsKPIs.empty();

  double totalScore = 0.0;
  int totalCompressions = 0;

  for (var event in events) {
    totalScore += event.value;
    try {
      if (event.metadata.isNotEmpty) {
        final meta = jsonDecode(event.metadata);
        totalCompressions += (meta['compressions'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
  }

  // Assume 3 minutes per session for total time calculation
  final totalTimeHours = (events.length * 3.0) / 60.0;

  return AnalyticsKPIs(
    totalSessions: events.length,
    avgScore: totalScore / events.length,
    totalTimeHours: totalTimeHours,
    totalCompressions: totalCompressions,
  );
});

final chartsDataProvider = FutureProvider<ChartsData>((ref) async {
  final events = await ref.watch(eventsProvider.future);
  if (events.isEmpty) return ChartsData.empty();

  final Map<String, int> catDist = {};
  final Map<DateTime, double> scoreTime = {};
  final List<Map<String, double>> scatter = [];
  int adultCount = 0;
  int pedCount = 0;

  for (var event in events) {
    catDist[event.category] = (catDist[event.category] ?? 0) + 1;
    if (event.category == 'Adulto') adultCount++;
    if (event.category == 'Pediátrico') pedCount++;
    
    // Simplification: one point per day (overwriting earlier ones in same day, or we could average)
    // To keep it simple, just taking the event's raw datetime. In a real app we'd group by day.
    scoreTime[event.timestamp] = event.value;

    try {
      if (event.metadata.isNotEmpty) {
        final meta = jsonDecode(event.metadata);
        final depth = (meta['depth'] as num?)?.toDouble() ?? 0.0;
        final rate = (meta['rate'] as num?)?.toDouble() ?? 0.0;
        scatter.add({'depth': depth, 'rate': rate});
      }
    } catch (_) {}
  }

  final pieDist = {
    'Adulto': (adultCount / events.length) * 100,
    'Pediátrico': (pedCount / events.length) * 100,
  };

  return ChartsData(
    categoryDistribution: catDist,
    scoreOverTime: scoreTime,
    scatterPoints: scatter,
    pieDistribution: pieDist,
  );
});

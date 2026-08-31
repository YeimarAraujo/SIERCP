enum DateRangeFilter { today, week, month, custom }

class AnalyticsEvent {
  final int? id;
  final DateTime timestamp;
  final String category;
  final double value;
  final String metadata;

  AnalyticsEvent({
    this.id,
    required this.timestamp,
    required this.category,
    required this.value,
    this.metadata = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'value': value,
      'metadata': metadata,
    };
  }

  factory AnalyticsEvent.fromMap(Map<String, dynamic> map) {
    return AnalyticsEvent(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      category: map['category'] as String,
      value: (map['value'] as num).toDouble(),
      metadata: map['metadata'] as String,
    );
  }
}

class AnalyticsKPIs {
  final int totalSessions;
  final double avgScore;
  final double totalTimeHours;
  final int totalCompressions;

  const AnalyticsKPIs({
    required this.totalSessions,
    required this.avgScore,
    required this.totalTimeHours,
    required this.totalCompressions,
  });

  factory AnalyticsKPIs.empty() => const AnalyticsKPIs(
        totalSessions: 0,
        avgScore: 0.0,
        totalTimeHours: 0.0,
        totalCompressions: 0,
      );
}

class ChartsData {
  final Map<String, int> categoryDistribution;
  final Map<DateTime, double> scoreOverTime;
  final List<Map<String, double>> scatterPoints; // depth vs rate
  final Map<String, double> pieDistribution;

  const ChartsData({
    required this.categoryDistribution,
    required this.scoreOverTime,
    required this.scatterPoints,
    required this.pieDistribution,
  });

  factory ChartsData.empty() => const ChartsData(
        categoryDistribution: {},
        scoreOverTime: {},
        scatterPoints: [],
        pieDistribution: {},
      );
}

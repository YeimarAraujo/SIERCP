import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/analytics_models.dart';

class AnalyticsLocalDatasource {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'analytics_siercp.db'); // Separated DB for analytics isolation
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE analytics_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME,
            category TEXT,
            value REAL,
            metadata TEXT
          )
        ''');
      },
    );
  }

  Future<List<AnalyticsEvent>> getEventsByDateRange(DateTime start, DateTime end) async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'analytics_events',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => AnalyticsEvent.fromMap(maps[i]));
  }

  Future<void> saveEvent(AnalyticsEvent event) async {
    final dbClient = await db;
    await dbClient.insert(
      'analytics_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAll() async {
    final dbClient = await db;
    await dbClient.delete('analytics_events');
  }

  // Generar datos Dummy de entrenamiento si la base de datos está vacía
  Future<void> generateDummyData() async {
    final dbClient = await db;
    final count = Sqflite.firstIntValue(await dbClient.rawQuery('SELECT COUNT(*) FROM analytics_events'));
    if (count != null && count > 0) return;

    final now = DateTime.now();
    for (int i = 0; i < 100; i++) {
      final date = now.subtract(Duration(days: (100 - i) ~/ 3));
      final isAdult = (i % 3) == 0;
      final category = isAdult ? 'Adulto' : 'Pediátrico';
      final score = 60.0 + (i % 40); // 60 a 100
      final depth = isAdult ? 50.0 + (i % 15) : 35.0 + (i % 15);
      final rate = 95.0 + (i % 30);
      
      await saveEvent(AnalyticsEvent(
        timestamp: date,
        category: category,
        value: score,
        metadata: '{"depth": $depth, "rate": $rate, "compressions": ${100 + i}}',
      ));
    }
  }
}

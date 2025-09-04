import 'package:sqflite/sqflite.dart';
import 'package:lift_league/services/db_service.dart';
import 'package:lift_league/data/lift_catalog_seed.dart';

class LiftCatalogService {
  LiftCatalogService._();
  static final instance = LiftCatalogService._();

  Future<Database> get _db async => DBService.instance.database;

  /// Seed the catalogue once (idempotent).
  Future<void> ensureSeeded() async {
    final db = await _db;
    final c = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(1) FROM lift_catalog'),
    ) ?? 0;
    if (c > 0) return;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final r in kLiftCatalogSeed) {
      batch.insert('lift_catalog', {
        'name': r['name'],
        'primaryGroup': r['primaryGroup'],
        'equipment': r['equipment'],
        'isBodyweightCapable': (r['isBodyweightCapable'] ?? 0) as int,
        'isDumbbellCapable': (r['isDumbbellCapable'] ?? 0) as int,
        'unilateral': (r['unilateral'] ?? 0) as int,
        'createdAt': ts,
        'updatedAt': ts,
      });
    }
    await batch.commit(noResult: true);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lc_group ON lift_catalog(primaryGroup);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lc_name  ON lift_catalog(name);');
  }

  /// Distinct primary groups (e.g., Chest, Back, Legs…)
  Future<List<String>> getGroups() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT primaryGroup FROM lift_catalog ORDER BY primaryGroup',
    );
    return rows
        .map((r) => (r['primaryGroup'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Query the catalogue with optional filters.
  Future<List<Map<String, Object?>>> query({
    String? group,
    String? queryText,
    bool? bodyweightCapable,
    bool? dumbbellCapable,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _db;

    final where = <String>[];
    final args  = <Object?>[];

    if (group != null && group.trim().isNotEmpty) {
      where.add('primaryGroup = ?'); args.add(group.trim());
    }
    if (queryText != null && queryText.trim().isNotEmpty) {
      where.add('name LIKE ?'); args.add('%${queryText.trim()}%');
    }
    if (bodyweightCapable == true) where.add('isBodyweightCapable = 1');
    if (dumbbellCapable == true)  where.add('isDumbbellCapable = 1');

    final sql = '''
      SELECT id AS catalogId,
             name,
             primaryGroup,
             equipment,
             isBodyweightCapable,
             isDumbbellCapable,
             unilateral
        FROM lift_catalog
       ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
       ORDER BY name
       LIMIT ? OFFSET ?
    ''';
    args..add(limit)..add(offset);
    return db.rawQuery(sql, args);
  }
}

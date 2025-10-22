// dart run lib/dev/build_seed_db.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lift_league/dev/lift_data.dart' as liftsSrc;
import 'package:lift_league/services/schema_sql.dart';

import 'catalog_generator.dart';
import 'stock_templates_generator.dart';

const _seedDir = 'assets/db';

String seedRelPath(int v) => 'assets/db/seed_v$v.db';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final outDir = Directory(p.join(Directory.current.path, _seedDir));
  await outDir.create(recursive: true);

  final seedFileName = 'seed_v${SCHEMA_USER_VERSION}.db';
  final outPath = p.normalize(p.join(outDir.path, seedFileName));
  final outFile = File(outPath);
  if (outFile.existsSync()) outFile.deleteSync();

  final db = await databaseFactory.openDatabase(outPath);

  try {
    // 1) Schema
    await _executeAll(db, schemaCreateStatements);

    // 2) Reference data: lift_catalog
      const catalogTimestamp = 1704067200000; // 2024-01-01T00:00:00Z
      final catalogRows = generateLiftCatalog(startId: 1, timestamp: catalogTimestamp);
      final catalogBatch = db.batch();
      for (final row in catalogRows) {
        catalogBatch.insert('lift_catalog', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await catalogBatch.commit(noResult: true);

      // 3) Core lookup tables from runtime defaults (lifts + stock templates)
      await _insertLifts(db);

      // 3) Stock templates
      final stock = generateStockTemplates();
      await db.transaction((txn) async {
          for (final workout in stock.workouts) {
            await txn.insert('workouts', workout, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final block in stock.blocks) {
            await txn.insert('blocks', block, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final wb in stock.workoutsBlocks) {
            await txn.insert('workouts_blocks', wb, conflictAlgorithm: ConflictAlgorithm.replace);
          }
            for (final lw in stock.liftWorkouts) {
              await txn.insert('lift_workouts', lw, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });

        // 4) Indexes / PRAGMAs / version
        await _executeAll(db, schemaIndexStatements);
        await db.execute('PRAGMA user_version = $SCHEMA_USER_VERSION;');

        // Basic validation / counts for the console log
        final liftCount = await _countRows(db, 'lifts');
        final catalogCount = await _countRows(db, 'lift_catalog');
        final workoutCount = await _countRows(db, 'workouts');
        print('Seed stats → lifts: $liftCount, catalog: $catalogCount, workouts: $workoutCount');

        // 5) Finalize
        await db.execute('PRAGMA optimize;');
        await db.execute('VACUUM;');
        print('Seed DB written to: $outPath');
        } finally {
        await db.close();
        }
      }

          Future<void> _executeAll(Database db, List<String> statements) async {
        for (final stmt in statements) {
          final parts = stmt.split(';');
          for (final part in parts) {
            final sql = part.trim();
            if (sql.isEmpty) continue;
            await db.execute('$sql;');
          }
        }
      }

      Future<void> _insertLifts(Database db) async {
        await db.transaction((txn) async {
          for (final lift in liftsSrc.liftDataList) {
            final liftId = lift['liftId'];
            final liftName = lift['liftName'] ?? 'Unnamed Lift';

            final clean = {
              'liftId': liftId,
              'liftName': liftName,
              'repScheme': lift['repScheme'] ?? '',
              'numSets': (lift['numSets'] ?? 3) as int,
              'scoreMultiplier': (lift['scoreMultiplier'] as num?)?.toDouble() ?? 1.0,
              'isDumbbellLift': (lift['isDumbbellLift'] is int)
                  ? lift['isDumbbellLift']
                  : int.tryParse('${lift['isDumbbellLift']}') ?? 0,
              'scoreType': lift['scoreType'] ?? 'multiplier',
              'youtubeUrl': lift['youtubeUrl'] ?? '',
              'description': lift['description'] ?? '',
              'referenceLiftId': lift['referenceLiftId'],
              'percentOfReference': (lift['percentOfReference'] as num?)?.toDouble(),
            };

            await txn.insert(
              'lifts',
              clean,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
      }

      Future<int> _countRows(Database db, String table) async {
        final rows = await db.rawQuery('SELECT COUNT(1) as c FROM $table');
        if (rows.isEmpty) return 0;
        final value = rows.first.values.first;
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value.toString()) ?? 0;
      }
// dart run tool/build_seed_db.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/services/schema_sql.dart'; // factor your CREATE TABLE/INDEX SQL here
import 'catalog_generator.dart';   // your existing generator for catalog rows
import 'stock_templates_generator.dart'; // new: emits blocks/workouts/lift_templates rows

const seedOutRel = 'assets/db/seed_vXX.db';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final outPath = p.normalize(p.join(Directory.current.path, seedOutRel));
  final outFile = File(outPath);
  if (outFile.existsSync()) outFile.deleteSync();

  final db = await databaseFactory.openDatabase(outPath);

  try {
    // 1) Schema
    for (final stmt in schemaCreateStatements) {
      await db.execute(stmt);
    }

    // 2) Reference data: lift_catalog
    final catalogRows = generateLiftCatalog(); // List<Map<String, dynamic>>
    final batch = db.batch();
    for (final r in catalogRows) {
      batch.insert('lift_catalog', r, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    // 3) Stock templates
    final stock = generateStockTemplates(); // emits blocks, workouts, lift_templates lists
    await db.transaction((txn) async {
      for (final b in stock.blocks) {
        await txn.insert('blocks', b, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final wb in stock.workoutsBlocks) {
        await txn.insert('workouts_blocks', wb, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final lt in stock.liftTemplates) {
        await txn.insert('lift_templates', lt, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    // 4) Indexes / PRAGMAs / version
    for (final stmt in schemaIndexStatements) {
      await db.execute(stmt);
    }
    await db.execute('PRAGMA user_version = 28;'); // match CURRENT_DB_VERSION

    // 5) Finalize
    await db.execute('PRAGMA optimize;');
    await db.execute('VACUUM;');
    print('Seed DB written to: $outPath');
  } finally {
    await db.close();
  }
}

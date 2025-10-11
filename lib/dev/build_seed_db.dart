// dart run tool/build_seed_db.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lift_league/services/schema_sql.dart'; // factor your CREATE TABLE/INDEX SQL here
import 'catalog_generator.dart';   // your existing generator for catalog rows

String seedRelPath(int v) => 'assets/db/seed_v$v.db';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final outRel = seedRelPath(SCHEMA_USER_VERSION);
  final outPath = p.normalize(p.join(Directory.current.path, outRel));
  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  if (outFile.existsSync()) outFile.deleteSync();

  final db = await databaseFactory.openDatabase(outPath);
  try {
    for (final sql in schemaCreateStatements) {
      await db.execute(sql);
    }
    for (final sql in schemaIndexStatements) {
      await db.execute(sql);
    }

    final rows = generateLiftCatalog(); // must match lift_catalog columns
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('lift_catalog', r, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    await db.execute('PRAGMA user_version = $SCHEMA_USER_VERSION');
    await db.execute('PRAGMA optimize;');
    await db.execute('VACUUM;');
    stdout.writeln('Seed DB written: $outPath');
  } finally {
    await db.close();
  }
}

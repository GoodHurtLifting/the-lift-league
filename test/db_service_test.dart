import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lift_league/services/db_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('reopens database if handle is closed', () async {
    final service = DBService.instance;

    final db1 = await service.database;
    await db1.rawQuery('SELECT 1');

    await db1.close();

    final db2 = await service.database;
    final result = await db2.rawQuery('SELECT 1');
    expect(result, isNotEmpty);
  });

  test('resetDevDatabase reinitializes and allows queries', () async {
    final service = DBService.instance;

    await service.resetDevDatabase();

    await expectLater(service.getBlockInstanceById(1), completes);
  });
}

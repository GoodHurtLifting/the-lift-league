import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:lift_league/data/lift_data.dart';
import 'package:lift_league/data/workout_data.dart';
import 'package:lift_league/data/block_data.dart';
import 'package:lift_league/data/titles_data.dart';
import 'package:lift_league/services/calculations.dart';
import 'package:lift_league/models/custom_block_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lift_league/services/user_stats_service.dart';
import 'package:lift_league/services/badge_service.dart';

class DBService {
  static final DBService _instance = DBService._internal();

  factory DBService() => _instance;

  DBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ──────────────────────────────────────────────────────────
  // 🔄 DATABASE INIT (v16, cleaned up)
  // ──────────────────────────────────────────────────────────
  static const _dbVersion = 16;   // bump any time the schema changes

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'lift_league.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, v) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        await _createTables(db);
        await _insertDefaultData(db);
      },
      // One-shot upgrade: run only when pre-v16 DB is opened
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 16) {
          // add scheduledDate so we can credit make-up workouts
          await db.execute(
            "ALTER TABLE workout_instances ADD COLUMN scheduledDate TEXT;"
          );
          // helpful indexes
          await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_wi_user_block "
            "ON workout_instances (userId, blockInstanceId);"
          );
          await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_wi_sched "
            "ON workout_instances (scheduledDate);"
          );
        }
      },
    );
  }

  // ──────────────────────────────────────────────
  // 🚀 DATABASE TABLE CREATION
  // ──────────────────────────────────────────────
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE lifts (
        liftId INTEGER PRIMARY KEY,
        liftName TEXT,
        repScheme TEXT,
        numSets INTEGER,
        scoreMultiplier REAL,
        isDumbbellLift INTEGER,
        scoreType TEXT,
        youtubeUrl TEXT,
        description TEXT,
        referenceLiftId INTEGER,
        percentOfReference REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE blocks (
        blockId INTEGER PRIMARY KEY AUTOINCREMENT,
        blockName TEXT,
        scheduleType TEXT,
        numWorkouts INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE block_instances (
        blockInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
        blockId INTEGER,
        userId Text,
        blockName TEXT, -- (optional, for UI)
        startDate TEXT,
        endDate TEXT,
        status TEXT,
        FOREIGN KEY (blockId) REFERENCES blocks(blockId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        workoutId INTEGER PRIMARY KEY,
        workoutName TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts_blocks (
        workoutBlockId INTEGER PRIMARY KEY AUTOINCREMENT,
        blockId INTEGER,
        workoutId INTEGER,
        FOREIGN KEY (blockId) REFERENCES block_instances(blockId) ON DELETE CASCADE,
        FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_instances (
        workoutInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
        blockInstanceId   INTEGER,
        userId            TEXT,
        workoutId         INTEGER,
        workoutName       TEXT,
        blockName         TEXT,
        week              INTEGER,
        scheduledDate     TEXT,    -- NEW v16
        startTime         TEXT,
        endTime           TEXT,
        completed         INTEGER DEFAULT 0,
        FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId) ON DELETE CASCADE,
        FOREIGN KEY (workoutId)      REFERENCES workouts(workoutId)      ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE lift_workouts (
        liftWorkoutId INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER,
        liftId INTEGER,
        numSets INTEGER DEFAULT 3,
        FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE,
        FOREIGN KEY (liftId) REFERENCES lifts(liftId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE lift_entries (
        liftInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutInstanceId INTEGER,
        liftId INTEGER,
        setIndex INTEGER,
        reps INTEGER,
        weight REAL,
        userId TEXT,
        FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lift_totals (
        liftTotalId INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        workoutInstanceId INTEGER,
        liftId INTEGER,
        liftReps INTEGER DEFAULT 0,
        liftWorkload REAL DEFAULT 0.0,
        liftScore REAL DEFAULT 0.0,
        UNIQUE(userId, workoutInstanceId, liftId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_totals (
        workoutInstanceId INTEGER PRIMARY KEY,
        userId TEXT,
        blockInstanceId INTEGER,
        workoutWorkload REAL DEFAULT 0.0,
        workoutScore REAL DEFAULT 0.0,
        FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId),
        FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS block_totals (
        blockInstanceId INTEGER PRIMARY KEY,
        userId TEXT,
        blockId INTEGER,         -- 🔥 needed for leaderboard grouping
        blockName TEXT,          -- 🏷️ display name for leaderboard
        blockWorkload REAL DEFAULT 0.0,
        blockScore REAL DEFAULT 0.0,
        FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId)
      );
      
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        numWeeks INTEGER,
        daysPerWeek INTEGER,
        isDraft INTEGER DEFAULT 0,
        coverImagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        blockId INTEGER,
        dayIndex INTEGER,
        name TEXT,
        FOREIGN KEY (blockId) REFERENCES custom_blocks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lift_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER,
        name TEXT,
        sets INTEGER,
        repsPerSet INTEGER,
        multiplier REAL,
        isBodyweight INTEGER,
        FOREIGN KEY (workoutId) REFERENCES workout_drafts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_weight_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        value REAL,
        bmi REAL,
        bodyFat REAL,
        source TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_energy_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        kcalIn REAL,
        kcalOut REAL,
        source TEXT
      )
    ''');
  }

  // ──────────────────────────────────────────────
  // 🔄 INSERT DEFAULT DATA
  // ──────────────────────────────────────────────
  Future<void> _insertDefaultData(Database db) async {
    await _insertLifts(db);
    await _insertWorkouts(db);
    await _insertBlocks(db);
  }

  Future<void> _insertLifts(Database db) async {
    await db.transaction((txn) async {
      for (var lift in liftDataList) {
        try {
          final liftId = lift['liftId'];
          final liftName = lift['liftName'] ?? 'Unnamed Lift';
          print("👉 Inserting liftId $liftId: $liftName");

          final cleanLift = {
            'liftId': liftId,
            'liftName': liftName,
            'repScheme': lift['repScheme'] ?? '',
            'numSets': (lift['numSets'] ?? 3) as int,
            'scoreMultiplier': (lift['scoreMultiplier'] ?? 1.0).toDouble(),
            'isDumbbellLift': (lift['isDumbbellLift'] ?? 0) is int
                ? lift['isDumbbellLift']
                : int.tryParse('${lift['isDumbbellLift']}') ?? 0,
            'scoreType': lift['scoreType'] ?? 'multiplier',
            'youtubeUrl': lift['youtubeUrl'] ?? '',
            'description': lift['description'] ?? '',
            'referenceLiftId': lift['referenceLiftId'],
            'percentOfReference':
                (lift['percentOfReference'] as num?)?.toDouble(),
          };

          await txn.insert(
            'lifts',
            cleanLift,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } catch (e) {
          print(
              "❌ ERROR inserting liftId ${lift['liftId']} (${lift['liftName']}): $e");
        }
      }
    });
    print("✅ All Default Lifts Inserted Inside Transaction");
  }

  Future<Map<String, dynamic>?> getLiftById(int liftId) async {
    final db = await database;

    List<Map<String, dynamic>> result = await db.query(
      'lifts',
      where: 'liftId = ?',
      whereArgs: [liftId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      print("❌ Lift not found: Lift ID $liftId");
      return null;
    }
  }

  Future<void> resetDevDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lift_league.db');

    // Close the current connection (required before deleting)
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Delete the database file
    await deleteDatabase(path);

    // Reinitialize (will now trigger onCreate and create all tables)
    await _initDatabase();
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH ALL BLOCKS FROM BLOCKS TABLE
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllBlocks() async {
    final db = await database;
    return await db.query('blocks');
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH ALL BLOCK INSTANCES
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllBlockInstances(String userId) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT DISTINCT blockInstanceId, blockName
    FROM block_instances
    WHERE userId = ?
    ORDER BY blockInstanceId ASC
  ''', [userId]);
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH LIFT ENTRIES FOR A WORKOUT INSTANCE
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLiftEntries(
      int workoutInstanceId, int liftId) async {
    final db = await database;

    List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT * FROM lift_entries
    WHERE workoutInstanceId = ? AND liftId = ?
    ORDER BY setIndex ASC
  ''', [workoutInstanceId, liftId]);

    print(
        "🔍 Lift Entries for workoutInstanceId $workoutInstanceId, liftId $liftId: ${results.length}");

    return results;
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH ALL LIFTS FOR A WORKOUT INSTANCE
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWorkoutLifts(
      int workoutInstanceId) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT DISTINCT le.liftId, l.liftName, l.repScheme, l.numSets, l.scoreMultiplier, 
             l.isDumbbellLift, l.scoreType, l.youtubeUrl, l.description
      FROM lift_entries le
      JOIN lifts l ON le.liftId = l.liftId
      WHERE le.workoutInstanceId = ?
    ''', [workoutInstanceId]);
  }

// ✅ Fetch lift scores from the DB
  Future<Map<String, dynamic>?> fetchStoredLiftTotals({
    required int workoutInstanceId,
    required int liftId,
  }) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final result = await db.query(
      'lift_totals',
      where: 'workoutInstanceId = ? AND liftId = ? AND userId = ?',
      whereArgs: [workoutInstanceId, liftId, userId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH A SPECIFIC WORKOUT INSTANCE BY ID
// ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getWorkoutInstanceById(
      int workoutInstanceId) async {
    final db = await database;

    List<Map<String, dynamic>> result = await db.query(
      'workout_instances',
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      print(
          "❌ Workout instance not found: WorkoutInstanceId $workoutInstanceId");
      return null;
    }
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH A SPECIFIC BLOCK INSTANCE BY ID
// ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> getBlockInstanceById(
      int blockInstanceId) async {
    final db = await database;

    List<Map<String, dynamic>> result = await db.query(
      'block_instances',
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      print("❌ Block instance not found: BlockInstanceId $blockInstanceId");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBlockInstancesByBlockName(
      String blockName, String userId) async {
    final db = await database;
    return await db.query(
      'block_instances',
      where: 'blockName = ? AND userId = ?',
      whereArgs: [blockName, userId],
      orderBy: 'blockInstanceId ASC',
    );
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH ALL WORKOUT INSTANCES FOR A BLOCK
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWorkoutInstancesByBlock(
      int blockInstanceId) async {
    final db = await database;

    List<Map<String, dynamic>> workouts = await db.query(
      'workout_instances',
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      orderBy: 'workoutInstanceId ASC', // 👈 key line
    );

    if (workouts.isEmpty) {
      print(
          "❌ No workout instances found for blockInstanceId: $blockInstanceId");
    } else {
      print(
          "✅ Found ${workouts.length} workouts for blockInstanceId: $blockInstanceId");

      for (var workout in workouts) {
        print("🔍 DB Workout Name: '${workout['workoutName']}'");
      }
    }

    return workouts;
  }

  // ──────────────────────────────────────────────
// 🔍 FETCH PREVIOUS LIFT ENTRY FOR COMPARISON
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPreviousLiftEntry(
      int workoutInstanceId, int liftId) async {
    final db = await database;

    // Step 1: Get the most recent previous workoutInstanceId for this lift
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final result = await db.rawQuery('''
    SELECT MAX(workoutInstanceId) as previousWorkoutInstanceId
    FROM lift_entries
    WHERE liftId = ? AND workoutInstanceId < ? AND userId = ?
  ''', [liftId, workoutInstanceId, userId]);

    final previousWorkoutInstanceId = result.first['previousWorkoutInstanceId'];

    if (previousWorkoutInstanceId == null) return [];

    // Step 2: Get the lift entries from that workout instance
    return await db.rawQuery('''
    SELECT * FROM lift_entries
    WHERE liftId = ? AND workoutInstanceId = ?
    ORDER BY setIndex ASC
  ''', [liftId, previousWorkoutInstanceId]);
  }

  Future<double> getPreviousLiftScore(
      int currentWorkoutInstanceId, int liftId) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Step 1: Get the most recent previous workoutInstanceId for this lift from lift_entries.
    final result = await db.rawQuery('''
    SELECT MAX(workoutInstanceId) as previousWorkoutInstanceId
    FROM lift_entries
    WHERE liftId = ? AND workoutInstanceId < ? AND userId = ?
  ''', [liftId, currentWorkoutInstanceId, userId]);

    final previousWorkoutInstanceId = result.first['previousWorkoutInstanceId'];
    if (previousWorkoutInstanceId == null) return 0.0;

    // Step 2: Retrieve the liftScore from the lift_totals table for that previous workout instance.
    final scoreResult = await db.rawQuery('''
    SELECT liftScore FROM lift_totals
    WHERE liftId = ? AND workoutInstanceId = ? AND userId = ?
  ''', [liftId, previousWorkoutInstanceId, userId]);

    if (scoreResult.isEmpty) return 0.0;

    final liftScore = scoreResult.first['liftScore'];
    return (liftScore as num).toDouble();
  }

  Future<double> getPreviousWorkoutScore(
      int currentWorkoutInstanceId, int workoutId, String userId) async {
    final db = await database;

    // Step 1: Get the most recent previous workoutInstanceId for the same workoutId
    final result = await db.rawQuery('''
    SELECT MAX(wt.workoutInstanceId) as previousWorkoutInstanceId
    FROM workout_totals wt
    JOIN workout_instances wi ON wt.workoutInstanceId = wi.workoutInstanceId
    WHERE wt.workoutInstanceId < ? AND wi.workoutId = ? AND wt.userId = ?
  ''', [currentWorkoutInstanceId, workoutId, userId]);

    final previousWorkoutInstanceId = result.first['previousWorkoutInstanceId'];
    if (previousWorkoutInstanceId == null) return 0.0;

    // Step 2: Get the workoutScore from that specific instance
    final scoreResult = await db.rawQuery('''
    SELECT workoutScore FROM workout_totals
    WHERE workoutInstanceId = ? AND userId = ?
  ''', [previousWorkoutInstanceId, userId]);

    if (scoreResult.isEmpty) return 0.0;

    return (scoreResult.first['workoutScore'] as num).toDouble();
  }

  Future<double?> getAverageWeightForLift(int liftId) async {
    final db = await database;

    // Get the most recent workoutInstanceId for this lift
    final result = await db.rawQuery('''
    SELECT workoutInstanceId
    FROM lift_entries
    WHERE liftId = ? AND weight > 0
    ORDER BY workoutInstanceId DESC
    LIMIT 1
  ''', [liftId]);

    if (result.isEmpty) return null;

    final workoutInstanceId = result.first['workoutInstanceId'];

    // Now get the average weight across all entries for that liftId in the latest instance
    final avgResult = await db.rawQuery('''
    SELECT AVG(weight) as avgWeight
    FROM lift_entries
    WHERE liftId = ? AND workoutInstanceId = ?
  ''', [liftId, workoutInstanceId]);

    return (avgResult.first['avgWeight'] as num?)?.toDouble();
  }

  Future<void> _insertWorkouts(Database db) async {
    for (var workout in workoutDataList) {
      await db.insert(
          'workouts',
          {
            'workoutId': workout['workoutId'],
            'workoutName': workout['workoutName'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);

      // ✅ Insert lifts into `lift_workouts` (separately)
      if (workout.containsKey('liftIds') && workout['liftIds'] is List) {
        for (int liftId in workout['liftIds']) {
          await db.insert(
              'lift_workouts',
              {
                'workoutId': workout['workoutId'],
                'liftId': liftId,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
    print("✅ Default Workouts and Lift Assignments Inserted");
  }

  Future<void> _insertBlocks(Database db) async {
    for (var block in blockDataList) {
      await db.insert(
          'blocks',
          {
            'blockId': block['blockId'],
            'blockName': block['blockName'],
            'scheduleType': block['scheduleType'],
            'numWorkouts': block['numWorkouts'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);

      // ✅ Insert into workouts_blocks junction table
      List<int> workoutIds = List<int>.from(block['workoutsIds']);
      for (int workoutId in workoutIds) {
        await db.insert(
            'workouts_blocks',
            {
              'blockId': block['blockId'],
              'workoutId': workoutId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    print("✅ Default Blocks and Workout Assignments Inserted");
  }

  // ──────────────────────────────────────────────
// 🔢 UNIQUE ID GENERATORS
// ──────────────────────────────────────────────

  int generateBlockInstanceId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }

  int generateWorkoutInstanceId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }

  // ──────────────────────────────────────────────
  // 📝 CUSTOM BLOCK HELPERS
  // ──────────────────────────────────────────────
  Future<int> insertCustomBlock(CustomBlock block) async {
    final db = await database;
    await db.insert(
      'custom_blocks',
      {
        'id': block.id,
        'name': block.name,
        'numWeeks': block.numWeeks,
        'daysPerWeek': block.daysPerWeek,
        'isDraft': block.isDraft ? 1 : 0,
        'coverImagePath': block.coverImagePath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (final workout in block.workouts) {
      await insertWorkoutDraft(workout, block.id);
    }
    return block.id;
  }

  Future<void> insertWorkoutDraft(WorkoutDraft w, int blockId) async {
    final db = await database;
    final workoutId = await db.insert('workout_drafts', {
      'blockId': blockId,
      'dayIndex': w.dayIndex,
      'name': w.name,
    });
    for (final lift in w.lifts) {
      await db.insert('lift_drafts', {
        'workoutId': workoutId,
        'name': lift.name,
        'sets': lift.sets,
        'repsPerSet': lift.repsPerSet,
        'multiplier': lift.multiplier,
        'isBodyweight': lift.isBodyweight ? 1 : 0,
      });
    }
  }

  int? _findLiftIdByName(String name) {
    final match = liftDataList.firstWhere(
      (l) => (l['liftName'] as String).toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );
    return match.isNotEmpty ? match['liftId'] as int : null;
  }

  Future<List<Map<String, dynamic>>> getCustomBlocks(
      {bool includeDrafts = false}) async {
    final db = await database;
    if (includeDrafts) {
      return db.query('custom_blocks');
    }
    return db.query('custom_blocks', where: 'isDraft = 0');
  }

  Future<void> deleteCustomBlock(int id) async {
    final db = await database;
    await db.delete('custom_blocks', where: 'id = ?', whereArgs: [id]);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docId = id.toString();
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.collection('custom_blocks').doc(docId).delete();
      await userDoc.collection('customBlockRefs').doc(docId).delete();

      final globalDoc =
          FirebaseFirestore.instance.collection('custom_blocks').doc(docId);
      final snap = await globalDoc.get();
      if (snap.exists && snap.data()?['ownerId'] == user.uid) {
        await globalDoc.delete();
      }
    }
  }

  Future<CustomBlock?> getCustomBlock(int id) async {
    final db = await database;
    final blockData = await db.query(
      'custom_blocks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (blockData.isEmpty) return null;
    final blockRow = blockData.first;
    final workoutRows = await db.query(
      'workout_drafts',
      where: 'blockId = ?',
      whereArgs: [id],
      orderBy: 'dayIndex ASC',
    );
    final List<WorkoutDraft> workouts = [];
    for (final w in workoutRows) {
      final lifts = await db.query(
        'lift_drafts',
        where: 'workoutId = ?',
        whereArgs: [w['id']],
      );
      workouts.add(
        WorkoutDraft(
          id: w['id'] as int,
          dayIndex: w['dayIndex'] as int,
          name: w['name'] as String? ?? '',
          lifts: lifts
              .map((l) => LiftDraft(
                    name: l['name'] as String,
                    sets: l['sets'] as int,
                    repsPerSet: l['repsPerSet'] as int,
                    multiplier: (l['multiplier'] as num).toDouble(),
                    isBodyweight: (l['isBodyweight'] as int) == 1,
                  ))
              .toList(),
        ),
      );
    }

    return CustomBlock(
      id: blockRow['id'] as int,
      name: blockRow['name'] as String,
      numWeeks: blockRow['numWeeks'] as int,
      daysPerWeek: blockRow['daysPerWeek'] as int,
      coverImagePath: blockRow['coverImagePath'] as String?,
      workouts: workouts,
      isDraft: (blockRow['isDraft'] as int) == 1,
      scheduleType: 'standard',
    );
  }

  Future<void> updateCustomBlock(CustomBlock block) async {
    final db = await database;
    await db.update(
      'custom_blocks',
      {
        'name': block.name,
        'numWeeks': block.numWeeks,
        'daysPerWeek': block.daysPerWeek,
        'isDraft': block.isDraft ? 1 : 0,
        'coverImagePath': block.coverImagePath,
      },
      where: 'id = ?',
      whereArgs: [block.id],
    );
    await db
        .delete('workout_drafts', where: 'blockId = ?', whereArgs: [block.id]);
    for (final w in block.workouts) {
      await insertWorkoutDraft(w, block.id);
    }
  }

  Future<void> syncCustomBlocksFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('custom_blocks')
        .get();
    for (final doc in snap.docs) {
      final id = int.tryParse(doc.id) ?? 0;
      final db = await database;
      final existing =
      await db.query('custom_blocks', where: 'id = ?', whereArgs: [id]);
      if (existing.isNotEmpty) continue;
      final data = doc.data();
      data['id'] = id;
      await insertCustomBlock(CustomBlock.fromMap(data));
    }
  }

  Future<int> createBlockFromCustomBlockId(int customId, String userId) async {
    final customBlock = await getCustomBlock(customId);
    if (customBlock == null) {
      throw Exception('Custom block not found: $customId');
    }

    final db = await database;

    final int blockId = await db.insert('blocks', {
      'blockName': customBlock.name,
      'scheduleType': 'standard',
      'numWorkouts': customBlock.workouts.length,
    });

    for (final workout in customBlock.workouts) {
      final int workoutId = await db.insert('workouts', {
        'workoutName': workout.name,
      });

      await db.insert('workouts_blocks', {
        'blockId': blockId,
        'workoutId': workoutId,
      });

      for (final lift in workout.lifts) {
        final liftId = _findLiftIdByName(lift.name);
        if (liftId != null) {
          await db.insert('lift_workouts', {
            'workoutId': workoutId,
            'liftId': liftId,
          });
        } else {
          print('❌ Unknown lift name: ${lift.name}');
        }
      }
    }

    final int blockInstanceId = await db.insert('block_instances', {
      'blockId': blockId,
      'blockName': customBlock.name,
      'userId': userId,
      'startDate': null,
      'endDate': null,
      'status': 'inactive',
    });

    await insertWorkoutInstancesForBlock(blockInstanceId);

    return blockInstanceId;
  }

// ──────────────────────────────────────────────
// 🔄 CREATE NEW BLOCK INSTANCE & INSERT WORKOUTS
// ──────────────────────────────────────────────
  /// Creates a new block instance for the given [blockName]. If the block does
  /// not exist in the standard `blocks` table, this will look for a matching
  /// entry in `custom_blocks` and automatically convert it to a standard block
  /// (along with its workouts and lifts) before creating the instance.
  Future<int> insertNewBlockInstance(String blockName, String userId) async {
    final db = await database;

// ✅ Fetch blockId from the `blocks` table. If not found, attempt to convert
    // a custom block with the same name into a standard one.
    var blockData = await db.query(
      'blocks',
      where: 'blockName = ?',
      whereArgs: [blockName],
      limit: 1,
    );

    int blockId;

    if (blockData.isEmpty) {
      final cleanName = blockName.replaceAll(' (draft)', '');
      final custom = await db.query('custom_blocks',
          where: 'name = ?', whereArgs: [cleanName], limit: 1);
      if (custom.isEmpty) {
        throw Exception('❌ Block not found: $blockName');
      }
      return await createBlockFromCustomBlockId(
          custom.first['id'] as int, userId);
    } else {
      blockId = blockData.first['blockId'] as int;
    }

    // ✅ Insert new block instance with userId
    int newBlockInstanceId = await db.insert('block_instances', {
      'blockId': blockId,
      'blockName': blockName,
      'userId': userId,
      'startDate': null,
      'endDate': null,
      'status': "inactive",
    });

    return newBlockInstanceId;
  }

  Future<void> activateBlockInstanceIfNeeded(
      int blockInstanceId, String userId, String blockName) async {
    final db = await database;

    // Check if block is already active
    final result = await db.query(
      'block_instances',
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (result.isEmpty) return;

    final status = result.first['status'] as String?;
    if (status == 'active') return;

    // Activate block locally
    await db.update(
      'block_instances',
      {
        'status': 'active',
        'startDate': DateTime.now().toIso8601String(),
      },
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
    );

    // Update Firestore with activeBlockName
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'activeBlockName': blockName,
    });
  }

// ──────────────────────────────────────────────
// 🔄 INSERT WORKOUT INSTANCES FOR A BLOCK INSTANCE
// ──────────────────────────────────────────────
  Future<void> insertWorkoutInstancesForBlock(int blockInstanceId) async {
    final db = await database;

    // ✅ Fetch blockId from block_instances
    final blockData = await db.query(
      'block_instances',
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (blockData.isEmpty) {
      print("❌ Block instance not found: $blockInstanceId");
      return;
    }

    final int blockId = blockData.first['blockId'] as int;
    final String userId = blockData.first['userId']?.toString() ?? '';

    // ✅ Fetch workouts linked to this block
    final workouts = await db.rawQuery('''
    SELECT wb.workoutId, w.workoutName 
    FROM workouts_blocks wb
    JOIN workouts w ON wb.workoutId = w.workoutId
    WHERE wb.blockId = ?
  ''', [blockId]);

    if (workouts.isEmpty) {
      print("❌ No workouts found for Block ID: $blockId");
      return;
    }

    print("✅ Workouts found for Block ID $blockId: ${workouts.length}");

    // ✅ Get schedule type
    final String scheduleType = await getScheduleType(blockId);

    int workoutsPerWeek;
    switch (scheduleType) {
      case 'ab_alternate':
      case 'texas_method':
      case 'ppl_plus':
        workoutsPerWeek = 3;
        break;
      case 'standard':
      default:
        workoutsPerWeek = (workouts.length == 4) ? 4 : 3;
        break;
    }

    // ✅ Generate full distribution of workouts for the block
    final List<Map<String, dynamic>> distribution =
        await generateWorkoutDistribution(workouts, scheduleType);

    if (distribution.isEmpty) {
      print("❌ Distribution failed. No workouts to insert.");
      return;
    }

    // ✅ Insert workout instances (keep clean name)
    for (int i = 0; i < distribution.length; i++) {
      final workout = distribution[i];
      final int week = (i / workoutsPerWeek).floor() + 1;

      final int newWorkoutInstanceId = await db.insert(
        'workout_instances',
        {
          'blockInstanceId': blockInstanceId,
          'userId': userId,
          'workoutId': workout['workoutId'],
          'workoutName': workout['workoutName'],
          'blockName': blockData.first['blockName'], // make sure this exists
          'week': week,
          'startTime': null,
          'endTime': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      print(
          "✅ Inserted ${workout['workoutName']} (Week $week, Instance ID: $newWorkoutInstanceId)");

      await insertLiftsForWorkoutInstance(newWorkoutInstanceId);
    }

    print(
        "✅ All workout instances inserted for blockInstanceId $blockInstanceId");
  }

  Future<void> deleteBlockInstance(int blockInstanceId) async {
    final db = await database;
    await db.transaction((txn) async {
      final workoutIds = await txn.query(
        'workout_instances',
        columns: ['workoutInstanceId'],
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
      );

      for (final row in workoutIds) {
        final id = row['workoutInstanceId'] as int;
        await txn.delete('lift_totals',
            where: 'workoutInstanceId = ?', whereArgs: [id]);
        await txn.delete('workout_totals',
            where: 'workoutInstanceId = ?', whereArgs: [id]);
      }

      await txn.delete('workout_totals',
          where: 'blockInstanceId = ?', whereArgs: [blockInstanceId]);
      await txn.delete('block_totals',
          where: 'blockInstanceId = ?', whereArgs: [blockInstanceId]);
      await txn.delete('workout_instances',
          where: 'blockInstanceId = ?', whereArgs: [blockInstanceId]);
      await txn.delete('block_instances',
          where: 'blockInstanceId = ?', whereArgs: [blockInstanceId]);
    });
  }

// ──────────────────────────────────────────────
// 🔄 GET SCHEDULE TYPE FROM `blocks` TABLE
// ──────────────────────────────────────────────
  Future<String> getScheduleType(int blockId) async {
    final db = await database;
    final result = await db.query(
      'blocks',
      where: 'blockId = ?',
      whereArgs: [blockId],
      limit: 1,
    );
    return result.isNotEmpty
        ? result.first['scheduleType'] as String
        : 'standard';
  }

// ──────────────────────────────────────────────
// 🔄 GENERATE WORKOUT DISTRIBUTION BASED ON SCHEDULE TYPE
// ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> generateWorkoutDistribution(
      List<Map<String, dynamic>> workouts, String scheduleType) async {
    final int numWorkouts = workouts.length;
    List<int> pattern = [];

    switch (scheduleType) {
      case 'ab_alternate':
        pattern = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
        break;

      case 'ppl_plus':
        for (int i = 0; i < 7; i++) {
          pattern.addAll([0, 1, 2]); // 21 total slots
        }
        break;

      case 'texas_method':
        for (int i = 0; i < 2; i++) {
          pattern
              .addAll(List.generate(6, (j) => j)); // 6 workouts × 2 = 12 slots
        }
        break;

      default: // Standard
        if (numWorkouts == 2) {
          pattern = List.generate(12, (i) => i % 2);
        } else if (numWorkouts == 3) {
          pattern = List.generate(12, (i) => i % 3);
        } else if (numWorkouts == 4) {
          pattern = List.generate(16, (i) => i % 4);
        } else if (numWorkouts == 5) {
          pattern = List.generate(20, (i) => i % 5);
        } else {
          pattern = List.generate(12, (i) => i % numWorkouts);
        }
        break;
    }

    List<Map<String, dynamic>> orderedWorkouts = [];
    for (int i = 0; i < pattern.length; i++) {
      orderedWorkouts.add(workouts[pattern[i]]);
    }
    print("🧪 Distribution pattern: ${pattern.length} items");
    print("✅ Generated distribution with ${orderedWorkouts.length} workouts.");
    return orderedWorkouts;
  }

  Future<void> setWorkoutStartTime(int workoutInstanceId) async {
    final db = await database;
    await db.update(
      'workout_instances',
      {'startTime': DateTime.now().toIso8601String()},
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
    );
  }

  Future<void> setWorkoutEndTime(int workoutInstanceId) async {
    final db = await database;
    await db.update(
      'workout_instances',
      {'endTime': DateTime.now().toIso8601String()},
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
    );
  }

  Future<void> saveLiftEntry({
    required int workoutInstanceId,
    required int liftId,
    required int setIndex,
    required int reps,
    required double weight,
  }) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      print("No valid userId available. Skipping saveLiftEntry.");
      return;
    }

    // ✅ Check if the entry already exists, including userId in the WHERE clause
    List<Map<String, dynamic>> existingEntry = await db.query(
      'lift_entries',
      where:
          'workoutInstanceId = ? AND liftId = ? AND setIndex = ? AND userId = ?',
      whereArgs: [workoutInstanceId, liftId, setIndex, userId],
    );

    if (existingEntry.isNotEmpty) {
      // ✅ Update existing entry and include userId to be safe
      await db.update(
        'lift_entries',
        {
          'reps': reps,
          'weight': weight,
          'userId': userId,
        },
        where:
            'workoutInstanceId = ? AND liftId = ? AND setIndex = ? AND userId = ?',
        whereArgs: [workoutInstanceId, liftId, setIndex, userId],
      );
      print(
        "🔄 Updated Set: Lift $liftId - Set $setIndex - Reps: $reps - Weight: $weight",
      );
    } else {
      // ✅ Insert new entry if not found, including userId in the data
      await db.insert(
        'lift_entries',
        {
          'workoutInstanceId': workoutInstanceId,
          'liftId': liftId,
          'setIndex': setIndex,
          'reps': reps,
          'weight': weight,
          'userId': userId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        "✅ Inserted Set: Lift $liftId - Set $setIndex - Reps: $reps - Weight: $weight",
      );
    }

    // ✅ Update lift totals in the database
    await updateLiftTotals(workoutInstanceId, liftId);
  }

  Future<void> upsertLiftTotals({
    required int workoutInstanceId,
    required int liftId,
    required int liftReps,
    required double liftWorkload,
    required double liftScore,
  }) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      print("No valid userId available. Skipping upsert for lift_totals.");
      return;
    }

    await db.insert(
      'lift_totals',
      {
        'userId': userId,
        'workoutInstanceId': workoutInstanceId,
        'liftId': liftId,
        'liftReps': liftReps,
        'liftWorkload': liftWorkload,
        'liftScore': liftScore,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print(
        "✅ Upserted lift_totals for Lift $liftId in Workout $workoutInstanceId");
  }

  Future<void> updateLiftTotals(int workoutInstanceId, int liftId) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      print("No valid userId available. Skipping updateLiftTotals.");
      return;
    }

    // Fetch lift info
    final liftData = await db.query(
      'lifts',
      where: 'liftId = ?',
      whereArgs: [liftId],
      limit: 1,
    );

    if (liftData.isEmpty) {
      throw Exception("❌ Lift not found: Lift ID $liftId");
    }

    final lift = liftData.first;
    final scoreMultiplier =
        (lift['scoreMultiplier'] as num?)?.toDouble() ?? 1.0;
    final isDumbbellLift = (lift['isDumbbellLift'] as int?) == 1;
    final scoreType = lift['scoreType']?.toString() ?? 'multiplier';

    // Fetch lift entries
    final entries = await db.query(
      'lift_entries',
      where: 'workoutInstanceId = ? AND liftId = ? AND userId = ?',
      whereArgs: [workoutInstanceId, liftId],
    );

    // Calculate totals correctly
    final liftReps = getLiftRepsFromDb(entries, isDumbbellLift: isDumbbellLift);
    final liftWorkload =
        getLiftWorkloadFromDb(entries, isDumbbellLift: isDumbbellLift);
    final liftScore = calculateLiftScoreFromEntries(
      entries,
      scoreMultiplier,
      isDumbbellLift: isDumbbellLift,
      scoreType: scoreType,
    );

    // Update DB
    await db.update(
      'lift_totals',
      {
        'liftReps': liftReps,
        'liftWorkload': liftWorkload,
        'liftScore': liftScore,
      },
      where: 'workoutInstanceId = ? AND liftId = ? AND userId = ?',
      whereArgs: [workoutInstanceId, liftId, userId],
    );

    print(
        "✅ Updated Lift Totals — Lift ID: $liftId | Reps: $liftReps | Workload: $liftWorkload | Score: $liftScore");
  }

  Future<void> insertLiftsForWorkoutInstance(int workoutInstanceId) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception("No valid userId available");
    }

    // ✅ Fetch the associated workoutId
    List<Map<String, dynamic>> workoutInstanceData = await db.query(
      'workout_instances',
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );

    if (workoutInstanceData.isEmpty) {
      throw Exception("❌ Workout instance not found: $workoutInstanceId");
    }

    int workoutId = workoutInstanceData.first['workoutId'];

    // ✅ Fetch lifts associated with this workout
    List<Map<String, dynamic>> lifts = await db.rawQuery('''
    SELECT lw.liftId, l.numSets FROM lift_workouts lw
    JOIN lifts l ON lw.liftId = l.liftId
    WHERE lw.workoutId = ?
  ''', [workoutId]);

    if (lifts.isEmpty) {
      throw Exception("❌ No lifts found for Workout ID: $workoutId");
    }

    for (var lift in lifts) {
      final int liftId = lift['liftId'];
      final int numSets = lift['numSets'];

      // 🔄 Insert lift_entries for each set
      for (int setIndex = 1; setIndex <= numSets; setIndex++) {
        await db.insert('lift_entries', {
          'workoutInstanceId': workoutInstanceId,
          'liftId': liftId,
          'setIndex': setIndex,
          'reps': 0,
          'weight': 0.0,
          'userId': userId,
        });
      }

      // ✅ Insert baseline lift_totals entry (one per liftId per workoutInstance)
      await db.insert(
        'lift_totals',
        {
          'userId': userId, // Include the userId here
          'workoutInstanceId': workoutInstanceId,
          'liftId': liftId,
          'liftReps': 0,
          'liftWorkload': 0.0,
          'liftScore': 0.0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    print(
        "✅ Lifts and Lift Totals inserted for Workout Instance: $workoutInstanceId");
  }

  Future<void> writeLiftTotalsDirectly({
    required int workoutInstanceId,
    required int liftId,
    required int liftReps,
    required double liftWorkload,
    required double liftScore,
    bool syncToCloud = true,
  }) async {
    final db = await database;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      print("No valid userId available. Skipping writeLiftTotalsDirectly.");
      return;
    }

    await db.insert(
      'lift_totals',
      {
        'userId': userId,
        'workoutInstanceId': workoutInstanceId,
        'liftId': liftId,
        'liftReps': liftReps,
        'liftWorkload': liftWorkload,
        'liftScore': liftScore,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Overwrites if entry already exists
    );

    print(
        "✅ Updated lift_totals: Lift $liftId | Workout $workoutInstanceId | Reps: $liftReps | Workload: $liftWorkload | Score: $liftScore");
  }

  Future<void> upsertWorkoutTotals({
    required int workoutInstanceId,
    required String userId,
    required int blockInstanceId,
    required double workoutWorkload,
    required double workoutScore,
  }) async {
    final db = await database;
    await db.insert(
      'workout_totals',
      {
        'workoutInstanceId': workoutInstanceId,
        'userId': userId,
        'blockInstanceId': blockInstanceId,
        'workoutWorkload': workoutWorkload,
        'workoutScore': workoutScore,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWorkoutTotals({
    required int workoutInstanceId,
    required String userId,
    required double workoutWorkload,
    required double workoutScore,
  }) async {
    final dbInstance = await database;
    // Attempt to update first.
    final result = await dbInstance.update(
      'workout_totals',
      {
        'workoutWorkload': workoutWorkload,
        'workoutScore': workoutScore,
        'userId': userId,
      },
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
    );
    // If no rows were updated, insert new totals.
    if (result == 0) {
      await dbInstance.insert(
        'workout_totals',
        {
          'workoutInstanceId': workoutInstanceId,
          'workoutWorkload': workoutWorkload,
          'workoutScore': workoutScore,
          'userId': userId,
        },
      );
    }
  }

  Future<void> writeWorkoutTotalsDirectly({
    required int workoutInstanceId,
    required String userId,
    bool syncToCloud = true,
  }) async {
    final db = await database;

    // 🧠 Step 1: Get the workoutId + blockInstanceId from workout_instances
    final workoutInstance = await db.rawQuery('''
    SELECT workoutId, blockInstanceId 
    FROM workout_instances 
    WHERE workoutInstanceId = ?
  ''', [workoutInstanceId]);

    if (workoutInstance.isEmpty) {
      print("❌ No workoutInstance found for ID $workoutInstanceId");
      return;
    }

    final workoutId = workoutInstance.first['workoutId'] as int;
    final blockInstanceId = workoutInstance.first['blockInstanceId'] as int;

    // 🧠 Step 2: Get liftIds from workoutData
    final workoutDef = workoutDataList.firstWhere(
      (w) => w['workoutId'] == workoutId,
      orElse: () => {},
    );

    final List<int> liftIds = List<int>.from(workoutDef['liftIds'] ?? []);

    if (liftIds.isEmpty) {
      print("⚠️ No lifts defined for workoutId $workoutId");
      return;
    }

    double totalScore = 0.0;
    double totalWorkload = 0.0;

    for (final liftId in liftIds) {
      final liftTotal = await db.rawQuery('''
      SELECT liftScore, liftWorkload
      FROM lift_totals
      WHERE workoutInstanceId = ? AND liftId = ? AND userId = ?
    ''', [workoutInstanceId, liftId, userId]);

      if (liftTotal.isNotEmpty) {
        totalScore += (liftTotal.first['liftScore'] as num?)?.toDouble() ?? 0.0;
        totalWorkload +=
            (liftTotal.first['liftWorkload'] as num?)?.toDouble() ?? 0.0;
      } else {
        totalScore += 0.0;
      }
    }

    final averageScore =
        liftIds.isNotEmpty ? (totalScore / liftIds.length) : 0.0;

    // 🧠 Step 3: Write to workout_totals
    await upsertWorkoutTotals(
      workoutInstanceId: workoutInstanceId,
      userId: userId,
      blockInstanceId: blockInstanceId,
      workoutWorkload: totalWorkload,
      workoutScore: averageScore,
    );

    print(
        "✅ Updated workout_totals: Workout $workoutInstanceId | Workload: $totalWorkload | Score: $averageScore");

    // 🧠 Step 4: Update block_totals
    await recalculateBlockTotals(blockInstanceId);
    // 🧠 Step 5: Firestore sync removed — use syncWorkoutTotalsToFirestore instead
    if (syncToCloud) {
      await syncWorkoutTotalsToFirestore(userId);
    }
  }

  Future<void> syncWorkoutTotalsToFirestore(String userId) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT SUM(workoutWorkload) AS totalLbs
    FROM workout_totals
    WHERE userId = ?
  ''', [userId]);

    final totalLbs = (result.first['totalLbs'] as num?)?.toDouble() ?? 0.0;

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'totalLbsLifted': totalLbs,
    });

    print("✅ Firestore totalLbsLifted updated: $totalLbs lbs");
  }

  Future<Map<String, dynamic>?> getWorkoutTotals(
      int workoutInstanceId, String userId) async {
    final db = await database;
    final result = await db.query(
      'workout_totals',
      where: 'workoutInstanceId = ? AND userId = ?',
      whereArgs: [workoutInstanceId, userId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateWorkoutInstanceCompletion(int workoutInstanceId) async {
    final db = await database;
    await db.update(
      'workout_instances',
      {
        'completed': 1,
        'endTime':
            DateTime.now().toIso8601String(), // optional: remove if unused
      },
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
    );
  }

  /// Marks the workout complete, updates training days, finishes block if needed,
  /// and returns true if this call also completed the block.
  Future<bool> completeWorkoutAndCheckBlock({
    required int workoutInstanceId,
    required int blockInstanceId,
    required String userId,
  }) async {
    // Step 1: Mark workout instance complete
    await updateWorkoutInstanceCompletion(workoutInstanceId);

    // Step 1.5: Update unique training day
    await updateTrainingDaysAndWorkoutsCompleted(userId, workoutInstanceId);

    // Step 2: Check remaining workouts in block
    final remaining = await getRemainingUnfinishedWorkouts(blockInstanceId);

    if (remaining == 0) {
      // Step 3: Mark block completed
      await updateBlockInstanceEndDate(blockInstanceId, userId);

      // Step 4: Recalculate total blocks completed
      final userStatsService = UserStatsService();
      final totalBlocks =
          await userStatsService.getTotalCompletedBlocks(userId);

      // Step 5: Update Firestore with new count + title
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final workoutsLogged = userDoc.data()?['workoutsCompleted'] ?? 0;
      final newTitle = getUserTitle(
          blocksCompleted: totalBlocks, workoutsLogged: workoutsLogged);
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'blocksCompleted': totalBlocks,
        'title': newTitle,
      });

      return true;
    }

    return false;
  }

  Future<List<Map<String, dynamic>>> checkForEarnedBadges({
    required String userId,
  }) async {
    final badgeService = BadgeService();
    final meatWagon = await badgeService.checkAndAwardMeatWagonBadge(userId);
    final punchCard = await badgeService.checkAndAwardPunchCardBadge(userId);
    final hypeMan = await badgeService.checkAndAwardHypeManBadge(userId);
    final dailyDriver =
        await badgeService.checkAndAwardDailyDriverBadge(userId);

    // If you want to include Lift PR-based badges here too (optional)
    final liftPRs = ['Bench Press', 'Squats', 'Deadlift'];
    final List<Map<String, dynamic>> lunchLadyBadges = [];

    for (final lift in liftPRs) {
      final liftDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('big3_prs')
          .doc(lift)
          .get();

      final bestWeight = liftDoc.data()?['bestWeight'] ?? 0.0;
      if (bestWeight > 0) {
        final earned = await badgeService.checkAndAwardLunchLadyBadge(
          userId: userId,
          liftName: lift,
          weight: bestWeight.toDouble(),
        );
        lunchLadyBadges.addAll(earned);
      }
    }

    return [
      ...meatWagon,
      ...lunchLadyBadges,
      ...punchCard,
      ...hypeMan,
      ...dailyDriver
    ];
  }

  Future<int> getRemainingUnfinishedWorkouts(int blockInstanceId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COUNT(*) as remaining
    FROM workout_instances
    WHERE blockInstanceId = ? AND completed != 1
  ''', [blockInstanceId]);

    return result.first['remaining'] != null
        ? result.first['remaining'] as int
        : 0;
  }

  Future<void> incrementBlocksCompleted(String userId) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

    await userDoc.update({
      'blocksCompleted': FieldValue.increment(1),
    });
  }

  Future<void> updateBlockInstanceEndDate(
      int blockInstanceId, String userId) async {
    final db = await database;
    await db.update(
      'block_instances',
      {
        'endDate': DateTime.now().toIso8601String(),
      },
      where: 'blockInstanceId = ? AND userId = ?',
      whereArgs: [blockInstanceId, userId],
    );
  }

  Future<void> updateTrainingDaysAndWorkoutsCompleted(
      String userId, int workoutInstanceId) async {
    final db = await database;

    // Check if this is the first time this workoutInstance is marked completed
    final result = await db.rawQuery('''
    SELECT endTime FROM workout_instances
    WHERE workoutInstanceId = ?
  ''', [workoutInstanceId]);

    if (result.isEmpty || result.first['endTime'] == null) return;

    final date = result.first['endTime'].toString().split('T').first;

    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final userDoc = await userRef.get();

    final existingDays =
        List<String>.from(userDoc.data()?['loggedTrainingDays'] ?? []);

    // Track training day if it's new
    if (!existingDays.contains(date)) {
      existingDays.add(date);
      await userRef.update({
        'loggedTrainingDays': existingDays,
        'trainingDays': existingDays.length,
      });
    }

    // Always increment workoutsCompleted
    await userRef.update({
      'workoutsCompleted': FieldValue.increment(1),
    });

// Fetch updated counts
    final updatedDoc = await userRef.get();
    final blocksCompleted = updatedDoc.data()?['blocksCompleted'] ?? 0;
    final workoutsLogged = updatedDoc.data()?['workoutsCompleted'] ?? 0;

// Update title if needed
    final newTitle = getUserTitle(
      blocksCompleted: blocksCompleted,
      workoutsLogged: workoutsLogged,
    );
    await userRef.update({'title': newTitle});
  }

  Future<void> recalculateBlockTotals(int blockInstanceId) async {
    final db = await database;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print("No valid user. Skipping recalculateBlockTotals.");
      return;
    }
    final userId = currentUser.uid;

    // 🧠 Fetch blockId + blockName from block_instances
    final blockData = await db.query(
      'block_instances',
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );

    if (blockData.isEmpty) {
      print("❌ Block instance not found for blockInstanceId: $blockInstanceId");
      return;
    }

    final blockId = blockData.first['blockId'] as int;
    final blockName =
        blockData.first['blockName']?.toString() ?? 'Unknown Block';

    // 🧠 Collect workouts and reduce redundancy
    final workouts = await getWorkoutInstancesByBlock(blockInstanceId);
    final Map<String, double> bestScores = {};
    final Map<String, double> bestWorkloads = {};

    double totalBlockWorkload = 0.0;

    for (final w in workouts) {
      final workoutInstanceId = w['workoutInstanceId'];
      final workoutName = w['workoutName'];

      // 🧼 Skip Recovery days
      final upperName = workoutName.toString().toUpperCase();
      if (upperName.contains("RECOVERY")) continue;

      final totals = await getWorkoutTotals(workoutInstanceId, userId);
      final score = (totals?['workoutScore'] as num?)?.toDouble() ?? 0.0;
      final workload = (totals?['workoutWorkload'] as num?)?.toDouble() ?? 0.0;

      totalBlockWorkload += workload;

      if (!bestScores.containsKey(workoutName) ||
          score > bestScores[workoutName]!) {
        bestScores[workoutName] = score;
        bestWorkloads[workoutName] = workload;
      }
    }

    final totalBlockScore = bestScores.values.fold(0.0, (a, b) => a + b);

    await upsertBlockTotals(
      blockInstanceId: blockInstanceId,
      userId: userId,
      blockScore: totalBlockScore,
      blockWorkload: totalBlockWorkload,
      blockId: blockId,
      blockName: blockName,
    );

    // 🔁 Sync to Firestore
    final Map<String, dynamic> bestScoresMap = {};
    bestScores.forEach((key, value) {
      final safeKey = key.replaceAll(' ', '_').toLowerCase();
      bestScoresMap[safeKey] = value;
    });

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'blockScores': {
        '$blockInstanceId': {
          'totalScore': totalBlockScore,
          'bestScores': bestScoresMap,
        }
      }
    }, SetOptions(merge: true));

    print(
        "✅ Recalculated block totals: Block $blockInstanceId | Score: $totalBlockScore | Workload: $totalBlockWorkload");
  }

  Future<int> getBlockIdFromInstance(int blockInstanceId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT blockId FROM block_instances WHERE blockInstanceId = ?
  ''', [blockInstanceId]);

    return result.first['blockId'] as int;
  }

  Future<int> getBlockInstanceIdForWorkout(int workoutInstanceId) async {
    final db = await database;
    final result = await db.query(
      'workout_instances',
      columns: ['blockInstanceId'],
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );
    return result.first['blockInstanceId'] as int;
  }

  /// Returns the block instance ID marked as `active` for the given [userId].
  ///
  /// If no active block exists, `null` is returned.
  Future<String?> getActiveBlockInstanceId(String userId) async {
    final db = await database;
    final result = await db.query(
      'block_instances',
      columns: ['blockInstanceId'],
      where: 'userId = ? AND status = ?',
      whereArgs: [userId, 'active'],
      limit: 1,
    );

    if (result.isNotEmpty && result.first['blockInstanceId'] != null) {
      return result.first['blockInstanceId'].toString();
    }
    return null;
  }

  Future<void> upsertBlockTotals({
    required int blockInstanceId,
    required String userId,
    required double blockScore,
    required double blockWorkload,
    required int blockId,
    required String blockName,
  }) async {
    final db = await database;
    await db.insert(
      'block_totals',
      {
        'blockInstanceId': blockInstanceId,
        'userId': userId,
        'blockScore': blockScore,
        'blockId': blockId,
        'blockName': blockName,
        'blockWorkload': blockWorkload,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBlockTotals({
    required int blockInstanceId,
    required String userId,
    required double blockWorkload,
    required double blockScore,
    required int blockId,
    required String blockName,
  }) async {
    final db = await database;
    await db.insert(
      'block_totals',
      {
        'blockInstanceId': blockInstanceId,
        'userId': userId,
        'blockId': blockId,
        'blockName': blockName,
        'blockWorkload': blockWorkload,
        'blockScore': blockScore,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> writeBlockTotalsDirectly({
    required int blockInstanceId,
    required String userId,
    required double blockWorkload,
    required double blockScore,
    required int blockId,
    required String blockName,
  }) async {
    await upsertBlockTotals(
      blockInstanceId: blockInstanceId,
      userId: userId,
      blockWorkload: blockWorkload,
      blockScore: blockScore,
      blockId: blockId,
      blockName: blockName,
    );

    print(
        "✅ Updated block_totals: BlockInstance $blockInstanceId | $blockName | Workload: $blockWorkload | Score: $blockScore");
  }

  Future<Map<String, dynamic>?> getBlockTotals(
      int blockInstanceId, String userId) async {
    final db = await database;
    final result = await db.query(
      'block_totals',
      where: 'blockInstanceId = ? AND userId = ?',
      whereArgs: [blockInstanceId, userId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getLeaderboardDataForBlock(
      int blockId) async {
    final db = await database;

    // Step 1: Query all block_totals for this blockId
    final result = await db.rawQuery('''
    SELECT * FROM block_totals
    WHERE blockId = ?
  ''', [blockId]);

    // Step 2: Group by userId, select their best blockInstance (highest score)
    final Map<String, Map<String, dynamic>> bestPerUser = {};

    for (final row in result) {
      final userId = row['userId'] as String;
      final score = double.tryParse(row['blockScore'].toString()) ?? 0.0;

      if (!bestPerUser.containsKey(userId) ||
          score > (bestPerUser[userId]!['blockScore'] ?? 0.0)) {
        bestPerUser[userId] = {
          'blockInstanceId': row['blockInstanceId'],
          'blockScore': score,
        };
      }
    }

    // Step 3: Build list of userIds to fetch from Firestore
    final List<String> userIds = bestPerUser.keys.toList();
    if (userIds.isEmpty) {
      return [];
    }

    // Step 4: Batch fetch all user profiles at once
    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();

    final Map<String, Map<String, dynamic>> userProfiles = {
      for (var doc in userDocs.docs) doc.id: doc.data()
    };

    List<Map<String, dynamic>> finalData = [];

    // Step 5: Build final leaderboard entries
    for (final entry in bestPerUser.entries) {
      final userId = entry.key;
      final blockInstanceId = entry.value['blockInstanceId'];
      final blockScore = entry.value['blockScore'];

      // Fetch individual best workout scores
      final workoutScoresRaw = await db.rawQuery('''
      SELECT workoutScore FROM workout_totals
      WHERE blockInstanceId = ?
    ''', [blockInstanceId]);

      final workoutScores = workoutScoresRaw
          .map((e) =>
              double.tryParse(e['workoutScore'].toString())
                  ?.toStringAsFixed(1) ??
              '0.0')
          .toList();

      final userData = userProfiles[userId] ?? {};

      finalData.add({
        'userId': userId,
        'displayName': userData['displayName'] ?? 'Anonymous',
        'profileImageUrl': userData['profileImageUrl'] ?? '',
        'title': userData['title'] ?? '',
        'blockInstanceId': blockInstanceId,
        'blockScore': blockScore.toStringAsFixed(1),
        'workoutScores': workoutScores,
      });

      print('✅ Leaderboard user loaded: $userId | Score: $blockScore');
    }

    // Step 6: Sort by blockScore descending
    finalData.sort((a, b) =>
        double.parse(b['blockScore']).compareTo(double.parse(a['blockScore'])));

    return finalData;
  }

  Future<Map<String, dynamic>?> getCurrentWorkoutInfo(String userId) async {
    final db = await DBService().database;

    final result = await db.rawQuery('''
    SELECT blockName, workoutName, week
    FROM workout_instances
    WHERE userId = ? AND completed = 1
    ORDER BY startTime DESC
    LIMIT 1
  ''', [userId]);

    if (result.isEmpty) return null;

    final data = result.first;
    return {
      'blockName': data['blockName'] ?? '',
      'workoutName': data['workoutName'] ?? '',
      'week': data['week'] ?? 1,
    };
  }

  Future<Map<String, dynamic>?> getLastFinishedWorkoutInfo(
      String userId) async {
    final db = await database;
    final result = await db.rawQuery(r'''
    SELECT blockName, workoutName, week
      FROM workout_instances
     WHERE userId = ? AND completed = 1
  ORDER BY endTime DESC
     LIMIT 1
  ''', [userId]);

    if (result.isEmpty) return null;
    final data = result.first;
    return {
      'blockName': data['blockName'] as String? ?? '',
      'workoutName': data['workoutName'] as String? ?? '',
      'week': data['week'] as int? ?? 1,
    };
  }

  Future<Map<String, dynamic>?> getNextWorkoutInfo(String userId) async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT blockName, workoutName, week
      FROM workout_instances
     WHERE userId = ? AND completed = 0
  ORDER BY startTime ASC
     LIMIT 1
  ''', [userId]);

    if (result.isEmpty) return null;
    final data = result.first;
    return {
      'blockName': data['blockName'] as String? ?? '',
      'workoutName': data['workoutName'] as String? ?? '',
      'week': data['week'] as int? ?? 1,
    };
  }

  Future<void> postAutoClinkAfterWorkout(String userId,
      {List<String>? badgeImagePaths}) async {
    final info = await getLastFinishedWorkoutInfo(userId);
    if (info == null) return;

    final block = info['blockName'];
    final workout = info['workoutName'];
    final week = info['week'];

    final message = 'Just finished: W$week $workout, $block';

    final entry = {
      'userId': userId,
      'type': 'clink',
      'clink': message,
      'timestamp': Timestamp.now(),
    };
    if (badgeImagePaths != null && badgeImagePaths.isNotEmpty) {
      entry['imageUrls'] = badgeImagePaths;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('timeline_entries')
        .add(entry);
  }

  Future<void> postPRClink(String userId, String message) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('timeline_entries')
        .add({
      'userId': userId,
      'type': 'clink',
      'clink': message,
      'timestamp': Timestamp.now(),
    });
  }
// ──────────────────────────────────────────────────────────────
  // 📈 Momentum Metrics
  // ──────────────────────────────────────────────────────────────

  Future<int> getCurrentWeekNumber(int blockInstanceId) async {
    final db = await database;
    final result = await db.query('block_instances',
        columns: ['startDate'],
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
        limit: 1);
    if (result.isEmpty || result.first['startDate'] == null) return 1;
    final start = DateTime.parse(result.first['startDate'] as String);
    final diff = DateTime.now().difference(start).inDays;
    return diff ~/ 7 + 1;
  }

  Future<Map<String, double>> _getWeekStats(
      String userId, int blockInstanceId, int week) async {
    final db = await database;

    final totalRaw = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM workout_instances
      WHERE blockInstanceId = ? AND week = ?
    ''', [blockInstanceId, week]);
    final total = totalRaw.first['total'] as int? ?? 0;

    final completedRaw = await db.rawQuery('''
      SELECT COUNT(*) as completed
      FROM workout_instances
      WHERE blockInstanceId = ? AND week = ? AND completed = 1
    ''', [blockInstanceId, week]);
    final completed = completedRaw.first['completed'] as int? ?? 0;

    final consistency = total > 0 ? (completed / total) * 100 : 0.0;

    final currentScoreRaw = await db.rawQuery('''
      SELECT AVG(workoutScore) as avgScore
      FROM workout_totals
      WHERE blockInstanceId = ? AND workoutInstanceId IN (
        SELECT workoutInstanceId FROM workout_instances
        WHERE blockInstanceId = ? AND week = ? AND completed = 1
      )
    ''', [blockInstanceId, blockInstanceId, week]);
    final currentAvg =
        (currentScoreRaw.first['avgScore'] as num?)?.toDouble() ?? 0.0;

    final prevScoreRaw = await db.rawQuery('''
      SELECT AVG(workoutScore) as avgScore
      FROM workout_totals
      WHERE blockInstanceId = ? AND workoutInstanceId IN (
        SELECT workoutInstanceId FROM workout_instances
        WHERE blockInstanceId = ? AND week < ? AND completed = 1
      )
    ''', [blockInstanceId, blockInstanceId, week]);
    final prevAvg = (prevScoreRaw.first['avgScore'] as num?)?.toDouble() ?? 0.0;

    double efficiency;
    if (prevAvg == 0) {
      efficiency = currentAvg > 0 ? 100.0 : 0.0;
    } else {
      efficiency = (currentAvg / prevAvg) * 100;
    }

    return {
      'consistency': double.parse(consistency.toStringAsFixed(1)),
      'efficiency': double.parse(efficiency.toStringAsFixed(1))
    };
  }

  Future<double> getWeeklyMomentum(
      String userId, int blockInstanceId, int week) async {
    final stats = await _getWeekStats(userId, blockInstanceId, week);
    return (stats['consistency']! + stats['efficiency']!) / 2.0;
  }

  Future<double> getRunningMomentumAverage(
      String userId, int blockInstanceId, int currentWeek) async {
    double total = 0.0;
    int weeks = 0;
    for (int w = 1; w <= currentWeek; w++) {
      final stats = await _getWeekStats(userId, blockInstanceId, w);
      if (stats['consistency']! == 0 && stats['efficiency']! == 0) continue;
      total += (stats['consistency']! + stats['efficiency']!) / 2.0;
      weeks++;
    }
    return weeks > 0 ? total / weeks : 0.0;
  }

  // -----------------------------------------------------------------
  // Lift Management Helpers
  // -----------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllLifts() async {
    final db = await database;
    return await db.query('lifts');
  }

  Future<void> updateLiftDefinition({
    required int liftId,
    required String liftName,
    required String repScheme,
    required String scoreType,
    required double scoreMultiplier,
    required String youtubeUrl,
    required String description,
  }) async {
    final db = await database;
    await db.update(
      'lifts',
      {
        'liftName': liftName,
        'repScheme': repScheme,
        'scoreType': scoreType,
        'scoreMultiplier': scoreMultiplier,
        'youtubeUrl': youtubeUrl,
        'description': description,
      },
      where: 'liftId = ?',
      whereArgs: [liftId],
    );
  }

  Future<List<Map<String, dynamic>>> getWorkoutsByBlockId(int blockId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT wb.workoutId, w.workoutName
      FROM workouts_blocks wb
      JOIN workouts w ON wb.workoutId = w.workoutId
      WHERE wb.blockId = ?
      ORDER BY w.workoutName ASC
    ''', [blockId]);
  }

  Future<List<Map<String, dynamic>>> getLiftsByWorkoutId(int workoutId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT l.*
      FROM lift_workouts lw
      JOIN lifts l ON lw.liftId = l.liftId
      WHERE lw.workoutId = ?
      ORDER BY l.liftName ASC
    ''', [workoutId]);
  }

  Future<List<Map<String, dynamic>>> getLiftsByBlockAndWorkout() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.blockId, b.blockName, w.workoutId, w.workoutName,
             l.liftId, l.liftName, l.repScheme, l.numSets, l.scoreMultiplier,
             l.isDumbbellLift, l.scoreType, l.youtubeUrl, l.description
      FROM blocks b
      JOIN workouts_blocks wb ON wb.blockId = b.blockId
      JOIN workouts w ON wb.workoutId = w.workoutId
      JOIN lift_workouts lw ON lw.workoutId = w.workoutId
      JOIN lifts l ON lw.liftId = l.liftId
      ORDER BY b.blockName ASC, w.workoutName ASC, l.liftName ASC
    ''');
  }

  Future<List<int>> getWorkoutInstancesByLift(int liftId) async {
    final db = await database;
    final res = await db.rawQuery(
        'SELECT DISTINCT workoutInstanceId FROM lift_entries WHERE liftId = ?',
        [liftId]);
    return res.map((e) => e['workoutInstanceId'] as int).toList();
  }

  Future<void> insertWeightSample({
    required DateTime date,
    double? value,
    double? bmi,
    double? bodyFat,
    required String source,
  }) async {
    final db = await database;
    await db.insert('health_weight_samples', {
      'date': date.toIso8601String(),
      'value': value,
      'bmi': bmi,
      'bodyFat': bodyFat,
      'source': source,
    });
  }

  Future<Map<String, dynamic>?> getLatestWeightSampleForDay(
    DateTime day, {
    String source = 'manual',
  }) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query(
      'health_weight_samples',
      columns: ['value', 'bmi', 'bodyFat'],
      where: 'date >= ? AND date < ? AND source = ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
        source,
      ],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> insertEnergySample({
    required DateTime date,
    required double kcalIn,
    required double kcalOut,
    required String source,
  }) async {
    final db = await database;
    await db.insert('health_energy_samples', {
      'date': date.toIso8601String(),
      'kcalIn': kcalIn,
      'kcalOut': kcalOut,
      'source': source,
    });
  }

}

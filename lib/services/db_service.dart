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
import 'package:flutter/foundation.dart';
import 'score_multiplier_service.dart';

// Score type constants (use ints everywhere)
const int SCORE_TYPE_MULTIPLIER = 0;
const int SCORE_TYPE_BODYWEIGHT = 1;

class DBService {
  static final DBService _instance = DBService._internal();

  factory DBService() => _instance;

  static DBService get instance => _instance;

  DBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ──────────────────────────────────────────────────────────
  // 🔄 DATABASE INIT (v18, cleaned up)
  // ──────────────────────────────────────────────────────────

  static const _dbVersion = 26;   // bump any time the schema changes


  Future<bool> _hasColumn(DatabaseExecutor db, String table, String col) async {
    final rows = await db.rawQuery('PRAGMA table_info($table);');
    for (final r in rows) {
      final name = (r['name'] as String?)?.toLowerCase();
      if (name == col.toLowerCase()) return true;
    }
    return false;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'lift_league.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, v) async {
        // Ensure FK cascades for the initial connection
        await db.execute('PRAGMA foreign_keys = ON;');
        await _createTables(db);
        await _insertDefaultData(db);
      },
      onOpen: (db) async {
        // Ensure FK cascades are ON for every new connection
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onUpgrade: (db, oldV, newV) async {
        // Always keep FKs on
        await db.execute('PRAGMA foreign_keys = ON;');

        if (oldV < 16) {
          await db.execute("ALTER TABLE workout_instances ADD COLUMN scheduledDate TEXT;");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_wi_user_block ON workout_instances (userId, blockInstanceId);");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_wi_sched ON workout_instances (scheduledDate);");
        }

        if (oldV < 17) {
          await db.execute("ALTER TABLE custom_lifts ADD COLUMN isDumbbellLift INTEGER DEFAULT 0;");
          try { await db.execute("ALTER TABLE lift_workouts ADD COLUMN repsPerSet INTEGER;"); } catch (_) {}
          try { await db.execute("ALTER TABLE lift_workouts ADD COLUMN multiplier REAL;"); } catch (_) {}
          try { await db.execute("ALTER TABLE lift_workouts ADD COLUMN isBodyweight INTEGER;"); } catch (_) {}
          try { await db.execute("ALTER TABLE lift_workouts ADD COLUMN isDumbbellLift INTEGER;"); } catch (_) {}
          try { await db.execute("ALTER TABLE custom_lifts ADD COLUMN isDumbbellLift INTEGER;"); } catch (_) {}
        }

        if (oldV < 18) {
          await db.execute("ALTER TABLE block_instances ADD COLUMN customBlockId INTEGER;");
          // best-effort backfill by name
          final instances = await db.query('block_instances');
          for (final inst in instances) {
            final name = inst['blockName']?.toString();
            if (name == null) continue;
            final custom = await db.query('custom_blocks', where: 'name = ?', whereArgs: [name], limit: 1);
            if (custom.isNotEmpty) {
              await db.update('block_instances', {'customBlockId': custom.first['customBlockId']},
                  where: 'blockInstanceId = ?', whereArgs: [inst['blockInstanceId']]);
            }
          }
        }

        // === MERGED (former 19/20/22) ===
        if (oldV < 19) {
          // Normalize completed and index
          await db.execute("UPDATE workout_instances SET completed = 0 WHERE completed IS NULL;");
          await db.execute("CREATE INDEX IF NOT EXISTS idx_wi_block_completed ON workout_instances (blockInstanceId, completed);");

          // Ensure workouts_blocks exists with correct schema (no rebuild)
          await db.execute('''
          CREATE TABLE IF NOT EXISTS workouts_blocks (
            workoutBlockId INTEGER PRIMARY KEY AUTOINCREMENT,
            blockId INTEGER NOT NULL,
            workoutId INTEGER NOT NULL,
            FOREIGN KEY (blockId) REFERENCES blocks(blockId) ON DELETE CASCADE,
            FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE
          );
        ''');
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_wb_block_workout ON workouts_blocks(blockId, workoutId);');

          // slotIndex on workout_instances
          try {
            final hasSlot = await _hasColumn(db, 'workout_instances', 'slotIndex');
            if (!hasSlot) {
              await db.execute('ALTER TABLE workout_instances ADD COLUMN slotIndex INTEGER;');
            }
          } catch (_) {}

          // lift_instances: position + archived (defensive)
          try {
            if (!await _hasColumn(db, 'lift_instances', 'position')) {
              await db.execute('ALTER TABLE lift_instances ADD COLUMN position INTEGER DEFAULT 0;');
            }
          } catch (_) {}
          try {
            if (!await _hasColumn(db, 'lift_instances', 'archived')) {
              await db.execute('ALTER TABLE lift_instances ADD COLUMN archived INTEGER DEFAULT 0;');
            }
          } catch (_) {}

          // Reordering support: position on built-ins and customs
          try {
            if (!await _hasColumn(db, 'lift_workouts', 'position')) {
              await db.execute('ALTER TABLE lift_workouts ADD COLUMN position INTEGER DEFAULT 0;');
              await db.execute('CREATE INDEX IF NOT EXISTS idx_lw_workout_pos ON lift_workouts(workoutId, position);');
            }
          } catch (_) {}
          try {
            if (!await _hasColumn(db, 'custom_lifts', 'position')) {
              await db.execute('ALTER TABLE custom_lifts ADD COLUMN position INTEGER DEFAULT 0;');
              await db.execute('CREATE INDEX IF NOT EXISTS idx_ld_workout_pos ON custom_lifts(workoutId, position);');
            }
          } catch (_) {}
        }

        if (oldV < 21) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS lift_instances (
            liftInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
            workoutInstanceId INTEGER,
            liftId INTEGER,
            liftName TEXT,
            sets INTEGER,
            repsPerSet INTEGER,
            scoreMultiplier REAL,
            isDumbbellLift INTEGER,
            isBodyweight INTEGER,
            position INTEGER DEFAULT 0,
            archived INTEGER DEFAULT 0,
            FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE,
            FOREIGN KEY (liftId) REFERENCES lifts(liftId)
          )
        ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_li_workout_archived_pos ON lift_instances (workoutInstanceId, archived, position);');
        }

        if (oldV < 22) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_blocks (
            customBlockId INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            uniqueWorkoutCount INTEGER NOT NULL,
            workoutsPerWeek INTEGER NOT NULL,
            totalWeeks INTEGER NOT NULL,
            ownerUid TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isDraft INTEGER NOT NULL DEFAULT 1,
            coverImagePath TEXT,
            scheduleType TEXT NOT NULL DEFAULT 'standard'
          );
          ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_workouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customBlockId INTEGER NOT NULL,
            name TEXT NOT NULL,
            position INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
          );
          ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_lifts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customWorkoutId INTEGER NOT NULL,
            liftCatalogId INTEGER,
            name TEXT NOT NULL,
            repSchemeText TEXT,
            sets INTEGER,
            repsPerSet INTEGER,
            scoreType INTEGER,
            scoreMultiplier REAL,
            isBodyweight INTEGER,
            isDumbbell INTEGER,
            position INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(customWorkoutId) REFERENCES custom_workouts(id) ON DELETE CASCADE
          );
          ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_block_instances (
            blockInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
            customBlockId INTEGER NOT NULL,
            runNumber INTEGER NOT NULL DEFAULT 1,
            startDate INTEGER NULL,
            endDate INTEGER NULL,
            FOREIGN KEY(customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
          );
          ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS custom_workout_instances (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            blockInstanceId INTEGER NOT NULL,
            customWorkoutId INTEGER NOT NULL,
            week INTEGER NOT NULL,
            slot INTEGER NOT NULL,
            position INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(blockInstanceId) REFERENCES custom_block_instances(blockInstanceId) ON DELETE CASCADE,
            FOREIGN KEY(customWorkoutId) REFERENCES custom_workouts(id) ON DELETE CASCADE
          );
          ''');
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_cwi_block_week_slot ON custom_workout_instances(blockInstanceId, week, slot);');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_cw_block_pos ON custom_workouts(customBlockId, position);');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_clifts_cw_pos ON custom_lifts(customWorkoutId, position);');
          } catch (_) {}
        }


        if (oldV < 23) {
          await db.execute('''
          CREATE TABLE IF NOT EXISTS lift_catalog (
            catalogId INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            primaryGroup TEXT NOT NULL,
            secondaryGroups TEXT,
            equipment TEXT,
            isBodyweightCapable INTEGER NOT NULL DEFAULT 0,
            isDumbbellCapable INTEGER NOT NULL DEFAULT 0,
            unilateral INTEGER NOT NULL DEFAULT 0,
            youtubeUrl TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
          ''');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS lift_aliases (
            aliasId INTEGER PRIMARY KEY AUTOINCREMENT,
            catalogId INTEGER NOT NULL,
            alias TEXT NOT NULL,
            FOREIGN KEY(catalogId) REFERENCES lift_catalog(catalogId) ON DELETE CASCADE
          );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_lc_group ON lift_catalog(primaryGroup);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_la_alias ON lift_aliases(alias);');
        }

        if (oldV < 26) {
          if (!await _hasColumn(db, 'custom_blocks', 'coverImagePath')) {
            await db.execute(
                "ALTER TABLE custom_blocks ADD COLUMN coverImagePath TEXT;");
          }
          if (!await _hasColumn(db, 'custom_blocks', 'scheduleType')) {
            await db.execute(
                "ALTER TABLE custom_blocks ADD COLUMN scheduleType TEXT NOT NULL DEFAULT 'standard';");
          }
        }
      },
    );
  }


  // ──────────────────────────────────────────────
  // 🚀 DATABASE TABLE CREATION
  // ──────────────────────────────────────────────
  Future<void> _createTables(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');

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
        customBlockId INTEGER,
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
        blockId INTEGER NOT NULL,
        workoutId INTEGER NOT NULL,
        FOREIGN KEY (blockId) REFERENCES blocks(blockId) ON DELETE CASCADE,
        FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_wb_block_workout ON workouts_blocks(blockId, workoutId);
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
        slotIndex         INTEGER,
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
        repsPerSet INTEGER,
        multiplier REAL,
        isBodyweight INTEGER,
        isDumbbellLift INTEGER,
        position INTEGER DEFAULT 0,
        FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE,
        FOREIGN KEY (liftId) REFERENCES lifts(liftId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lift_instances (
        liftInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutInstanceId INTEGER,
        liftId INTEGER,
        liftName TEXT,
        sets INTEGER,
        repsPerSet INTEGER,
        scoreMultiplier REAL,
        isDumbbellLift INTEGER,
        isBodyweight INTEGER,
        position INTEGER DEFAULT 0,
        archived INTEGER DEFAULT 0,
        FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE,
        FOREIGN KEY (liftId) REFERENCES lifts(liftId)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_li_workout_archived_pos ON lift_instances (workoutInstanceId, archived, position);');

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
  customBlockId INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  uniqueWorkoutCount INTEGER NOT NULL,
  workoutsPerWeek INTEGER NOT NULL,
  totalWeeks INTEGER NOT NULL,
  ownerUid TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  isDraft INTEGER NOT NULL DEFAULT 1,
  coverImagePath TEXT,
  scheduleType TEXT NOT NULL DEFAULT 'standard'
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS custom_workouts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customBlockId INTEGER NOT NULL,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS custom_lifts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customWorkoutId INTEGER NOT NULL,
  liftCatalogId INTEGER,
  name TEXT NOT NULL,
  repSchemeText TEXT,
  sets INTEGER,
  repsPerSet INTEGER,
  scoreType INTEGER,
  scoreMultiplier REAL,
  isBodyweight INTEGER,
  isDumbbell INTEGER,
  position INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(customWorkoutId) REFERENCES custom_workouts(id) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS custom_block_instances (
  blockInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
  customBlockId INTEGER NOT NULL,
  runNumber INTEGER NOT NULL DEFAULT 1,
  startDate INTEGER NULL,
  endDate INTEGER NULL,
  FOREIGN KEY(customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS custom_workout_instances (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  blockInstanceId INTEGER NOT NULL,
  customWorkoutId INTEGER NOT NULL,
  week INTEGER NOT NULL,
  slot INTEGER NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(blockInstanceId) REFERENCES custom_block_instances(blockInstanceId) ON DELETE CASCADE,
  FOREIGN KEY(customWorkoutId) REFERENCES custom_workouts(id) ON DELETE CASCADE
);
''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_cwi_block_week_slot ON custom_workout_instances(blockInstanceId, week, slot);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cw_block_pos ON custom_workouts(customBlockId, position);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clifts_cw_pos ON custom_lifts(customWorkoutId, position);');


    await db.execute('''
CREATE TABLE IF NOT EXISTS lift_catalog (
  catalogId INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  primaryGroup TEXT NOT NULL,
  secondaryGroups TEXT,
  equipment TEXT,
  isBodyweightCapable INTEGER NOT NULL DEFAULT 0,
  isDumbbellCapable INTEGER NOT NULL DEFAULT 0,
  unilateral INTEGER NOT NULL DEFAULT 0,
  youtubeUrl TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
);
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS lift_aliases (
  aliasId INTEGER PRIMARY KEY AUTOINCREMENT,
  catalogId INTEGER NOT NULL,
  alias TEXT NOT NULL,
  FOREIGN KEY(catalogId) REFERENCES lift_catalog(catalogId) ON DELETE CASCADE
);
''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lc_group ON lift_catalog(primaryGroup);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_la_alias ON lift_aliases(alias);');


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
      SELECT lw.liftId,
             l.liftName,
             COALESCE(lw.numSets, l.numSets) AS sets,
             lw.repsPerSet,
             COALESCE(lw.multiplier, l.scoreMultiplier) AS multiplier,
             COALESCE(lw.isDumbbellLift, l.isDumbbellLift) AS isDumbbellLift,
             CASE WHEN lw.isBodyweight = 1 THEN 'bodyweight' ELSE l.scoreType END AS scoreType,
             l.repScheme,
             l.youtubeUrl,
             l.description,
             l.referenceLiftId,
             l.percentOfReference,
             lw.isBodyweight AS isBodyweight
      FROM workout_instances wi
      JOIN lift_workouts lw ON lw.workoutId = wi.workoutId
      JOIN lifts l ON lw.liftId = l.liftId
      WHERE wi.workoutInstanceId = ?
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

  /// Builds workout instances and seeded lifts for a custom block.
  Future<void> buildCustomBlockInstances({
    required int customBlockId,
    required int blockInstanceId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final block = await txn.query(
        'custom_blocks',
        where: 'customBlockId = ?',
        whereArgs: [customBlockId],
        limit: 1,
      );
      if (block.isEmpty) return;
      final uwc = (block.first['uniqueWorkoutCount'] as num).toInt();
      final wpw = (block.first['workoutsPerWeek'] as num).toInt();
      final weeks = (block.first['totalWeeks'] as num).toInt();

      final wkts = await txn.query(
        'custom_workouts',
        where: 'customBlockId = ?',
        whereArgs: [customBlockId],
        orderBy: 'position ASC',
      );
      final week1 = wkts.take(uwc).toList();
      if (week1.isEmpty) return;

      // Clear any existing instances (cascade removes lifts)
      await txn.delete(
        'workout_instances',
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
      );

      final nameCol = await _liftNameColTx(txn);

      for (int w = 1; w <= weeks; w++) {
        for (int s = 1; s <= wpw; s++) {
          final cw = week1[(s - 1) % week1.length];
          final workoutInstanceId = await txn.insert('workout_instances', {
            'blockInstanceId': blockInstanceId,
            // Store the template workout id so later edits can
            // propagate across all corresponding instances.
            'workoutId': cw['id'],
            'workoutName': cw['name'],
            'week': w,
            'slotIndex': s,
            'completed': 0,
          });

          final lifts = await txn.query(
            'custom_lifts',
            where: 'customWorkoutId = ?',
            whereArgs: [cw['id']],
            orderBy: 'position ASC',
          );

          for (final l in lifts) {
            final ins = {
              'workoutInstanceId': workoutInstanceId,
              'liftId': l['liftCatalogId'],
              nameCol: l['name'],
              'sets': l['sets'],
              'repsPerSet': l['repsPerSet'],
              'scoreMultiplier': l['scoreMultiplier'],
              'isBodyweight': l['isBodyweight'],
              'isDumbbellLift': l['isDumbbell'],
              'position': (l['position'] as num?)?.toInt() ?? 0,
              'archived': 0,
            };
            final newLid = await txn.insert('lift_instances', ins);
            final sets = (l['sets'] as num?)?.toInt() ?? 0;
            await _resizeEntriesForLiftInstanceTx(txn, newLid, sets);
          }
        }
      }
    });
  }

  /// Rebuilds workout instances after shape edits.
  Future<void> rebuildCustomBlockInstances({
    required int customBlockId,
    required int blockInstanceId,
  }) =>
      buildCustomBlockInstances(
        customBlockId: customBlockId,
        blockInstanceId: blockInstanceId,
      );

  /// Updates the core shape of a custom block and rebuilds its instances.
  Future<void> updateCustomBlockShape(
      {required int customBlockId,
      required int blockInstanceId,
      required int uniqueWorkoutCount,
      required int workoutsPerWeek,
      required int totalWeeks}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'custom_blocks',
        {
          'uniqueWorkoutCount': uniqueWorkoutCount,
          'workoutsPerWeek': workoutsPerWeek,
          'totalWeeks': totalWeeks,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'customBlockId = ?',
        whereArgs: [customBlockId],
      );

      // Remove existing instances and related data for a clean rebuild.
      await txn.delete(
        'lift_entries',
        where:
            'workoutInstanceId IN (SELECT workoutInstanceId FROM workout_instances WHERE blockInstanceId = ?)',
        whereArgs: [blockInstanceId],
      );
      await txn.delete(
        'lift_totals',
        where:
            'workoutInstanceId IN (SELECT workoutInstanceId FROM workout_instances WHERE blockInstanceId = ?)',
        whereArgs: [blockInstanceId],
      );
      await txn.delete(
        'workout_totals',
        where:
            'workoutInstanceId IN (SELECT workoutInstanceId FROM workout_instances WHERE blockInstanceId = ?)',
        whereArgs: [blockInstanceId],
      );
      await txn.delete('lift_instances',
          where:
              'workoutInstanceId IN (SELECT workoutInstanceId FROM workout_instances WHERE blockInstanceId = ?)',
          whereArgs: [blockInstanceId]);
      await txn.delete('workout_instances',
          where: 'blockInstanceId = ?', whereArgs: [blockInstanceId]);
    });

    await buildCustomBlockInstances(
        customBlockId: customBlockId, blockInstanceId: blockInstanceId);
    await recalculateBlockTotals(blockInstanceId);
  }

  /// Reorders workouts within a custom block and rebuilds instances.
  Future<void> reorderCustomWorkouts({
    required int customBlockId,
    required int blockInstanceId,
    required List<int> orderedIds,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedIds.length; i++) {
        await txn.update('custom_workouts', {'position': i + 1},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });

    await buildCustomBlockInstances(
        customBlockId: customBlockId, blockInstanceId: blockInstanceId);
    await recalculateBlockTotals(blockInstanceId);
  }

  Future<void> ensureCustomLiftInstancesSeeded(int workoutInstanceId) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'lift_instances',
        where: 'workoutInstanceId = ?',
        whereArgs: [workoutInstanceId],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      final meta = await txn.query(
        'workout_instances',
        columns: ['workoutId', 'blockInstanceId', 'slotIndex'],
        where: 'workoutInstanceId = ?',
        whereArgs: [workoutInstanceId],
        limit: 1,
      );
      if (meta.isEmpty) return;
      final row = meta.first;
      final int? workoutId = row['workoutId'] as int?;
      if (workoutId != null) return; // built-in

      final int blockInstanceId = (row['blockInstanceId'] as num).toInt();
      final int? slotIndex = (row['slotIndex'] as num?)?.toInt();
      final nameCol = await _liftNameColTx(txn);

      int? peerId;
      if (slotIndex != null) {
        final peerRows = await txn.rawQuery(
          '''SELECT wi.workoutInstanceId
             FROM workout_instances wi
             WHERE wi.blockInstanceId = ? AND wi.slotIndex = ? AND wi.workoutInstanceId != ?
               AND EXISTS (SELECT 1 FROM lift_instances li WHERE li.workoutInstanceId = wi.workoutInstanceId AND COALESCE(li.archived,0) = 0)
             ORDER BY wi.week ASC, wi.workoutInstanceId ASC
             LIMIT 1''',
          [blockInstanceId, slotIndex, workoutInstanceId],
        );
        if (peerRows.isNotEmpty) {
          peerId = (peerRows.first['workoutInstanceId'] as num).toInt();
        }
      }

      if (peerId != null) {
        final peerLifts = await txn.rawQuery('''
          SELECT liftId, $nameCol AS name, sets, repsPerSet, scoreMultiplier,
                 COALESCE(isDumbbellLift,0) AS isDumbbellLift,
                 COALESCE(isBodyweight,0) AS isBodyweight,
                 COALESCE(position,0) AS position
          FROM lift_instances
          WHERE workoutInstanceId = ? AND COALESCE(archived,0) = 0
          ORDER BY COALESCE(position,0) ASC, liftInstanceId ASC
        ''', [peerId]);
        for (final pl in peerLifts) {
          final ins = {
            'workoutInstanceId': workoutInstanceId,
            'liftId': pl['liftId'],
            nameCol: pl['name'],
            'sets': pl['sets'],
            'repsPerSet': pl['repsPerSet'],
            'scoreMultiplier': pl['scoreMultiplier'],
            'isDumbbellLift': pl['isDumbbellLift'],
            'isBodyweight': pl['isBodyweight'],
            'position': pl['position'],
            'archived': 0,
          };
          final newLid = await txn.insert('lift_instances', ins);
          final sets = (pl['sets'] as num?)?.toInt() ?? 0;
          await _resizeEntriesForLiftInstanceTx(txn, newLid, sets);
        }
        return;
      }

      if (slotIndex != null) {
        final customRow = await txn.rawQuery(
          'SELECT customBlockId FROM block_instances WHERE blockInstanceId = ? LIMIT 1',
          [blockInstanceId],
        );
        final int? customBlockId =
            customRow.isNotEmpty ? customRow.first['customBlockId'] as int? : null;
        if (customBlockId != null) {
          final draftWorkout = await txn.rawQuery(
            'SELECT id FROM custom_workouts WHERE blockId = ? ORDER BY COALESCE(dayIndex,0) ASC, id ASC LIMIT 1 OFFSET ?',
            [customBlockId, slotIndex],
          );
          if (draftWorkout.isNotEmpty) {
            final dwid = (draftWorkout.first['id'] as num).toInt();
            final drafts = await txn.rawQuery('''
              SELECT name, COALESCE(sets,0) AS sets, COALESCE(repsPerSet,0) AS repsPerSet,
                     COALESCE(multiplier,0.0) AS scoreMultiplier,
                     COALESCE(isDumbbellLift,0) AS isDumbbellLift,
                     COALESCE(isBodyweight,0) AS isBodyweight
              FROM custom_lifts
              WHERE workoutId = ?
              ORDER BY position ASC, id ASC
            ''', [dwid]);
            int pos = 0;
            for (final d in drafts) {
              final String name = ((d['name'] as String?) ?? '').trim();
              if (name.isEmpty) continue;

              int liftId;
              final found = await txn.rawQuery(
                'SELECT liftId FROM lifts WHERE LOWER(liftName) = LOWER(?) LIMIT 1',
                [name],
              );
              if (found.isNotEmpty) {
                liftId = (found.first['liftId'] as num).toInt();
              } else {
                liftId = await txn.insert('lifts', {
                  'liftName': name,
                  'repScheme': '${d['sets']}x${d['repsPerSet']}',
                  'numSets': d['sets'],
                  'scoreMultiplier': (d['scoreMultiplier'] as num?)?.toDouble(),
                  'isDumbbellLift': d['isDumbbellLift'],
                  'scoreType': 'standard',
                  'youtubeUrl': null,
                  'description': null,
                  'referenceLiftId': null,
                  'percentOfReference': null,
                }, conflictAlgorithm: ConflictAlgorithm.ignore);
                if (liftId == 0) {
                  final r = await txn.rawQuery(
                    'SELECT liftId FROM lifts WHERE LOWER(liftName) = LOWER(?) LIMIT 1',
                    [name],
                  );
                  if (r.isNotEmpty) {
                    liftId = (r.first['liftId'] as num).toInt();
                  }
                }
              }

              final ins = {
                'workoutInstanceId': workoutInstanceId,
                'liftId': liftId,
                nameCol: name,
                'sets': d['sets'],
                'repsPerSet': d['repsPerSet'],
                'scoreMultiplier': d['scoreMultiplier'],
                'isDumbbellLift': d['isDumbbellLift'],
                'isBodyweight': d['isBodyweight'],
                'position': pos++,
                'archived': 0,
              };
              final newLid = await txn.insert('lift_instances', ins);
              final sets = (d['sets'] as num?)?.toInt() ?? 0;
              await _resizeEntriesForLiftInstanceTx(txn, newLid, sets);
            }
          }
        }
      }
    });
  }

  // ──────────────────────────────────────────────
  // 🔍 CUSTOM INSTANCE CHECK
  // ──────────────────────────────────────────────
  Future<bool> _isCustomInstance(int workoutInstanceId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT bi.customBlockId
      FROM workout_instances wi
      JOIN block_instances bi ON bi.blockInstanceId = wi.blockInstanceId
      WHERE wi.workoutInstanceId = ?
      LIMIT 1
    ''', [workoutInstanceId]);
    if (rows.isEmpty) return false;
    return (rows.first['customBlockId'] as int?) != null;
  }

  // ──────────────────────────────────────────────
  // 🔍 FETCH LIFTS FOR A WORKOUT INSTANCE
  // ──────────────────────────────────────────────
  Future<List<Map<String, Object?>>> getLiftsForWorkoutInstance(
    int workoutInstanceId,
  ) async {
    if (!await _isCustomInstance(workoutInstanceId)) {
      return _getLockedLiftsForInstance(workoutInstanceId);
    }
    return _getCustomLiftsForInstance(workoutInstanceId);
  }

  Future<List<Map<String, Object?>>> _getLockedLiftsForInstance(
      int workoutInstanceId) async {
    final db = await database;
    final meta = await db.query(
      'workout_instances',
      columns: ['workoutId'],
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );
    if (meta.isEmpty) return [];
    final int? workoutId = meta.first['workoutId'] as int?;
    if (workoutId == null) return [];
    return await db.rawQuery('''
      SELECT
        0 AS liftInstanceId,
        lw.liftId,
        l.liftName AS name,
        COALESCE(lw.numSets,3)      AS sets,
        COALESCE(lw.repsPerSet,0)   AS repsPerSet,
        COALESCE(lw.multiplier,0.0) AS scoreMultiplier,
        COALESCE(lw.isDumbbellLift,0) AS isDumbbellLift,
        COALESCE(lw.isBodyweight,0)   AS isBodyweight,
        COALESCE(lw.position, lw.liftWorkoutId) AS position,
        l.scoreType           AS scoreType,
        l.youtubeUrl          AS youtubeUrl,
        l.description         AS description,
        l.referenceLiftId     AS referenceLiftId,
        l.percentOfReference  AS percentOfReference
      FROM lift_workouts lw
      JOIN lifts l ON l.liftId = lw.liftId
      WHERE lw.workoutId = ?
      ORDER BY COALESCE(lw.position, lw.liftWorkoutId) ASC, lw.liftWorkoutId ASC
    ''', [workoutId]);
  }

  Future<List<Map<String, Object?>>> _getCustomLiftsForInstance(
      int workoutInstanceId) async {
    final db = await database;
    await ensureCustomLiftInstancesSeeded(workoutInstanceId);
    final liftNameCol = await _liftNameColTx(db);
    return await db.rawQuery('''
      SELECT
        li.liftInstanceId,
        li.liftId,
        li.$liftNameCol AS name,
        li.sets,
        li.repsPerSet,
        li.scoreMultiplier,
        COALESCE(li.isDumbbellLift,0) AS isDumbbellLift,
        COALESCE(li.isBodyweight,0)   AS isBodyweight,
        COALESCE(li.position,0)       AS position,
        l.scoreType           AS scoreType,
        l.youtubeUrl          AS youtubeUrl,
        l.description         AS description,
        l.referenceLiftId     AS referenceLiftId,
        l.percentOfReference  AS percentOfReference
      FROM lift_instances li
      LEFT JOIN lifts l ON l.liftId = li.liftId
      WHERE li.workoutInstanceId = ? AND COALESCE(li.archived,0) = 0
      ORDER BY COALESCE(li.position,0) ASC, li.liftInstanceId ASC
    ''', [workoutInstanceId]);
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
          final liftRow = await db.query('lifts',
              where: 'liftId = ?', whereArgs: [liftId], limit: 1);
          final int numSets =
              liftRow.isNotEmpty ? liftRow.first['numSets'] as int : 3;
          final double? multiplier = liftRow.isNotEmpty
              ? (liftRow.first['scoreMultiplier'] as num?)?.toDouble()
              : null;
          final int? isDumbbell =
              liftRow.isNotEmpty ? liftRow.first['isDumbbellLift'] as int? : null;

          await db.insert(
              'lift_workouts',
              {
                'workoutId': workout['workoutId'],
                'liftId': liftId,
                'numSets': numSets,
                if (multiplier != null) 'multiplier': multiplier,
                if (isDumbbell != null) 'isDumbbellLift': isDumbbell,
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
  Future<int> upsertCustomBlock(CustomBlock block) async {
    final db = await database;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO custom_blocks (
        customBlockId,
        name,
        totalWeeks,
        workoutsPerWeek,
        uniqueWorkoutCount,
        ownerUid,
        isDraft,
        coverImagePath,
        scheduleType,
        createdAt,
        updatedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''' ,
      [
        block.id,
        block.name,
        block.numWeeks,
        block.daysPerWeek,
        block.workouts.length,
        uid,
        block.isDraft ? 1 : 0,
        block.coverImagePath,
        block.scheduleType,
        now,
        now,
      ],
    );

    await db.transaction((txn) async {
      await txn.delete(
        'custom_lifts',
        where:
            'customWorkoutId IN (SELECT id FROM custom_workouts WHERE customBlockId = ?)',
        whereArgs: [block.id],
      );
      await txn.delete(
        'custom_workouts',
        where: 'customBlockId = ?',
        whereArgs: [block.id],
      );

      final expanded = List<WorkoutDraft>.from(block.workouts)
        ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

      int i = 0;
      for (final w in expanded) {
        final wid = await txn.insert(
          'custom_workouts',
          {
            'id': w.id,
            'customBlockId': block.id,
            'position': i,
            'name': w.name,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (var j = 0; j < w.lifts.length; j++) {
          final l = w.lifts[j];
          await txn.insert('custom_lifts', {
            'customWorkoutId': wid,
            'name': l.name,
            'sets': l.sets,
            'repsPerSet': l.repsPerSet,
            'scoreMultiplier': l.multiplier,
            'scoreType':
                l.isBodyweight ? SCORE_TYPE_BODYWEIGHT : SCORE_TYPE_MULTIPLIER,
            'isBodyweight': l.isBodyweight ? 1 : 0,
            'isDumbbell': l.isDumbbellLift ? 1 : 0,
            'position': l.position,
          });
        }
        i++;
      }
    });

    return block.id;
  }

  // DEPRECATED: instance-only migration
  Future<int> insertCustomBlock(CustomBlock block) async {
    debugPrint('DEPRECATED: insertCustomBlock called');
    return upsertCustomBlock(block);
  }

  // DEPRECATED: instance-only migration
  Future<void> updateCustomBlock(CustomBlock block) async {
    debugPrint('DEPRECATED: updateCustomBlock called');
    await upsertCustomBlock(block);
  }

  // ──────────────────────────────────────────────
// TXN-aware reconciler (works with Database or Transaction)
// ──────────────────────────────────────────────
  Future<void> _reconcileWorkoutInstanceLiftsTx(
      dynamic db, // Database or Transaction
      int workoutInstanceId,
      List<LiftDraft> newLifts,
      ) async {
    // Load existing instance lifts (per-instance table)
    final existing = await db.query(
      'workout_lifts',
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      orderBy: 'liftId ASC',
    );

    String k(String s) => s.toLowerCase().trim();

    // Build case-insensitive name index
    final byName = <String, Map<String, Object?>>{
      for (final r in existing) k((r['liftName'] as String?) ?? ''): r,
    };
    final matched = <String>{};

    for (int idx = 0; idx < newLifts.length; idx++) {
      final l = newLifts[idx];
      final key = k(l.name);
      final row = byName[key];

      if (row != null) {
        final liftId = (row['liftId'] as num).toInt();
        await db.update(
          'workout_lifts',
          {
            'liftName': l.name,
            'sets': l.sets,
            'repsPerSet': l.repsPerSet,
            'multiplier': l.multiplier,
            'isBodyweight': l.isBodyweight ? 1 : 0,
            'isDumbbellLift': l.isDumbbellLift ? 1 : 0,
            // keep scoreType if present
            if (row.containsKey('scoreType'))
              'scoreType': (row['scoreType'] ?? 'multiplier'),
            // optional ordering if you have a column:
            if (row.containsKey('position')) 'position': idx,
          },
          where: 'liftId = ?',
          whereArgs: [liftId],
        );

        await _resizeLiftEntriesTx(db, workoutInstanceId, liftId, l.sets);
        matched.add(key);
      } else {
        // Insert new lift
        final newLiftId = await db.insert('workout_lifts', {
          'workoutInstanceId': workoutInstanceId,
          'liftName': l.name,
          'sets': l.sets,
          'repsPerSet': l.repsPerSet,
          'multiplier': l.multiplier,
          'isBodyweight': l.isBodyweight ? 1 : 0,
          'isDumbbellLift': l.isDumbbellLift ? 1 : 0,
          'scoreType': 'multiplier', // fallback
          'position': idx,           // if column exists, SQLite will ignore unknown columns
        });

        for (int i = 1; i <= l.sets; i++) {
          await db.insert('lift_entries', {
            'workoutInstanceId': workoutInstanceId,
            'liftId': newLiftId,
            'setIndex': i,
            'reps': 0,
            'weight': 0.0,
          });
        }
      }
    }

    // Remove lifts that aren’t in the new list
    for (final row in existing) {
      final key = k((row['liftName'] as String?) ?? '');
      if (matched.contains(key)) continue;
      final liftId = (row['liftId'] as num).toInt();

      try {
        if (row.containsKey('isHidden')) {
          await db.update('workout_lifts', {'isHidden': 1}, where: 'liftId = ?', whereArgs: [liftId]);
          continue;
        }
      } catch (_) {/* ignore */}

      await db.delete('lift_entries', where: 'workoutInstanceId = ? AND liftId = ?', whereArgs: [workoutInstanceId, liftId]);
      await db.delete('workout_lifts', where: 'liftId = ?', whereArgs: [liftId]);
    }
  }


// Public non-txn convenience (kept for any callers outside transactions)
  Future<void> reconcileWorkoutInstanceLifts(
      int workoutInstanceId,
      List<LiftDraft> newLifts,
      ) async {
    final db = await database;
    await _reconcileWorkoutInstanceLiftsTx(db, workoutInstanceId, newLifts);
  }


// TXN-aware entry resizer
  Future<void> _resizeLiftEntriesTx(
      dynamic db, // Database or Transaction
      int workoutInstanceId,
      int liftId,
      int newSetCount,
      ) async {
    final rows = await db.query(
      'lift_entries',
      where: 'workoutInstanceId = ? AND liftId = ?',
      whereArgs: [workoutInstanceId, liftId],
      orderBy: 'setIndex ASC',
    );

    final current = rows.length;
    if (current > newSetCount) {
      await db.delete(
        'lift_entries',
        where: 'workoutInstanceId = ? AND liftId = ? AND setIndex > ?',
        whereArgs: [workoutInstanceId, liftId, newSetCount],
      );
    } else if (current < newSetCount) {
      for (int i = current + 1; i <= newSetCount; i++) {
        await db.insert('lift_entries', {
          'workoutInstanceId': workoutInstanceId,
          'liftId': liftId,
          'setIndex': i,
          'reps': 0,
          'weight': 0.0,
        });
      }
    }
  }

  Future<void> _resizeEntriesForLiftInstanceTx(
      dynamic db, // Database or Transaction
      int liftInstanceId,
      int newSetCount,
      ) async {
    final rows = await db.query(
      'lift_entries',
      where: 'liftInstanceId = ?',
      whereArgs: [liftInstanceId],
      orderBy: 'setIndex ASC',
    );

    int? workoutInstanceId;
    int? liftId;
    if (rows.isNotEmpty) {
      workoutInstanceId = (rows.first['workoutInstanceId'] as num?)?.toInt();
      liftId = (rows.first['liftId'] as num?)?.toInt();
    } else {
      final li = await db.query(
        'lift_instances',
        columns: ['workoutInstanceId'],
        where: 'liftInstanceId = ?',
        whereArgs: [liftInstanceId],
        limit: 1,
      );
      if (li.isNotEmpty) {
        workoutInstanceId = (li.first['workoutInstanceId'] as num?)?.toInt();
      }
    }

    final current = rows.length;
    if (current > newSetCount) {
      await db.delete(
        'lift_entries',
        where: 'liftInstanceId = ? AND setIndex > ?',
        whereArgs: [liftInstanceId, newSetCount],
      );
    } else if (current < newSetCount) {
      for (int i = current + 1; i <= newSetCount; i++) {
        await db.insert('lift_entries', {
          'liftInstanceId': liftInstanceId,
          if (workoutInstanceId != null) 'workoutInstanceId': workoutInstanceId,
          if (liftId != null) 'liftId': liftId,
          'setIndex': i,
          'reps': 0,
          'weight': 0.0,
        });
      }
    }
  }

  /// Loads a single [WorkoutDraft] with its associated lifts from the database.
  // DEPRECATED: instance-only migration
  Future<WorkoutDraft?> fetchWorkoutDraft(int workoutId) async {
    debugPrint('DEPRECATED: fetchWorkoutDraft called');
    final db = await database;
    final workoutRows = await db.query('custom_workouts',
        where: 'id = ?', whereArgs: [workoutId], limit: 1);
    if (workoutRows.isEmpty) return null;
    final w = workoutRows.first;
    final liftRows = await db.query(
      'custom_lifts',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'position ASC',
    );
    final lifts = liftRows
        .map(
          (l) => LiftDraft(
            name: l['name'] as String,
            sets: l['sets'] as int,
            repsPerSet: l['repsPerSet'] as int,
            multiplier: (l['multiplier'] as num).toDouble(),
            isBodyweight: (l['isBodyweight'] as int) == 1,
            isDumbbellLift: (l['isDumbbellLift'] as int) == 1,
            position: (l['position'] as int?) ?? 0,
          ),
        )
        .toList();

    return WorkoutDraft(
      id: w['id'] as int,
      dayIndex: w['dayIndex'] as int,
      name: w['name'] as String? ?? '',
      lifts: lifts,
      isPersisted: true,
    );
  }

  /// Replaces an entire workout draft—including its lifts—in a single
  /// transaction.
  // DEPRECATED: instance-only migration
  Future<void> updateWorkoutDraft(WorkoutDraft workout) async {
    debugPrint('DEPRECATED: updateWorkoutDraft called');
    final db = await database;
    await db.transaction((txn) async {
      // Upsert the workout row first so JOINs won’t miss it
      await txn.insert(
        'custom_workouts',
        {
          'id': workout.id,
          'name': workout.name,
          'dayIndex': workout.dayIndex,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'custom_workouts',
        {
          'name': workout.name,
          'dayIndex': workout.dayIndex,
        },
        where: 'id = ?',
        whereArgs: [workout.id],
      );

      // Replace all lifts
      await txn.delete('custom_lifts', where: 'workoutId = ?', whereArgs: [workout.id]);
      print('[updateWorkoutDraft] workoutId=${workout.id} lifts=${workout.lifts.length}');

      for (var i = 0; i < workout.lifts.length; i++) {
        final lift = workout.lifts[i];
        await txn.insert('custom_lifts', {
          'workoutId': workout.id,
          'name': lift.name,
          'sets': lift.sets,
          'repsPerSet': lift.repsPerSet,
          'multiplier': lift.multiplier,
          'isBodyweight': lift.isBodyweight ? 1 : 0,
          'isDumbbellLift': lift.isDumbbellLift ? 1 : 0,
          'position': lift.position,
        });
      }
    });
  }

  // DEPRECATED: instance-only migration
  Future<void> upsertWorkoutDraftRow({
    required int id,
    required String name,
    required int dayIndex,
  }) async {
    debugPrint('DEPRECATED: upsertWorkoutDraftRow called');
    final db = await database;
    // 1) Try insert (ignore conflict)
    await db.insert(
      'custom_workouts',
      {
        'id': id,
        'name': name,
        'dayIndex': dayIndex,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // 2) Ensure fields are current
    await db.update(
      'custom_workouts',
      {
        'name': name,
        'dayIndex': dayIndex,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Safe for FIRST-TIME inserts. Ensures parent custom_blocks exists, then upserts custom_workouts.
  // DEPRECATED: instance-only migration
  Future<void> upsertWorkoutDraftRowWithBlock({
    required int id,
    required int blockId,
    required String name,
    required int dayIndex,
  }) async {
    debugPrint('DEPRECATED: upsertWorkoutDraftRowWithBlock called');
    final db = await database;
    await db.transaction((txn) async {
      // 1) Ensure parent custom_blocks row exists (FK requires it)
      await txn.insert(
        'custom_blocks',
        {
          'customBlockId': blockId,
          'name': 'Untitled Block',
          'uniqueWorkoutCount': 1,
          'workoutsPerWeek': 1,
          'totalWeeks': 1,
          'ownerUid': FirebaseAuth.instance.currentUser?.uid ?? '',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'isDraft': 1,
          'coverImagePath': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 2) Insert-or-ignore the custom_workouts parent row
      await txn.insert(
        'custom_workouts',
        {
          'id': id,
          'customBlockId': blockId,
          'name': name,
          'position': dayIndex,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 3) Keep name/dayIndex up to date
      await txn.update(
        'custom_workouts',
        {
          'name': name,
          'position': dayIndex,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Replaces all lift entries for a workout draft with [lifts]. This is used
  /// when editing or reordering lifts within a custom block draft.
  // DEPRECATED: instance-only migration
  Future<void> updateWorkoutDraftLifts(int workoutId, List<LiftDraft> lifts) async {
    debugPrint('DEPRECATED: updateWorkoutDraftLifts called');
    final db = await database;
    await db.transaction((txn) async {
      // Ensure parent exists (keeps things consistent if called early)
      await txn.insert(
        'custom_workouts',
        {'id': workoutId, 'customBlockId': 0, 'name': '', 'position': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await txn.delete('custom_lifts', where: 'customWorkoutId = ?', whereArgs: [workoutId]);
      for (var i = 0; i < lifts.length; i++) {
        final lift = lifts[i];
        await txn.insert('custom_lifts', {
          'customWorkoutId': workoutId,
          'name': lift.name,
          'sets': lift.sets,
          'repsPerSet': lift.repsPerSet,
          'multiplier': lift.multiplier,
          'isBodyweight': lift.isBodyweight ? 1 : 0,
          'isDumbbellLift': lift.isDumbbellLift ? 1 : 0,
          'position': lift.position,
        });
      }
    });
  }

  /// Updates the name of a workout draft in the database.
  // DEPRECATED: instance-only migration
  Future<void> updateWorkoutDraftName(int workoutId, String name) async {
    debugPrint('DEPRECATED: updateWorkoutDraftName called');
    final db = await database;
    await db.update('custom_workouts', {'name': name},
        where: 'id = ?', whereArgs: [workoutId]);
  }

  int? _findLiftIdByName(String name) {
    final match = liftDataList.firstWhere(
      (l) => (l['liftName'] as String).toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );
    return match.isNotEmpty ? match['liftId'] as int : null;
  }

  Future<int> _getOrCreateLiftId(DatabaseExecutor db, LiftDraft lift) async {
    final String name = lift.name.trim();
    final int isDb = lift.isDumbbellLift ? 1 : 0;

    // 1) Try cached/name lookup but only accept if dumbbell flag matches
    final int? cachedId = _findLiftIdByName(name);
    if (cachedId != null) {
      final row = await db.query(
        'lifts',
        where: 'liftId = ?',
        whereArgs: [cachedId],
        limit: 1,
      );
      if (row.isNotEmpty) {
        final int rowIsDb = (row.first['isDumbbellLift'] as int?) ?? 0;
        if (rowIsDb == isDb) {
          return cachedId;
        }
        // else: name matches but dumbbell flag differs → fall through and create/find the correct variant
      }
    }

    // 2) Case-insensitive match on name + dumbbell flag (authoritative lookup)
    final existing = await db.query(
      'lifts',
      where: 'LOWER(liftName) = ? AND COALESCE(isDumbbellLift,0) = ?',
      whereArgs: [name.toLowerCase(), isDb],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return (existing.first['liftId'] as num).toInt();
    }

    // 3) Create a new lift row (preserve your manual id & field semantics)
    final maxIdResult = await db.rawQuery('SELECT MAX(liftId) AS maxId FROM lifts');
    final int newId = ((maxIdResult.first['maxId'] as num?)?.toInt() ?? 0) + 1;

    await db.insert('lifts', {
      'liftId': newId,
      'liftName': name,
      'repScheme': '${lift.sets} sets x ${lift.repsPerSet} reps', // keep your format
      'numSets': lift.sets,
      'scoreMultiplier': lift.multiplier,
      'isDumbbellLift': isDb,
      'scoreType': lift.isBodyweight ? 'bodyweight' : 'multiplier', // keep existing scoring semantics
      'youtubeUrl': '',
      'description': '',
      'referenceLiftId': null,
      'percentOfReference': null,
    });

    return newId;
  }


  Future<List<Map<String, dynamic>>> getCustomBlocks() async {
    final db = await database;
    return db.query('custom_blocks', where: 'isDraft = 0');
  }

  Future<void> deleteCustomBlock(int id) async {
    final db = await database;
    await db.delete('custom_blocks', where: 'customBlockId = ?', whereArgs: [id]);

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

  Future<CustomBlockForEdit?> loadCustomBlockForEdit({
    required int customBlockId,
    int? blockInstanceId,
  }) async {
    final db = await database;

    // 1) Block shell
    final blockRows = await db.query(
      'custom_blocks',
      where: 'customBlockId = ?',
      whereArgs: [customBlockId],
      limit: 1,
    );
    if (blockRows.isEmpty) return null;
    final b = blockRows.first;

    // 2) Workouts depending on context
    final List<Map<String, Object?>> wRows;
    if (blockInstanceId == null) {
      wRows = await db.query(
        'custom_workouts',
        where: 'customBlockId = ?',
        whereArgs: [customBlockId],
        orderBy: 'position ASC, id ASC',
      );
    } else {
      final hasDayIndex = await _hasColumn(db, 'workout_instances', 'dayIndex');
      wRows = await db.query(
        'workout_instances',
        columns: [
          'workoutInstanceId AS id',
          if (hasDayIndex) 'dayIndex',
          'workoutName AS name',
        ],
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
        orderBy: hasDayIndex
            ? 'COALESCE(dayIndex, 0) ASC, workoutInstanceId ASC'
            : 'workoutInstanceId ASC',
      );
    }

    if (wRows.isEmpty) {
      return CustomBlockForEdit(
        id: (b['customBlockId'] ?? b['id']) as int,
        name: (b['name'] as String?) ?? '',
        numWeeks: (b['totalWeeks'] as int?) ?? (b['numWeeks'] as int?) ?? 4,
        daysPerWeek: (b['workoutsPerWeek'] as int?) ?? (b['daysPerWeek'] as int?) ?? 3,
        isDraft: ((b['isDraft'] as int?) ?? 0) == 1,
        coverImagePath: b['coverImagePath'] as String?,
        scheduleType: b['scheduleType']?.toString() ?? 'standard',
        workouts: const [],
      );
    }

    // 3) Fetch lifts for all workouts and group
    final workoutIds = wRows.map((w) => w['id'] as int).toList();
    final placeholders = List.filled(workoutIds.length, '?').join(',');
    final List<Map<String, Object?>> lRows;
    if (blockInstanceId == null) {
      lRows = await db.rawQuery(
        'SELECT * FROM custom_lifts WHERE customWorkoutId IN ($placeholders) ORDER BY position ASC, id ASC',
        workoutIds,
      );
    } else {
      lRows = await db.rawQuery(
        'SELECT * FROM lift_instances WHERE workoutInstanceId IN ($placeholders) AND COALESCE(archived,0)=0 ORDER BY position ASC, liftInstanceId ASC',
        workoutIds,
      );
    }

    final Map<int, List<LiftDraft>> liftsByWorkout = {};
    for (final l in lRows) {
      final wid = (blockInstanceId == null)
          ? l['customWorkoutId'] as int
          : l['workoutInstanceId'] as int;
      (liftsByWorkout[wid] ??= []).add(
        LiftDraft(
          id: (blockInstanceId == null)
              ? l['id'] as int?
              : l['liftInstanceId'] as int?,
          name: ((blockInstanceId == null)
                  ? l['name']
                  : l['liftName'])
              ?.toString() ??
              '',
          sets: (l['sets'] as int?) ?? 0,
          repsPerSet: (l['repsPerSet'] as int?) ?? 0,
          multiplier: (blockInstanceId == null)
              ? (l['multiplier'] as num?)?.toDouble() ?? 0.0
              : (l['scoreMultiplier'] as num?)?.toDouble() ?? 0.0,
          isBodyweight: ((l['isBodyweight'] as int?) ?? 0) == 1,
          isDumbbellLift: ((l['isDumbbellLift'] as int?) ?? 0) == 1,
          position: (l['position'] as int?) ?? 0,
        ),
      );
    }

    // 4) Build workouts
    int fallback = 0;
    final workouts = <WorkoutDraft>[];
    for (final w in wRows) {
      final wid = w['id'] as int;
      final dayIdx = (w['dayIndex'] as int?) ?? (w['position'] as int?) ?? (fallback++);
      workouts.add(
        WorkoutDraft(
          id: wid,
          dayIndex: dayIdx,
          name: (w['name'] as String?) ?? '',
          lifts: liftsByWorkout[wid] ?? const [],
          isPersisted: true,
        ),
      );
    }

    // 5) Return block
    return CustomBlockForEdit(
      id: (b['customBlockId'] ?? b['id']) as int,
      name: (b['name'] as String?) ?? '',
      numWeeks: (b['totalWeeks'] as int?) ?? (b['numWeeks'] as int?) ?? 4,
      daysPerWeek: (b['workoutsPerWeek'] as int?) ?? (b['daysPerWeek'] as int?) ?? 3,
      isDraft: ((b['isDraft'] as int?) ?? 0) == 1,
      coverImagePath: b['coverImagePath'] as String?,
      scheduleType: b['scheduleType']?.toString() ?? 'standard',
      workouts: workouts,
    );
  }

  @Deprecated('Use loadCustomBlockForEdit instead')
  // TODO: Remove after migrating all callers.
  Future<CustomBlockForEdit?> getCustomBlock(int id) =>
      loadCustomBlockForEdit(customBlockId: id);

  Future<int?> getCustomBlockIdForInstance(int blockInstanceId) async {
    final db = await database;
    final rows = await db.query(
      'block_instances',
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['customBlockId'];
    return (v is int) ? v : (v is num ? v.toInt() : null);
  }

  Future<int?> findActiveInstanceIdByName(String blockName, String userId) async {
    final db = await database;
    final rows = await db.query(
      'block_instances',
      columns: ['blockInstanceId'],
      where: 'userId = ? AND blockName = ? AND status = ?',
      whereArgs: [userId, blockName, 'active'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['blockInstanceId'] as int;
  }

  Future<int> addLiftToCustomWorkout({
    required int customBlockId,
    required int dayIndex,
    required String workoutName,
    required int liftCatalogId,
    required String repSchemeText,
    required int sets,
    required int repsPerSet,
    required int isBodyweight,
    required int isDumbbell,
    required String scoreType,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Ensure parent custom_blocks row exists to satisfy FK constraint.
      // If the row already exists this insert is ignored.
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert(
        'custom_blocks',
        {
          'customBlockId': customBlockId,
          'name': 'Untitled Block',
          'uniqueWorkoutCount': 1,
          'workoutsPerWeek': 1,
          'totalWeeks': 1,
          'ownerUid': uid,
          'createdAt': now,
          'updatedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Resolve or create the custom_workouts row for this block/day
      int customWorkoutId;
      final cwRows = await txn.query(
        'custom_workouts',
        columns: ['id'],
        where: 'customBlockId = ? AND position = ?',
        whereArgs: [customBlockId, dayIndex],
        limit: 1,
      );
      if (cwRows.isNotEmpty) {
        customWorkoutId = cwRows.first['id'] as int;
      } else {
        customWorkoutId = await txn.insert('custom_workouts', {
          'customBlockId': customBlockId,
          'name': workoutName,
          'position': dayIndex,
        });
      }

      final posRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) + 1 AS pos FROM custom_lifts WHERE customWorkoutId = ?',
        [customWorkoutId],
      );
      final position = (posRows.first['pos'] as num).toInt();

      String? liftName;
      final nameRows = await txn.query(
        'lift_catalog',
        columns: ['name'],
        where: 'catalogId = ?',
        whereArgs: [liftCatalogId],
        limit: 1,
      );
      if (nameRows.isNotEmpty) {
        liftName = nameRows.first['name'] as String?;
      }

      return await txn.insert('custom_lifts', {
        'customWorkoutId': customWorkoutId,
        'liftCatalogId': liftCatalogId,
        'name': liftName,
        'repSchemeText': repSchemeText,
        'sets': sets,
        'repsPerSet': repsPerSet,
        'isBodyweight': isBodyweight,
        'isDumbbell': isDumbbell,
        'scoreType': scoreType,
        'scoreMultiplier': null,
        'position': position,
      });
    });
  }

  Future<void> syncBuilderEdits({
    required int customBlockId,
    int? blockInstanceId,
    required int dayIndex,
    required List<LiftDraft> lifts,
    required List<Map<String, dynamic>> meta,
  }) async {
    final db = await database;

    // Determine the template workout we're editing
    final cwRows = await db.query(
      'custom_workouts',
      columns: ['id'],
      where: 'customBlockId = ? AND position = ?',
      whereArgs: [customBlockId, dayIndex],
      limit: 1,
    );
    if (cwRows.isEmpty) return;
    final customWorkoutId = cwRows.first['id'] as int;

    if (blockInstanceId == null) {
      // Draft-only path: update template lifts
      await db.transaction((txn) async {
        final existing = await txn.query(
          'custom_lifts',
          where: 'customWorkoutId = ?',
          whereArgs: [customWorkoutId],
        );
        final byId = <int, Map<String, Object?>>{
          for (final r in existing) r['id'] as int: r
        };
        final seen = <int>{};
        for (int i = 0; i < lifts.length; i++) {
          final l = lifts[i];
          final m = i < meta.length ? meta[i] : const {};
          final data = <String, Object?>{
            'customWorkoutId': customWorkoutId,
            'liftCatalogId': m['liftId'],
            'name': l.name,
            'repSchemeText':
                m['repScheme'] ?? '${l.sets}x${l.repsPerSet}',
            'sets': l.sets,
            'repsPerSet': l.repsPerSet,
            'scoreType': m['scoreType'],
            'scoreMultiplier': l.multiplier,
            'isBodyweight': l.isBodyweight ? 1 : 0,
            'isDumbbell': l.isDumbbellLift ? 1 : 0,
            'position': i,
          };
          if (l.id != null && byId.containsKey(l.id)) {
            await txn.update('custom_lifts', data,
                where: 'id = ?', whereArgs: [l.id]);
            seen.add(l.id!);
          } else {
            final newId = await txn.insert('custom_lifts', data);
            l.id = newId;
            seen.add(newId);
          }
        }
        for (final row in existing) {
          final id = row['id'] as int;
          if (!seen.contains(id)) {
            await txn.delete('custom_lifts', where: 'id = ?', whereArgs: [id]);
          }
        }
      });
      return;
    }

    // Active block path: propagate edits to all workout instances
    await db.transaction((txn) async {
      final baseRows = await txn.query(
        'workout_instances',
        columns: ['workoutInstanceId'],
        where: 'blockInstanceId = ? AND slotIndex = ?',
        whereArgs: [blockInstanceId, dayIndex],
        limit: 1,
      );
      if (baseRows.isEmpty) return;
      final baseWid = (baseRows.first['workoutInstanceId'] as num).toInt();

      final existing = await txn.query(
        'lift_instances',
        where: 'workoutInstanceId = ? AND archived = 0',
        whereArgs: [baseWid],
      );
      final byId = <int, Map<String, Object?>>{
        for (final r in existing) r['liftInstanceId'] as int: r
      };
      final seen = <int>{};
      final templateData = <Map<String, Object?>>[];

      for (int i = 0; i < lifts.length; i++) {
        final l = lifts[i];
        final m = i < meta.length ? meta[i] : const {};

        templateData.add({
          'customWorkoutId': customWorkoutId,
          'liftCatalogId': m['liftId'],
          'name': l.name,
          'repSchemeText': m['repScheme'] ?? '${l.sets}x${l.repsPerSet}',
          'sets': l.sets,
          'repsPerSet': l.repsPerSet,
          'scoreType': m['scoreType'],
          'scoreMultiplier': l.multiplier,
          'isBodyweight': l.isBodyweight ? 1 : 0,
          'isDumbbell': l.isDumbbellLift ? 1 : 0,
          'position': i,
        });

        if (l.id != null && byId.containsKey(l.id)) {
          await updateLiftAcrossSlot(
            workoutInstanceId: baseWid,
            liftInstanceId: l.id!,
            name: l.name,
            sets: l.sets,
            repsPerSet: l.repsPerSet,
            scoreMultiplier: l.multiplier,
            isDumbbellLift: l.isDumbbellLift,
            isBodyweight: l.isBodyweight,
            position: i,
            liftId: m['liftId'],
          );
          seen.add(l.id!);
        } else {
          await addLiftAcrossSlot(
            workoutInstanceId: baseWid,
            lift: l,
            insertAt: i,
            liftId: m['liftId'],
          );
        }
      }

      for (final row in existing) {
        final id = row['liftInstanceId'] as int;
        if (!seen.contains(id)) {
          await removeLiftAcrossSlot(
            workoutInstanceId: baseWid,
            liftInstanceId: id,
          );
        }
      }

      // Replace template with new definition
      await txn.delete('custom_lifts',
          where: 'customWorkoutId = ?', whereArgs: [customWorkoutId]);
      for (final data in templateData) {
        await txn.insert('custom_lifts', data);
      }
    });

    await recalculateBlockTotals(blockInstanceId);
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
      await db.query('custom_blocks', where: 'customBlockId = ?', whereArgs: [id]);
      if (existing.isNotEmpty) continue;
      final data = doc.data();
      data['customBlockId'] = id;
      await upsertCustomBlock(CustomBlock.fromMap(data));
    }
  }

  /// Applies edits from a custom block to an existing block instance.
  ///
  /// 1. Refreshes the standard block definition from the custom block.
  /// 2. Deletes any upcoming workout instances tied to [blockInstanceId].
  /// 3. Recreates workout instances so future workouts reflect the edits.
  /// Applies the latest Custom Block draft directly to the active block instance,
  /// without creating shadow blocks. Non-destructive where data exists.
  ///
  /// Guarantees:
  /// - Upserts workouts in draft order (dayIndex) and names.
  /// - Upserts lifts by a stable key (templateLiftId preferred; else name+shape),
  ///   preserving existing IDs so lift_entries / lift_totals remain linked.
  /// - Removes workouts/lifts that are no longer in the draft only if they have
  ///   no entries; otherwise sets archived=1 if available.
  Future<void> applyCustomBlockEdits(
      CustomBlock block, int blockInstanceId) async {
    final db = await database;

    // Persist latest edits locally before applying
    await upsertCustomBlock(block);

    await db.transaction((txn) async {
      // Ensure instance exists
      final instanceRows = await txn.query(
        'block_instances',
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
        limit: 1,
      );
      if (instanceRows.isEmpty) return;

      final instance = instanceRows.first;
      final String userId    = instance['userId']?.toString() ?? '';
      final String blockName = instance['blockName']?.toString() ?? '';

      // Keep instance pointing at this custom draft; update display name
      await txn.update(
        'block_instances',
        {'customBlockId': block.id, 'blockName': block.name},
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
      );

      // Figure out optional columns once
      final hasDayIndex    = await _hasColumn(txn, 'workout_instances', 'dayIndex');
      final hasPosCol      = await _hasColumn(txn, 'lift_instances', 'position');
      final hasArchivedWi  = await _hasColumn(txn, 'workout_instances', 'archived');
      final hasArchivedLi  = await _hasColumn(txn, 'lift_instances', 'archived');

      // Helpers
      Future<List<Map<String, Object?>>> workoutInstances() => txn.query(
        'workout_instances',
        where: 'blockInstanceId = ?',
        whereArgs: [blockInstanceId],
        // ✅ no dayIndex — sort by stable, existing columns
        orderBy: 'week ASC, scheduledDate ASC, workoutInstanceId ASC',
      );

      Future<List<Map<String, Object?>>> liftsFor(int workoutInstanceId) => txn.query(
        'lift_instances',
        where: 'workoutInstanceId = ?',
        whereArgs: [workoutInstanceId],
        orderBy: hasPosCol ? 'position ASC' : 'liftInstanceId ASC',
      );

      Future<bool> liftHasEntriesTx(int liftInstanceId) async {
        final rows = await txn.query(
          'lift_entries',
          where: 'liftInstanceId = ?',
          whereArgs: [liftInstanceId],
          limit: 1,
        );
        return rows.isNotEmpty;
      }

      // Key that doesn't rely on template IDs
      String rowKey(Map<String, Object?> m) {
        final n   = ((m['name'] ?? '') as String).toLowerCase().trim();
        final st  = (m['sets'] ?? 0).toString();
        final rp  = (m['repsPerSet'] ?? 0).toString();
        final dbb = (m['isDumbbellLift'] ?? 0).toString();
        final bw  = (m['isBodyweight'] ?? 0).toString();
        return '$n|$st|$rp|$dbb|$bw';
      }

      String draftKey(dynamic dl) {
        final n   = (dl.name as String).toLowerCase().trim();
        final st  = dl.sets.toString();
        final rp  = dl.repsPerSet.toString();
        final dbb = (dl.isDumbbellLift ? 1 : 0).toString();
        final bw  = (dl.isBodyweight ? 1 : 0).toString();
        return '$n|$st|$rp|$dbb|$bw';
      }

      // Existing workouts in stable order (index by array position, not dayIndex)
      final existingWorkouts = await workoutInstances();
      final Map<int, Map<String, Object?>> byOrdinal = {
        for (int idx = 0; idx < existingWorkouts.length; idx++) idx: existingWorkouts[idx]
      };

      final int daysPerWeek = block.daysPerWeek.clamp(1, 7);

      // Upsert workouts in draft order
      for (int i = 0; i < block.workouts.length; i++) {
        final draftW = block.workouts[i];
        Map<String, Object?>? existing = byOrdinal[i];

        if (existing == null) {
          final int week = (i ~/ daysPerWeek) + 1;
          final values = <String, Object?>{
            'blockInstanceId': blockInstanceId,
            'userId': userId,
            'workoutId': null,           // custom path
            'workoutName': draftW.name,  // schema uses workoutName
            'blockName': blockName,
            'week': week,
            'startTime': null,
            'endTime': null,
            'completed': 0,
          };
          if (hasDayIndex) values['dayIndex'] = i;

          final newWid = await txn.insert('workout_instances', values);
          existing = {
            'workoutInstanceId': newWid,
            'blockInstanceId': blockInstanceId,
            'workoutName': draftW.name,
          };
          if (hasDayIndex) existing['dayIndex'] = i;
        } else {
          final wid = existing['workoutInstanceId'] as int;
          final upd = <String, Object?>{
            'workoutName': draftW.name,
          };
          if (hasDayIndex) upd['dayIndex'] = i;

          await txn.update(
            'workout_instances',
            upd,
            where: 'workoutInstanceId = ?',
            whereArgs: [wid],
          );
        }

        // Sync lifts within this workout
        final wid = existing['workoutInstanceId'] as int;
        final currentLifts = await liftsFor(wid);
        final currentByKey = <String, Map<String, Object?>>{
          for (final l in currentLifts) rowKey(l): l
        };

        // Upsert/Update lifts
        for (int j = 0; j < draftW.lifts.length; j++) {
          final dl  = draftW.lifts[j];
          final key = draftKey(dl);
          final match = currentByKey[key];

          if (match == null) {
            final ins = <String, Object?>{
              'workoutInstanceId': wid,
              'liftName': dl.name,
              'sets': dl.sets,
              'repsPerSet': dl.repsPerSet,
              'scoreMultiplier': dl.multiplier,
              'isDumbbellLift': dl.isDumbbellLift ? 1 : 0,
              'isBodyweight': dl.isBodyweight ? 1 : 0,
            };
            if (hasPosCol) ins['position'] = j;

            final newLid = await txn.insert('lift_instances', ins);
            await _resizeEntriesForLiftInstanceTx(txn, newLid, dl.sets);
          } else {
            final lid = match['liftInstanceId'] as int;
            final upd = <String, Object?>{
              'liftName': dl.name,
              'sets': dl.sets,
              'repsPerSet': dl.repsPerSet,
              'scoreMultiplier': dl.multiplier,
              'isDumbbellLift': dl.isDumbbellLift ? 1 : 0,
              'isBodyweight': dl.isBodyweight ? 1 : 0,
            };
            if (hasPosCol) upd['position'] = j;

            await txn.update(
              'lift_instances',
              upd,
              where: 'liftInstanceId = ?',
              whereArgs: [lid],
            );
            await _resizeEntriesForLiftInstanceTx(txn, lid, dl.sets);
          }
        }

        // Remove/Archive lifts no longer in draft
        final draftKeys = <String>{for (final dl in draftW.lifts) draftKey(dl)};
        for (final cl in currentLifts) {
          final ck = rowKey(cl);
          if (!draftKeys.contains(ck)) {
            final lid = cl['liftInstanceId'] as int;
            final hasData = await liftHasEntriesTx(lid);

            if (!hasData) {
              await txn.delete('lift_instances', where: 'liftInstanceId = ?', whereArgs: [lid]);
            } else if (hasArchivedLi) {
              await txn.update('lift_instances', {'archived': 1}, where: 'liftInstanceId = ?', whereArgs: [lid]);
            }
          }
        }
      }

      // Remove/Archive workouts beyond draft length (by ordinal)
      for (int k = block.workouts.length; k < existingWorkouts.length; k++) {
        final orphan = byOrdinal[k];
        if (orphan == null) continue;
        final wid = orphan['workoutInstanceId'] as int;

        // Any entries under this workout?
        final liftIds = await txn.query(
          'lift_instances',
          columns: ['liftInstanceId'],
          where: 'workoutInstanceId = ?',
          whereArgs: [wid],
        );
        var hasAnyEntries = false;
        for (final row in liftIds) {
          if (await liftHasEntriesTx(row['liftInstanceId'] as int)) {
            hasAnyEntries = true; break;
          }
        }

        if (!hasAnyEntries) {
          await txn.delete('workout_instances', where: 'workoutInstanceId = ?', whereArgs: [wid]);
        } else if (hasArchivedWi) {
          await txn.update('workout_instances', {'archived': 1}, where: 'workoutInstanceId = ?', whereArgs: [wid]);
        }
      }

      // ignore: avoid_print
      print('[applyCustomBlockEdits] In-place sync complete for instance=$blockInstanceId (custom=${block.id})');
    });
  }

  Future<List<int>> _peerWorkoutIdsTx(DatabaseExecutor txn, int workoutInstanceId) async {
    final wi = await txn.query(
      'workout_instances',
      columns: ['blockInstanceId', 'slotIndex'],
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );
    if (wi.isEmpty) return [];
    final blockInstanceId = (wi.first['blockInstanceId'] as num).toInt();
    final slotIndex = (wi.first['slotIndex'] as num).toInt();
    final hasArchived = await _hasColumn(txn, 'workout_instances', 'archived');
    final where = StringBuffer('blockInstanceId = ? AND slotIndex = ?');
    final args = [blockInstanceId, slotIndex];
    if (hasArchived) where.write(' AND archived = 0');
    final rows = await txn.query(
      'workout_instances',
      columns: ['workoutInstanceId'],
      where: where.toString(),
      whereArgs: args,
    );
    return [for (final r in rows) (r['workoutInstanceId'] as num).toInt()];
  }

/// Count how many workouts in the same block share the same repeating slot
/// as this workout instance. Returns at least 1.
Future<int> peerCountForWorkoutInstance(int workoutInstanceId) async {
  final db = await database;

  // Locate block + slot for this instance
  final wi = await db.query(
    'workout_instances',
    columns: ['blockInstanceId', 'slotIndex'],
    where: 'workoutInstanceId = ?',
    whereArgs: [workoutInstanceId],
    limit: 1,
  );
  if (wi.isEmpty) return 1;

  final int blockInstanceId = (wi.first['blockInstanceId'] as num).toInt();
  final int? slotIndex = wi.first['slotIndex'] as int?;
  if (slotIndex == null) return 1;

  // Detect optional 'archived' column
  var hasArchived = false;
  try {
    final cols = await db.rawQuery('PRAGMA table_info(workout_instances);');
    hasArchived = cols.any(
      (r) => ((r['name'] as String?) ?? '').toLowerCase() == 'archived',
    );
  } catch (_) {}

  final whereArchived = hasArchived ? ' AND COALESCE(archived,0)=0' : '';

  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS c FROM workout_instances '
    'WHERE blockInstanceId = ? AND slotIndex = ?$whereArchived',
    [blockInstanceId, slotIndex],
  );

  final int count = (rows.first['c'] as num).toInt();
  return count == 0 ? 1 : count;
}

/// Backward-compatible alias for older call sites.
Future<int> peerCountForWorkout(int workoutInstanceId) =>
    peerCountForWorkoutInstance(workoutInstanceId);


  Future<String> _liftNameColTx(DatabaseExecutor txn) async {
    return await _hasColumn(txn, 'lift_instances', 'liftName') ? 'liftName' : 'name';
  }

  Future<void> addLiftAcrossSlot({
    required int workoutInstanceId,
    required LiftDraft lift,
    required int insertAt,
    int? liftId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final peerWids = await _peerWorkoutIdsTx(txn, workoutInstanceId);
      if (peerWids.isEmpty) return;
      final liftNameCol = await _liftNameColTx(txn);

      for (final wid in peerWids) {
        await txn.rawUpdate(
          'UPDATE lift_instances SET position = position + 1 WHERE workoutInstanceId = ? AND position >= ? AND archived = 0',
          [wid, insertAt],
        );

        final values = {
          'workoutInstanceId': wid,
          'liftId': liftId,
          liftNameCol: lift.name,
          'sets': lift.sets,
          'repsPerSet': lift.repsPerSet,
          'scoreMultiplier': lift.multiplier,
          'isDumbbellLift': lift.isDumbbellLift ? 1 : 0,
          'isBodyweight': lift.isBodyweight ? 1 : 0,
          'position': insertAt,
          'archived': 0,
        };
        final newLid = await txn.insert('lift_instances', values);
        await _resizeEntriesForLiftInstanceTx(txn, newLid, lift.sets);
      }
    });
  }

  Future<void> updateLiftAcrossSlot({
    required int workoutInstanceId,
    required int liftInstanceId,
    String? name,
    int? sets,
    int? repsPerSet,
    double? scoreMultiplier,
    bool? isDumbbellLift,
    bool? isBodyweight,
    int? position,
    int? liftId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final peerWids = await _peerWorkoutIdsTx(txn, workoutInstanceId);
      if (peerWids.isEmpty) return;
      final liftNameCol = await _liftNameColTx(txn);

      final baseRows = await txn.query(
        'lift_instances',
        where: 'liftInstanceId = ?',
        whereArgs: [liftInstanceId],
        limit: 1,
      );
      if (baseRows.isEmpty) return;
      final base = baseRows.first;
      final baseName = (base[liftNameCol]?.toString() ?? '').toLowerCase().trim();
      final baseSets = (base['sets'] as num?)?.toInt() ?? 0;
      final baseReps = (base['repsPerSet'] as num?)?.toInt() ?? 0;
      final baseDb = (base['isDumbbellLift'] as num?)?.toInt() ?? 0;
      final baseBw = (base['isBodyweight'] as num?)?.toInt() ?? 0;

      final shapeWhere = 'workoutInstanceId = ? AND archived = 0 AND lower($liftNameCol) = ? AND isDumbbellLift = ? AND isBodyweight = ? AND sets = ? AND repsPerSet = ?';
      final shapeArgs = [0, baseName, baseDb, baseBw, baseSets, baseReps];

      for (final wid in peerWids) {
        shapeArgs[0] = wid;
        final peer = await txn.query(
          'lift_instances',
          where: shapeWhere,
          whereArgs: shapeArgs,
          limit: 1,
        );
        if (peer.isEmpty) continue;
        final pid = (peer.first['liftInstanceId'] as num).toInt();

        final upd = <String, Object?>{};
        if (name != null) upd[liftNameCol] = name;
        if (sets != null) upd['sets'] = sets;
        if (repsPerSet != null) upd['repsPerSet'] = repsPerSet;
        if (scoreMultiplier != null) upd['scoreMultiplier'] = scoreMultiplier;
        if (isDumbbellLift != null) {
          upd['isDumbbellLift'] = isDumbbellLift ? 1 : 0;
        }
        if (isBodyweight != null) {
          upd['isBodyweight'] = isBodyweight ? 1 : 0;
        }
        if (position != null) upd['position'] = position;
        if (liftId != null) upd['liftId'] = liftId;
        if (upd.isEmpty) continue;

        await txn.update('lift_instances', upd,
            where: 'liftInstanceId = ?', whereArgs: [pid]);

        if (sets != null && sets != baseSets) {
          await _resizeEntriesForLiftInstanceTx(txn, pid, sets);
        }
      }
    });
  }

  Future<void> removeLiftAcrossSlot({
    required int workoutInstanceId,
    required int liftInstanceId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final peerWids = await _peerWorkoutIdsTx(txn, workoutInstanceId);
      if (peerWids.isEmpty) return;
      final liftNameCol = await _liftNameColTx(txn);

      final baseRows = await txn.query(
        'lift_instances',
        where: 'liftInstanceId = ?',
        whereArgs: [liftInstanceId],
        limit: 1,
      );
      if (baseRows.isEmpty) return;
      final base = baseRows.first;
      final baseName = (base[liftNameCol]?.toString() ?? '').toLowerCase().trim();
      final baseSets = (base['sets'] as num?)?.toInt() ?? 0;
      final baseReps = (base['repsPerSet'] as num?)?.toInt() ?? 0;
      final baseDb = (base['isDumbbellLift'] as num?)?.toInt() ?? 0;
      final baseBw = (base['isBodyweight'] as num?)?.toInt() ?? 0;

      final shapeWhere = 'workoutInstanceId = ? AND archived = 0 AND lower($liftNameCol) = ? AND isDumbbellLift = ? AND isBodyweight = ? AND sets = ? AND repsPerSet = ?';
      final shapeArgs = [0, baseName, baseDb, baseBw, baseSets, baseReps];

      for (final wid in peerWids) {
        shapeArgs[0] = wid;
        final peer = await txn.query(
          'lift_instances',
          columns: ['liftInstanceId'],
          where: shapeWhere,
          whereArgs: shapeArgs,
          limit: 1,
        );
        if (peer.isEmpty) continue;
        final lid = (peer.first['liftInstanceId'] as num).toInt();

        final hasData = await txn.query(
          'lift_entries',
          columns: ['1'],
          where: 'liftInstanceId = ? AND (reps > 0 OR weight > 0)',
          whereArgs: [lid],
          limit: 1,
        );
        if (hasData.isNotEmpty) {
          await txn.update('lift_instances', {'archived': 1},
              where: 'liftInstanceId = ?', whereArgs: [lid]);
        } else {
          await txn.delete('lift_entries',
              where: 'liftInstanceId = ?', whereArgs: [lid]);
          await txn.delete('lift_instances',
              where: 'liftInstanceId = ?', whereArgs: [lid]);
        }
      }
    });
  }


/// Rename a workout across all peers in the same slot within the block.
Future<void> updateWorkoutNameAcrossSlot(
  int workoutInstanceId,
  String name,
) async {
  final db = await database;
  await db.transaction((txn) async {
    // Find block + slot for this instance
    final wi = await txn.query(
      'workout_instances',
      columns: ['blockInstanceId', 'slotIndex'],
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );
    if (wi.isEmpty) return;

    final int blockInstanceId = (wi.first['blockInstanceId'] as num).toInt();
    final int? slotIndex = wi.first['slotIndex'] as int?;
    if (slotIndex == null) return;

    // Detect optional 'archived' column
    var hasArchived = false;
    try {
      final cols = await txn.rawQuery('PRAGMA table_info(workout_instances);');
      hasArchived = cols.any(
        (r) => ((r['name'] as String?) ?? '').toLowerCase() == 'archived',
      );
    } catch (_) {}

    final whereArchived = hasArchived ? ' AND COALESCE(archived,0)=0' : '';

    // Update all peers
    await txn.rawUpdate(
      'UPDATE workout_instances SET workoutName = ? '
      'WHERE blockInstanceId = ? AND slotIndex = ?$whereArchived',
      [name, blockInstanceId, slotIndex],
    );
  });
}



  Future<int?> findLatestInstanceIdByName(String blockName, String userId) async {
    final db = await database;
    final rows = await db.query(
      'block_instances',
      columns: ['blockInstanceId'],
      where: 'userId = ? AND blockName = ?',
      whereArgs: [userId, blockName],
      orderBy: 'blockInstanceId DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['blockInstanceId'] as int;
  }

  Future<int> createBlockFromCustomBlockId(int customId, String userId) async {
    final customBlock =
        await loadCustomBlockForEdit(customBlockId: customId);
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
        final liftId = await _getOrCreateLiftId(db, lift);
        await db.insert('lift_workouts', {
          'workoutId': workoutId,
          'liftId': liftId,
          'numSets': lift.sets,
          'repsPerSet': lift.repsPerSet,
          'multiplier': lift.multiplier,
          'isBodyweight': lift.isBodyweight ? 1 : 0,
          'isDumbbellLift': lift.isDumbbellLift ? 1 : 0,
        });
      }
    }

    final int blockInstanceId = await db.insert('block_instances', {
      'blockId': blockId,
      'customBlockId': customBlock.id,
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
  /// Creates a new block instance for the given [blockName]. If a matching
  /// custom block exists, the standard block definition is refreshed from it
  /// before the instance is created, ensuring any edits are respected on
  /// subsequent builds.
  Future<int> insertNewBlockInstance(String blockName, String userId) async {
    final db = await database;

    // 1) If there’s a Custom Block draft with this name, materialize a concrete block
    //    and create an instance pointing at it. (Seeder reads from blocks/workouts.)
    final custom = await db.query(
      'custom_blocks',
      where: 'name = ?',
      whereArgs: [blockName],
      limit: 1,
    );

    if (custom.isNotEmpty) {
      final int customBlockId = custom.first['customBlockId'] as int;

      // Use the existing materializer if present. It creates:
      // - a new row in `blocks`
      // - its `workouts` and `lift_workouts`
      // - a `block_instances` row
      // - and calls insertWorkoutInstancesForBlock(...) internally.
      //
      // If your local copy of createBlockFromCustomBlockId does NOT call
      // insertWorkoutInstancesForBlock, then call it right after and return.
      final int blockInstanceId = await createBlockFromCustomBlockId(customBlockId, userId);

      // If createBlockFromCustomBlockId already seeds, this call is redundant but harmless.
      // Uncomment if your implementation *doesn't* seed:
      // await insertWorkoutInstancesForBlock(blockInstanceId);

      return blockInstanceId;
    }

    // 2) Legacy: standard block by name (built-in programs)
    final blockData = await db.query(
      'blocks',
      where: 'blockName = ?',
      whereArgs: [blockName],
      limit: 1,
    );
    if (blockData.isEmpty) {
      throw Exception('❌ Block not found: $blockName');
    }
    final int blockId = blockData.first['blockId'] as int;

    // Create an instance pointing at the canonical block
    final int blockInstanceId = await db.insert('block_instances', {
      'blockId': blockId,
      'customBlockId': null,
      'blockName': blockName,
      'userId': userId,
      'startDate': null,
      'endDate': null,
      'status': "inactive",
    });

    // Seed workout_instances (and their lifts) for this instance
    await insertWorkoutInstancesForBlock(blockInstanceId);

    return blockInstanceId;
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

    // 1) Block instance
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

    final int blockId   = blockData.first['blockId'] as int;
    final String userId = blockData.first['userId']?.toString() ?? '';
    final String blockName = blockData.first['blockName']?.toString() ?? '';

    // 🔧 Defensive purge: remove ALL not-completed instances for this block instance
    // so inserts never collide and every instance gets freshly reseeded.
    await db.delete(
      'workout_instances',
      where: 'blockInstanceId = ? AND (completed IS NULL OR completed = 0)',
      whereArgs: [blockInstanceId],
    );

    // 2) Workouts wired to this (shadow) block
    final workouts = await db.rawQuery('''
    SELECT wb.workoutId, w.workoutName
    FROM workouts_blocks wb
    JOIN workouts w ON wb.workoutId = w.workoutId
    WHERE wb.blockId = ?
    ORDER BY wb.workoutBlockId ASC
  ''', [blockId]);

    if (workouts.isEmpty) {
      print("❌ No workouts found for Block ID: $blockId");
      return;
    }
    print("✅ Workouts found for Block ID $blockId: ${workouts.length}");

    // 3) Is this a custom block? (lookup by display name)
    final customBlock = await db.query(
      'custom_blocks',
      where: 'name = ?',
      whereArgs: [blockName],
      limit: 1,
    );
    final bool isCustomBlock = customBlock.isNotEmpty;
    final int? customDaysPerWeek =
        isCustomBlock ? (customBlock.first['workoutsPerWeek'] as int?) : null;
    final int? customNumWeeks =
        isCustomBlock ? (customBlock.first['totalWeeks'] as int?) : null;
    final int? customTotalLength = (customDaysPerWeek != null && customNumWeeks != null)
        ? customDaysPerWeek * customNumWeeks
        : null;

    // 4) Legacy schedule fallback
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

    int expectedLength;
    if (scheduleType == 'ppl_plus') {
      expectedLength = 21;
    } else {
      expectedLength = (workouts.length == 5) ? 20 : (workouts.length == 4) ? 16 : 12;
    }

    // 5) Build distribution
    // If this is a custom block but the shadow only contains the unique workouts (e.g. 3),
    // expand to the full length (daysPerWeek * numWeeks).
    final bool hasCustomLength = customTotalLength != null && customTotalLength > 0;
    final bool shadowLooksCollapsed = isCustomBlock && hasCustomLength && workouts.length != customTotalLength;

    final List<Map<String, dynamic>> base = (isCustomBlock || workouts.length == (customTotalLength ?? expectedLength))
        ? workouts
        : await generateWorkoutDistribution(workouts, scheduleType);

    final List<Map<String, dynamic>> distribution = shadowLooksCollapsed
        ? List.generate(customTotalLength!, (i) => base[i % base.length])
        : base;

    if (distribution.isEmpty) {
      print("❌ Distribution failed. No workouts to insert.");
      return;
    }

    final int dPerWeek = isCustomBlock ? (customDaysPerWeek ?? workoutsPerWeek) : workoutsPerWeek;

    // 6) Insert instances; never abort the whole loop on lift seeding errors
    final int numWorkouts = dPerWeek;
    int inserted = 0;
    for (int i = 0; i < distribution.length; i++) {
      final workout = distribution[i];
      final int week = (i ~/ dPerWeek) + 1;
      final int slotIndex = i % numWorkouts;

      final int newWorkoutInstanceId = await db.insert(
        'workout_instances',
        {
          'blockInstanceId': blockInstanceId,
          'userId': userId,
          'workoutId': workout['workoutId'],
          'workoutName': workout['workoutName'],
          'blockName': blockName,
          'week': week,
          'slotIndex': slotIndex,
          'startTime': null,
          'endTime': null,
          'completed': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (newWorkoutInstanceId == 0) {
        // ignore: avoid_print
        print("⚠️ Insert ignored for workout '${workout['workoutName']}' (duplicate?)");
        continue;
      }

      inserted++;
      // ignore: avoid_print
      print("✅ Inserted ${workout['workoutName']} (Week $week, Instance ID: $newWorkoutInstanceId)");

      try {
        await insertLiftsForWorkoutInstance(newWorkoutInstanceId);
      } catch (e, st) {
        // ignore: avoid_print
        print("⚠️ Failed to seed lifts for WI=$newWorkoutInstanceId (workoutId=${workout['workoutId']}): $e\n$st");
        // keep going; instances should still appear in the dashboard
      }
    }

    // ignore: avoid_print
    print("✅ Inserted $inserted/${distribution.length} workout instances for blockInstanceId $blockInstanceId");
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
  @Deprecated('Legacy shadow distribution') // TODO: Delete once custom scheduling is stable.
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
    await _maybeRecomputeCustomMultiplier(workoutInstanceId, liftId);
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

  Future<void> _maybeRecomputeCustomMultiplier(
      int workoutInstanceId, int liftId) async {
    final db = await database;
    // Detect custom block and gather context
    final ctx = await db.rawQuery('''
      SELECT wi.blockInstanceId, wi.workoutId, li.liftInstanceId, li.sets,
             li.position, COALESCE(li.isBodyweight,0) AS isBodyweight
      FROM lift_instances li
      JOIN workout_instances wi ON wi.workoutInstanceId = li.workoutInstanceId
      JOIN block_instances bi ON bi.blockInstanceId = wi.blockInstanceId
      WHERE li.workoutInstanceId = ? AND (li.liftInstanceId = ? OR li.liftId = ?)
        AND bi.customBlockId IS NOT NULL
      LIMIT 1
    ''', [workoutInstanceId, liftId, liftId]);

    if (ctx.isEmpty) return; // not custom or lift not found
    final row = ctx.first;
    if ((row['isBodyweight'] as int? ?? 0) == 1) return; // skip bodyweight

    final liftInstanceId = (row['liftInstanceId'] as num).toInt();
    final sets = (row['sets'] as num?)?.toInt() ?? 0;
    if (sets <= 0) return;

    final completed = await db.rawQuery('''
      SELECT COUNT(*) AS c
      FROM lift_entries
      WHERE liftInstanceId = ? AND (reps > 0 OR weight > 0)
    ''', [liftInstanceId]);
    final logged = (completed.first['c'] as num?)?.toInt() ?? 0;
    if (logged < sets) return; // not yet complete

    final blockInstanceId = (row['blockInstanceId'] as num).toInt();
    final customWorkoutId = (row['workoutId'] as num).toInt();
    final position = (row['position'] as num?)?.toInt() ?? 0;

    final template = await db.query('custom_lifts',
        columns: ['id'],
        where: 'customWorkoutId = ? AND position = ?',
        whereArgs: [customWorkoutId, position],
        limit: 1);
    if (template.isEmpty) return;
    final customLiftId = (template.first['id'] as num).toInt();

    await ScoreMultiplierService.computeAndApplyForCustomLift(
      customLiftId: customLiftId,
      blockInstanceId: blockInstanceId,
    );
  }

  Future<void> insertLiftsForWorkoutInstance(int workoutInstanceId) async {
    final db = await database;

    // 1) Find the instance → get workoutId + userId
    final wi = await db.query(
      'workout_instances',
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
      limit: 1,
    );
    if (wi.isEmpty) {
      // ignore: avoid_print
      print('❌ insertLiftsForWorkoutInstance: WI $workoutInstanceId not found');
      return;
    }
    final int workoutId = (wi.first['workoutId'] as num).toInt();
    final String userId = wi.first['userId']?.toString() ?? '';

    // 2) Get the lifts configured for THIS workout (the authoritative mapping)
    final liftRows = await db.query(
      'lift_workouts',
      columns: ['liftId', 'numSets', 'repsPerSet'],
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'liftWorkoutId ASC',
    );
    if (liftRows.isEmpty) {
      // ignore: avoid_print
      print('⚠️ No lift_workouts for workoutId=$workoutId (WI=$workoutInstanceId)');
      return;
    }

    // 3) Clear any earlier seeds for this instance (avoid dupes on rebuild)
    await db.delete(
      'lift_entries',
      where: 'workoutInstanceId = ?',
      whereArgs: [workoutInstanceId],
    );

    // 4) Seed one row per set for each lift, guarding FKs
    for (final lw in liftRows) {
      final int liftId = (lw['liftId'] as num).toInt();

      // If your schema enforces lift_entries.liftId → lifts(liftId), skip missing lifts.
      final liftExists = await db.query(
        'lifts',
        columns: ['liftId'],
        where: 'liftId = ?',
        whereArgs: [liftId],
        limit: 1,
      );
      if (liftExists.isEmpty) {
        // ignore: avoid_print
        print('⚠️ liftId=$liftId missing in lifts; skip (WI=$workoutInstanceId)');
        continue;
      }

      final int numSets    = (lw['numSets']    as num?)?.toInt() ?? 3;
      final int repsPerSet = (lw['repsPerSet'] as num?)?.toInt() ?? 0;

      for (int s = 0; s < numSets; s++) {
        await db.insert(
          'lift_entries',
          {
            'workoutInstanceId': workoutInstanceId,
            'liftId': liftId,
            'setIndex': s,
            'reps': 0,
            'weight': 0.0,
            'userId': userId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    // Optional: recompute totals here if you rely on them immediately
    // await recomputeTotalsForWorkoutInstance(workoutInstanceId, userId);
  }

  Future<bool> isCustomBlockInstance(int blockInstanceId) async {
    final db = await database;
    final rows = await db.query(
      'block_instances',
      columns: ['customBlockId'],
      where: 'blockInstanceId = ?',
      whereArgs: [blockInstanceId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final v = rows.first['customBlockId'];
    return v != null && v is int && v > 0;
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

    List<int> liftIds = List<int>.from(workoutDef['liftIds'] ?? []);

    // If no lifts are defined in the static workout data, fall back to the DB
    if (liftIds.isEmpty) {
      // Try pulling the lifts from lift_workouts for this workoutId
      final liftWorkouts = await db.query(
        'lift_workouts',
        columns: ['liftId'],
        where: 'workoutId = ?',
        whereArgs: [workoutId],
      );

      liftIds = liftWorkouts
          .map((row) => (row['liftId'] as num).toInt())
          .toList();

      // If still empty, aggregate directly from lift_totals for this instance
      if (liftIds.isEmpty) {
        final totals = await db.rawQuery('''
        SELECT liftId, SUM(liftScore) AS liftScore, SUM(liftWorkload) AS liftWorkload
        FROM lift_totals
        WHERE workoutInstanceId = ? AND userId = ?
        GROUP BY liftId
      ''', [workoutInstanceId, userId]);

        if (totals.isEmpty) {
          print("⚠️ No lifts found for workoutId $workoutId (instance $workoutInstanceId)");
          return;
        }

        double totalScore = 0.0;
        double totalWorkload = 0.0;
        for (final row in totals) {
          totalScore += (row['liftScore'] as num?)?.toDouble() ?? 0.0;
          totalWorkload += (row['liftWorkload'] as num?)?.toDouble() ?? 0.0;
        }

        final averageScore = totalScore / totals.length;

        await upsertWorkoutTotals(
          workoutInstanceId: workoutInstanceId,
          userId: userId,
          blockInstanceId: blockInstanceId,
          workoutWorkload: totalWorkload,
          workoutScore: averageScore,
        );

        print(
            "✅ Updated workout_totals (dynamic lifts): Workout $workoutInstanceId | Workload: $totalWorkload | Score: $averageScore");

        await recalculateBlockTotals(blockInstanceId);
        if (syncToCloud) {
          await syncWorkoutTotalsToFirestore(userId);
        }
        return;
      }
    }

    // Aggregate using the liftIds list
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
      }
    }

    final averageScore = liftIds.isNotEmpty ? (totalScore / liftIds.length) : 0.0;

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
    final int? customBlockId = blockData.first['customBlockId'] as int?;

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

      double score = 0.0;
      double workload = 0.0;

      if (customBlockId != null) {
        // Recompute lift totals for each lift in this custom workout.
        final lifts = await getLiftsForWorkoutInstance(workoutInstanceId);
        double totalScore = 0.0;
        double totalWorkload = 0.0;
        int liftCount = 0;
        for (final l in lifts) {
          final int? lid = l['liftId'] as int?;
          if (lid == null) continue;
          await updateLiftTotals(workoutInstanceId, lid);
          final lt = await db.query('lift_totals',
              columns: ['liftScore', 'liftWorkload'],
              where: 'workoutInstanceId = ? AND liftId = ? AND userId = ?',
              whereArgs: [workoutInstanceId, lid, userId],
              limit: 1);
          if (lt.isNotEmpty) {
            totalScore += (lt.first['liftScore'] as num?)?.toDouble() ?? 0.0;
            totalWorkload +=
                (lt.first['liftWorkload'] as num?)?.toDouble() ?? 0.0;
            liftCount++;
          }
        }
        workload = totalWorkload;
        score = liftCount > 0 ? totalScore / liftCount : 0.0;

        await upsertWorkoutTotals(
          workoutInstanceId: workoutInstanceId,
          userId: userId,
          blockInstanceId: blockInstanceId,
          workoutWorkload: workload,
          workoutScore: score,
        );
        await updateWorkoutTotals(
          workoutInstanceId: workoutInstanceId,
          userId: userId,
          workoutWorkload: workload,
          workoutScore: score,
        );
      } else {
        final totals = await getWorkoutTotals(workoutInstanceId, userId);
        score = (totals?['workoutScore'] as num?)?.toDouble() ?? 0.0;
        workload = (totals?['workoutWorkload'] as num?)?.toDouble() ?? 0.0;
      }

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

// Convert your existing String? API to int?
  Future<int?> getActiveBlockInstanceIdInt(String userId) async {
    final idStr = await getActiveBlockInstanceId(userId);
    return int.tryParse(idStr ?? '');
  }

// Insert into earned_badges if not already present for this block
  Future<void> upsertEarnedBadge({
    required String userId,
    required int blockInstanceId,
    required String badgeId,
    required String name,
    required String imagePath,
  }) async {
    final db = await database;

    final exists = await db.rawQuery('''
    SELECT 1 FROM earned_badges
    WHERE userId = ? AND blockInstanceId = ? AND badgeId = ?
    LIMIT 1
  ''', [userId, blockInstanceId, badgeId]);

    if (exists.isEmpty) {
      await db.insert('earned_badges', {
        'badgeId': badgeId,
        'userId': userId,
        'blockInstanceId': blockInstanceId,
        'name': name,
        'imagePath': imagePath,
      });
    }
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
      SELECT lw.liftId, l.liftName,
             CASE WHEN lw.repsPerSet IS NOT NULL THEN
               (lw.numSets || ' sets x ' || lw.repsPerSet || ' reps')
             ELSE l.repScheme END AS repScheme,
             lw.numSets,
             COALESCE(lw.multiplier, l.scoreMultiplier) AS scoreMultiplier,
             COALESCE(lw.isDumbbellLift, l.isDumbbellLift) AS isDumbbellLift,
             CASE WHEN lw.isBodyweight = 1 THEN 'bodyweight' ELSE l.scoreType END AS scoreType,
             l.youtubeUrl,
             l.description,
             l.referenceLiftId,
             l.percentOfReference,
             lw.isBodyweight AS isBodyweight
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
             l.liftId, l.liftName,
             CASE WHEN lw.repsPerSet IS NOT NULL THEN
               (lw.numSets || ' sets x ' || lw.repsPerSet || ' reps')
             ELSE l.repScheme END AS repScheme,
             lw.numSets,
             COALESCE(lw.multiplier, l.scoreMultiplier) AS scoreMultiplier,
             COALESCE(lw.isDumbbellLift, l.isDumbbellLift) AS isDumbbellLift,
             CASE WHEN lw.isBodyweight = 1 THEN 'bodyweight' ELSE l.scoreType END AS scoreType,
             l.youtubeUrl,
             l.description,
             l.referenceLiftId,
             l.percentOfReference,
             lw.isBodyweight AS isBodyweight
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

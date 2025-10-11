// GENERATED — DO NOT EDIT BY HAND.
// Source: lib/services/db_service.dart (onCreate + migrations)
import 'package:lift_league/services/db_service.dart' show CURRENT_DB_VERSION;

const int SCHEMA_USER_VERSION = CURRENT_DB_VERSION;

// Exact CREATE TABLE statements in creation order:
const List<String> schemaCreateStatements = [
  '''
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
    ''',
  '''
      CREATE TABLE blocks (
        blockId INTEGER PRIMARY KEY AUTOINCREMENT,
        blockName TEXT,
        scheduleType TEXT,
        numWorkouts INTEGER
      )
    ''',
  '''
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
    ''',
  '''
      CREATE TABLE workouts (
        workoutId INTEGER PRIMARY KEY,
        workoutName TEXT
      )
    ''',
  '''
      CREATE TABLE workouts_blocks (
        workoutBlockId INTEGER PRIMARY KEY AUTOINCREMENT,
        blockId INTEGER NOT NULL,
        workoutId INTEGER NOT NULL,
        FOREIGN KEY (blockId) REFERENCES blocks(blockId) ON DELETE CASCADE,
        FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE
      );
    ''',
  '''
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
    ''',
  '''
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
    ''',
  '''
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
    ''',
  '''
      CREATE TABLE lift_entries (
        liftEntryId INTEGER PRIMARY KEY AUTOINCREMENT,
        liftInstanceId INTEGER,
        workoutInstanceId INTEGER,
        liftId INTEGER,
        setIndex INTEGER,
        reps INTEGER,
        weight REAL,
        userId TEXT,
        FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE
      )
    ''',
  '''
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
    ''',
  '''
      CREATE TABLE IF NOT EXISTS workout_totals (
        workoutInstanceId INTEGER PRIMARY KEY,
        userId TEXT,
        blockInstanceId INTEGER,
        workoutWorkload REAL DEFAULT 0.0,
        workoutScore REAL DEFAULT 0.0,
        FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId),
        FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId)
      )
    ''',
  '''
      CREATE TABLE IF NOT EXISTS block_totals (
        blockInstanceId INTEGER PRIMARY KEY,
        userId TEXT,
        blockId INTEGER,         -- 🔥 needed for leaderboard grouping
        blockName TEXT,          -- 🏷️ display name for leaderboard
        blockWorkload REAL DEFAULT 0.0,
        blockScore REAL DEFAULT 0.0,
        FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId)
      );

    ''',
  '''
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
''',
  '''
CREATE TABLE IF NOT EXISTS custom_workouts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customBlockId INTEGER NOT NULL,
  name TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
);
''',
  '''
CREATE TABLE IF NOT EXISTS custom_lifts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customWorkoutId INTEGER NOT NULL,
  liftCatalogId INTEGER,
  name TEXT NOT NULL,
  repSchemeText TEXT,
  sets INTEGER,
  repsPerSet INTEGER,
  scoreType INTEGER,
  scoreMultiplier REAL,          -- legacy mirror
  baseMultiplier REAL,           -- db.md aligned
  isBodyweight INTEGER,
  isDumbbell INTEGER,            -- legacy mirror
  logUnilaterally INTEGER DEFAULT 0, -- db.md aligned
  position INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(customWorkoutId) REFERENCES custom_workouts(id) ON DELETE CASCADE
);
''',
  '''
CREATE TABLE IF NOT EXISTS custom_block_instances (
  blockInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
  customBlockId INTEGER NOT NULL,
  runNumber INTEGER NOT NULL DEFAULT 1,
  startDate INTEGER NULL,
  endDate INTEGER NULL,
  FOREIGN KEY(customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
);
''',
  '''
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
''',
  '''
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
''',
  '''
CREATE TABLE IF NOT EXISTS lift_aliases (
  aliasId INTEGER PRIMARY KEY AUTOINCREMENT,
  catalogId INTEGER NOT NULL,
  alias TEXT NOT NULL,
  FOREIGN KEY(catalogId) REFERENCES lift_catalog(catalogId) ON DELETE CASCADE
);
''',
  '''
      CREATE TABLE IF NOT EXISTS health_weight_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        value REAL,
        bmi REAL,
        bodyFat REAL,
        source TEXT
      )
    ''',
  '''
      CREATE TABLE IF NOT EXISTS health_energy_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        kcalIn REAL,
        kcalOut REAL,
        source TEXT
      )
    ''',
];

// Exact CREATE INDEX / UNIQUE INDEX statements:
const List<String> schemaIndexStatements = [
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_wb_block_workout ON workouts_blocks(blockId, workoutId);',
  'CREATE INDEX IF NOT EXISTS idx_li_workout_archived_pos ON lift_instances (workoutInstanceId, archived, position);',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_le_instance_set ON lift_entries(liftInstanceId, setIndex);',
  'CREATE INDEX IF NOT EXISTS idx_cwi_block_week_slot ON custom_workout_instances(blockInstanceId, week, slot);',
  'CREATE INDEX IF NOT EXISTS idx_cw_block_pos ON custom_workouts(customBlockId, position);',
  'CREATE INDEX IF NOT EXISTS idx_clifts_cw_pos ON custom_lifts(customWorkoutId, position);',
  'CREATE INDEX IF NOT EXISTS idx_lc_group ON lift_catalog(primaryGroup);',
  'CREATE INDEX IF NOT EXISTS idx_la_alias ON lift_aliases(alias);',
  'CREATE INDEX IF NOT EXISTS idx_wi_user_block ON workout_instances (userId, blockInstanceId);',
  'CREATE INDEX IF NOT EXISTS idx_wi_sched ON workout_instances (scheduledDate);',
  'CREATE INDEX IF NOT EXISTS idx_wi_block_completed ON workout_instances (blockInstanceId, completed);',
  'CREATE INDEX IF NOT EXISTS idx_lw_workout_pos ON lift_workouts(workoutId, position);',
];

# The Lift League — Database Playbook

**Goal:** Clean separation of (1) catalog identities, (2) stock templates, (3) custom structure, and (4) runtime instances + logging + totals.  
**Principles:**
- Templates define prescription; instances freeze it for history.
- Stock and custom converge at instances; scoring uses instance-frozen fields.
- Unilateral duplicates all aggregates (reps, workload, weightUsed) for that lift.

See also: `docs/scoring.md` for formulas.

---

## 1) Table Map (What lives where)

### 1.1 Catalog (seeded, read-only)
Identity & capabilities only; **no sets/reps/multipliers**.
```sql
CREATE TABLE IF NOT EXISTS lift_catalog (
  catalogId              INTEGER PRIMARY KEY,
  liftName               TEXT NOT NULL,
  primaryGroup           TEXT NOT NULL,
  secondaryGroup         TEXT,
  equipment              TEXT NOT NULL,
  isBodyweightCapable    INTEGER NOT NULL DEFAULT 0,
  isUnilateralCapable    INTEGER NOT NULL DEFAULT 0,
  UNIQUE(liftName, equipment)
);
CREATE INDEX IF NOT EXISTS idx_lc_name ON lift_catalog(liftName);
1.2 Stock Templates (seeded, read-only)
Defines how catalog lifts are used in stock workouts/blocks.


CREATE TABLE IF NOT EXISTS blocks (
  blockId INTEGER PRIMARY KEY,
  blockName TEXT NOT NULL,
  numWeeks INTEGER NOT NULL,
  numWorkouts INTEGER NOT NULL,
  scheduleType TEXT 
);

CREATE TABLE IF NOT EXISTS workouts (
  workoutId INTEGER PRIMARY KEY,
  workoutName TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workouts_blocks (
  blockId   INTEGER NOT NULL,
  workoutId INTEGER NOT NULL,
  position  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (blockId, workoutId),
  FOREIGN KEY (blockId)   REFERENCES blocks(blockId)   ON DELETE CASCADE,
  FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE
);

-- Link + prescription for stock workouts
CREATE TABLE IF NOT EXISTS lift_templates (
  workoutId        INTEGER NOT NULL,
  catalogId        INTEGER NOT NULL,
  position         INTEGER NOT NULL DEFAULT 0,
  sets             INTEGER,
  repsPerSet       INTEGER,
  baseMultiplier   REAL,               -- NULL when scoreType=BODYWEIGHT
  scoreType        INTEGER NOT NULL,   -- 0=MULTIPLIER, 1=BODYWEIGHT
  logUnilaterally  INTEGER NOT NULL DEFAULT 0,  -- doubles reps/workload/weightUsed for this lift
  groupKey         TEXT,               -- Optional unique identifier tying lifts that belong to the same superset or circuit
  instructions     TEXT,
  referenceCatalogId INTEGER,    -- optional: which catalog lift this one references
  percentOfReference REAL,       -- optional: e.g., 0.70 for 70%
  PRIMARY KEY (workoutId, catalogId),
  FOREIGN KEY (workoutId) REFERENCES workouts(workoutId) ON DELETE CASCADE,
  FOREIGN KEY (catalogId) REFERENCES lift_catalog(catalogId) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_lt_w ON lift_templates(workoutId, position);
1.3 Custom Templates (user-created structure)
No separate custom_lifts table. Week-1 instances act as the “live template”; edits propagate to all instances of that workout in the block.


CREATE TABLE IF NOT EXISTS custom_blocks (
  customBlockId   INTEGER PRIMARY KEY AUTOINCREMENT,
  userId          TEXT NOT NULL,
  customBlockName TEXT NOT NULL,
  numWeeks        INTEGER NOT NULL,
  numWorkouts     INTEGER NOT NULL,
  workoutsPerWeek INTEGER,
  isDraft         INTEGER NOT NULL DEFAULT 1,
  coverImagePath  TEXT
);

CREATE TABLE IF NOT EXISTS custom_workouts (
  customWorkoutId   INTEGER PRIMARY KEY AUTOINCREMENT,
  customBlockId     INTEGER NOT NULL,
  customWorkoutName TEXT NOT NULL,
  position          INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (customBlockId) REFERENCES custom_blocks(customBlockId) ON DELETE CASCADE
);
1.4 Runtime (where stock + custom meet)
Instances freeze the prescription and scoring config for history.


CREATE TABLE IF NOT EXISTS block_instances (
  blockInstanceId INTEGER PRIMARY KEY AUTOINCREMENT,
  userId          TEXT NOT NULL,
  sourceType      INTEGER NOT NULL,    -- 0=stock, 1=custom
  sourceBlockId   INTEGER NOT NULL,    -- blocks.blockId or custom_blocks.customBlockId
  blockName       TEXT NOT NULL,
  runNumber       INTEGER NOT NULL DEFAULT 1,
  startDate       INTEGER,
  endDate         INTEGER
);

CREATE TABLE IF NOT EXISTS workout_instances (
  workoutInstanceId     INTEGER PRIMARY KEY AUTOINCREMENT,
  blockInstanceId       INTEGER NOT NULL,
  sourceWorkoutId       INTEGER,       -- stock
  sourceCustomWorkoutId INTEGER,       -- custom
  workoutName           TEXT NOT NULL,
  week                  INTEGER,
  slotIndex             INTEGER,       -- = weekIndex*weeklySlots + dayIndex
  startTime             INTEGER,
  endTime               INTEGER,
  completed             INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS lift_instances (
  liftInstanceId     INTEGER PRIMARY KEY AUTOINCREMENT,
  workoutInstanceId  INTEGER NOT NULL,
  catalogId          INTEGER,          -- NULL if freeform custom
  liftName           TEXT NOT NULL,
  position           INTEGER NOT NULL DEFAULT 0,
  groupKey           TEXT,             -- Optional unique identifier tying lifts that belong to the same superset or circuit
  sets               INTEGER,
  repsPerSet         INTEGER,

  -- frozen scoring config
  scoreType          INTEGER NOT NULL,    -- 0=MULTIPLIER, 1=BODYWEIGHT
  baseMultiplier     REAL,                -- NULL for BODYWEIGHT
  logUnilaterally    INTEGER NOT NULL DEFAULT 0,  -- duplicates reps/workload/weightUsed
  referenceLiftInstanceId INTEGER,  -- optional: resolved pointer at instance time
  percentOfReference REAL,          -- carried over from template
  instructions       TEXT,
  archived           INTEGER NOT NULL DEFAULT 0,  -- safe removal flag

  FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_li_w ON lift_instances(workoutInstanceId, position);
1.5 Logging + Totals (authoritative for UI)

CREATE TABLE IF NOT EXISTS lift_entries (
  liftEntryId     INTEGER PRIMARY KEY AUTOINCREMENT,
  liftInstanceId  INTEGER NOT NULL,
  setIndex        INTEGER NOT NULL,
  reps            INTEGER,
  weight          REAL,         -- "weightUsed" per set; not rendered
  createdAt       INTEGER NOT NULL,
  FOREIGN KEY (liftInstanceId) REFERENCES lift_instances(liftInstanceId) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_le_li ON lift_entries(liftInstanceId);

CREATE TABLE IF NOT EXISTS lift_totals (
  liftInstanceId    INTEGER PRIMARY KEY,
  workoutInstanceId INTEGER NOT NULL,
  liftReps          INTEGER NOT NULL DEFAULT 0,   -- effective (after unilateral)
  liftWorkload      REAL    NOT NULL DEFAULT 0,   -- effective (after unilateral)
  liftScore         REAL    NOT NULL DEFAULT 0,
  FOREIGN KEY (liftInstanceId)    REFERENCES lift_instances(liftInstanceId)    ON DELETE CASCADE,
  FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS workout_totals (
  workoutInstanceId INTEGER PRIMARY KEY,
  blockInstanceId   INTEGER NOT NULL,
  workoutWorkload   REAL NOT NULL DEFAULT 0,
  workoutScore      REAL NOT NULL DEFAULT 0,
  FOREIGN KEY (workoutInstanceId) REFERENCES workout_instances(workoutInstanceId) ON DELETE CASCADE,
  FOREIGN KEY (blockInstanceId)   REFERENCES block_instances(blockInstanceId)   ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS block_totals (
  blockInstanceId INTEGER PRIMARY KEY,
  userId          TEXT NOT NULL,
  blockWorkload   REAL NOT NULL DEFAULT 0,
  blockScore      REAL NOT NULL DEFAULT 0,
  FOREIGN KEY (blockInstanceId) REFERENCES block_instances(blockInstanceId) ON DELETE CASCADE
);
2) Seeding & Opening Strategy
Ship a pre-populated SQLite asset (assets/db/seed_vXX.db) with all stock tables (catalog, blocks, workouts, workouts_blocks, lift_templates) and indexes.

On first run only (no DB file), copy the asset; then open DB and run migrations as needed.

Keep PRAGMA foreign_keys = ON in onOpen.

3) Materialization (Template → Instances)
3.1 Stock path
For each stock workout in a stock block, create a workout_instance, then insert lift_instances from lift_templates + lift_catalog:

INSERT INTO lift_instances (
  workoutInstanceId, catalogId, liftName, position,
  sets, repsPerSet, scoreType, baseMultiplier, logUnilaterally, instructions
)
SELECT
  ?, lc.catalogId, lc.liftName, lt.position,
  lt.sets, lt.repsPerSet, lt.scoreType, lt.baseMultiplier, lt.logUnilaterally, lt.instructions
FROM lift_templates lt
JOIN lift_catalog lc ON lc.catalogId = lt.catalogId
WHERE lt.workoutId = ?
ORDER BY lt.position ASC;
3.2 Custom path
The editor builds week-1 workout_instances and lift_instances (these are the “live template”).

Weeks 2–4 are cloned from week-1.

When you edit a custom workout, changes overwrite all instances of that workout in the block (see §5).

4) Scoring Model (summary)
All scoring reads only instance-frozen fields and logging.
Unilateral rule: duplicates all aggregates for the lift.

Let:

rawReps = SUM(reps)

rawWorkload = SUM(reps * weight)

rawWeightUsed = SUM(weight)

If logUnilaterally = 1 then:

totalReps = 2 * rawReps

totalWorkload = 2 * rawWorkload

totalWeightUsed = 2 * rawWeightUsed

Score calculation:

If scoreType = BODYWEIGHT: see docs/scoring.md.

If scoreType = MULTIPLIER:
score = totalWeightUsed * totalReps * baseMultiplier.

Totals persist to:

lift_totals (liftReps, liftWorkload, liftScore)

workout_totals rolls up lift_totals (sum workload, average score)

block_totals rolls up workout_totals (sum workload, average score)

5) Custom Edit Propagation (no week-by-week drift)
When saving a custom workout edit (order, sets/reps, scoreType, logUnilaterally, instructions):

Treat week-1 instances as the source of truth.

For every other workout_instance of that customWorkoutId in the same blockInstance:

Update matching lift_instances fields (match by catalogId when present, else liftName).

Insert missing lifts cloned from week-1.

Archive or delete lifts removed from week-1 (delete only if no entries exist).

Recompute lift_totals only for affected liftInstanceIds; workout_totals and block_totals roll up accordingly.

Add lift_instances.archived (INTEGER DEFAULT 0) so you can hide historical rows without losing entries.

6) Slot Indexing & Scheduling
slotIndex = weekIndex * weeklySlots + dayIndex.

Stock: base lineup from workouts_blocks.position.

Custom: base lineup from custom_workouts.position.

Scheduler fans the lineup across weeks to produce all workout_instances.

7) Indexing (hot paths)
lift_catalog(liftName)

lift_templates(workoutId, position)

lift_instances(workoutInstanceId, position)

lift_entries(liftInstanceId)

workout_instances(blockInstanceId, slotIndex)

All CREATE INDEX should be IF NOT EXISTS.

8) Admin/God Mode
- Purpose: allow post-launch edits to stock blocks/lifts without breaking user data.
- Scope: admins only; normal users cannot alter stock templates.
- Rules:
  • Templates are normally frozen into instances; history does not change.  
  • Admin overrides (multiplier, reps, lift name, instructions) trigger a reconciliation:  
      - Update matching fields in all lift_instances.  
      - Cascade name changes into workout_instances/block_instances if needed.  
      - Recompute lift_totals → workout_totals → block_totals.  
  • If entries already exist: archive rows instead of delete.  
  • Always idempotent: applying the same admin patch twice yields the same state.  
- Logging: record admin edits in a meta table (admin_edits) for audit/debugging.


Recomputes impacted totals,

Archives instead of deleting when entries exist.
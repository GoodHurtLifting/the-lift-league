custom_block_builder.md

Source of truth: docs/db.md (this file follows those contracts).
Scope: UI + DB rules for creating/editing custom blocks. Stock templates are separate (lift_templates in db.md).

1) Model contracts (UI)

CustomBlock { id, name, numWeeks, daysPerWeek, isDraft, scheduleType='standard', coverImagePath?, workouts: List<WorkoutDraft> }

WorkoutDraft { id, dayIndex, name, lifts: List<LiftDraft>, isPersisted }

LiftDraft { id?, name, sets, repsPerSet, multiplier, isBodyweight, isDumbbellLift, position }

UI fields map to instance fields:
multiplier → baseMultiplier (NULL for bodyweight),
isDumbbellLift → logUnilaterally (0/1),
isBodyweight → scoreType=1 else 0.

2) Tables in play

Stock (reference only): lift_templates(workoutId, catalogId, position, sets, repsPerSet, baseMultiplier, scoreType, logUnilaterally, instructions)

Custom (builder’s template tables today): custom_blocks, custom_workouts, custom_lifts

Add (or use if present): custom_lifts.baseMultiplier REAL, custom_lifts.logUnilaterally INTEGER DEFAULT 0.

Instances (target): block_instances, workout_instances, lift_instances(liftName, sets, repsPerSet, baseMultiplier, scoreType, logUnilaterally, position, archived).

3) Builder flow (current, template-first)

Save/Update block: rewrite all workouts/lifts for that block (transaction).

Workouts: order by dayIndex → dense position 0..N−1.

Lifts: keep incoming position; must be dense 0..M−1.

Score fields:

Bodyweight: scoreType=1, baseMultiplier=NULL, logUnilaterally from isDumbbellLift (usually 0).

Multiplier: scoreType=0, baseMultiplier = multiplier, logUnilaterally = isDumbbellLift ? 1 : 0.

4) Materialization (target, instance-first)

Week-1 lift_instances are the live template (mirror lift_templates fields).

Weeks 2–4 clone from week-1.

On edit: overwrite all weeks from week-1; archive removed lifts if entries exist.

5) Validation

Unique dayIndex within a block.

Non-empty lift.name; sets ≥ 0, repsPerSet ≥ 0.

scoreType ∈ {0,1}. If scoreType=1, baseMultiplier MUST be NULL.

position dense per list (workouts and lifts).

6) Catalog usage

Prefer picking from lift_catalog; store liftCatalogId + name.

Free text allowed; set liftCatalogId=NULL.

7) Scheduling

scheduleType is label only (no runtime branching).

Instances fan out via slotIndex = weekIndex*weeklySlots + dayIndex.

8) Review checklist

Save rewrites workouts/lifts exactly as UI shows.

scoreType/baseMultiplier/logUnilaterally normalized per §4.

Positions are dense from 0; dayIndex unique.

Catalog lookups fill name if liftCatalogId given.

Transactions wrap delete-and-replace.

Surgical diffs to align code with db.md (non-breaking)
1) Add missing columns to custom_lifts (compat layer)

File / Anchor / Action / Snippet / Notes

File: lib/services/db_service.dart

Anchor: onUpgrade (add a new block; bump _dbVersion to 28)

Action: Add columns if missing.

Snippet:

if (oldV < 28) {
try { await db.execute("ALTER TABLE custom_lifts ADD COLUMN baseMultiplier REAL;"); } catch (_) {}
try { await db.execute("ALTER TABLE custom_lifts ADD COLUMN logUnilaterally INTEGER DEFAULT 0;"); } catch (_) {}
}


Notes: Keep legacy columns (scoreMultiplier, isDumbbell) for now.

2) Normalize writes in upsertCustomBlock (write both new + legacy)

File: lib/services/db_service.dart

Anchor: inside upsertCustomBlock → inner loop inserting into custom_lifts

Action: Compute normalized fields; write both sets.

Snippet (replace the map body only):

final isBw = l.isBodyweight;
final scoreTypeInt = isBw ? SCORE_TYPE_BODYWEIGHT : SCORE_TYPE_MULTIPLIER;
final int logUni = l.isDumbbellLift ? 1 : 0;
final double? baseMul = isBw ? null : l.multiplier;

await txn.insert('custom_lifts', {
'customWorkoutId': wid,
'liftCatalogId': null,           // keep if you have one; else null
'name': l.name,
'repSchemeText': null,           // keep if you use it; else null
'sets': l.sets,
'repsPerSet': l.repsPerSet,
'scoreType': scoreTypeInt,
'baseMultiplier': baseMul,       // NEW (db.md aligned)
'logUnilaterally': logUni,       // NEW (db.md aligned)

// Legacy writes (keep during transition)
'scoreMultiplier': baseMul,      // legacy mirror
'isBodyweight': isBw ? 1 : 0,
'isDumbbell': logUni,            // legacy mirror of logUnilaterally

'position': l.position,
});


Notes: Safe mirror so both old and new readers keep working.

3) Normalize addLiftToCustomWorkout (accept optional multiplier; write both)

File: lib/services/db_service.dart

Anchor: method signature

Action: add double? multiplier.

Snippet (signature only):

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
double? multiplier, // NEW
}) async {


File: same method, before txn.insert('custom_lifts', ...)

Action: compute normalized fields.

Snippet:

final bool isBw = isBodyweight == 1 || scoreType.toLowerCase() == 'bodyweight';
final int scoreTypeInt = isBw ? SCORE_TYPE_BODYWEIGHT : SCORE_TYPE_MULTIPLIER;
final int logUni = isDumbbell;
final double? baseMul = isBw ? null : multiplier;


File: same method, map passed to insert

Action: write both new + legacy fields.

Snippet (changed lines only):

'scoreType': scoreTypeInt,
'baseMultiplier': baseMul,     // NEW
'logUnilaterally': logUni,     // NEW
'scoreMultiplier': baseMul,    // legacy mirror
'isBodyweight': isBw ? 1 : 0,
'isDumbbell': logUni,

4) Read path fallback in loadCustomBlockForEdit

File: lib/services/db_service.dart

Anchor: inside loadCustomBlockForEdit, template path (blockInstanceId == null) when building LiftDraft

Action: prefer new columns; fallback to legacy.

Snippet (replace the affected initializers):

multiplier: (l['baseMultiplier'] as num?)?.toDouble()
?? (l['scoreMultiplier'] as num?)?.toDouble()
?? 0.0,
isDumbbellLift: ((l['logUnilaterally'] as int?) ?? (l['isDumbbell'] as int?) ?? 0) == 1,

5) Instances (when you switch)

When you move the builder to write week-1 lift_instances directly, persist only:

liftName, sets, repsPerSet, baseMultiplier, scoreType, logUnilaterally, position, archived=0.
Then clone weeks 2–4. You can remove the custom_lifts mirror writes.

6)
**TODO:** What you can remove later

Legacy columns usage in code: custom_lifts.scoreMultiplier, custom_lifts.isDumbbell.

The compatibility reads in loadCustomBlockForEdit.

Ultimately custom_lifts entirely, once instance-first editing is complete.
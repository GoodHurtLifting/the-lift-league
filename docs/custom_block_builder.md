custom_block_builder.md

Source of truth: docs/db.md
Scope: UI + DB rules for creating/editing custom blocks. Stock templates are separate (lift_templates in db.md).

1) UI model contracts

CustomBlock { id, name, numWeeks, daysPerWeek, isDraft, scheduleType='standard', coverImagePath?, workouts: List<WorkoutDraft> }

WorkoutDraft { id, dayIndex, name, lifts: List<LiftDraft>, isPersisted }

LiftDraft { id?, name, sets, repsPerSet, multiplier, isBodyweight, isDumbbellLift, position }

Normalization (UI → DB fields)

isBodyweight == true → scoreType = 1 (BODYWEIGHT), baseMultiplier = NULL

else → scoreType = 0 (MULTIPLIER), baseMultiplier = multiplier

isDumbbellLift → logUnilaterally = 1 (else 0)

Constants (db.md-compatible)
SCORE_TYPE_MULTIPLIER = 0
SCORE_TYPE_BODYWEIGHT = 1

2) Table usage (builder path today)

custom_blocks(customBlockId, name, totalWeeks, workoutsPerWeek, …, scheduleType, coverImagePath, isDraft)

custom_workouts(id, customBlockId, name, position)

custom_lifts(id, customWorkoutId, liftCatalogId?, name, repSchemeText?, sets, repsPerSet, scoreType, baseMultiplier, logUnilaterally, position)
(legacy mirrors may still exist: scoreMultiplier, isDumbbell — safe to ignore in new code)

Block field mappings (UI → DB)

numWeeks → custom_blocks.totalWeeks

daysPerWeek → custom_blocks.workoutsPerWeek

workouts.length → custom_blocks.uniqueWorkoutCount

name → custom_blocks.name

scheduleType is label only (no runtime branching)

Workout & Lift mappings

Workout order: sort by dayIndex → write position = 0..N-1

Lift order: preserve incoming position = 0..M-1

multiplier → baseMultiplier

isDumbbellLift → logUnilaterally

isBodyweight → scoreType (1 for bodyweight, else 0)

3) Builder flow

Save/Update block (transaction):

Upsert custom_blocks

Delete existing custom_workouts + custom_lifts for the block

Reinsert workouts and lifts with normalized scoring fields

Load for edit:

Template mode (blockInstanceId == null): read custom_workouts + custom_lifts

LiftDraft.id = custom_lifts.id

Instance mode (blockInstanceId != null): read workout_instances + lift_instances (archived=0)

LiftDraft.id = lift_instances.liftInstanceId

4) Validation

Unique dayIndex within the block

Positions dense from 0 (for both workouts and lifts)

Lift: non-empty name, sets ≥ 0, repsPerSet ≥ 0

If scoreType = 1, baseMultiplier MUST be NULL

5) Catalog usage

Prefer selecting from lift_catalog: store liftCatalogId and resolved name

Free text allowed; set liftCatalogId = NULL

6) Scheduling (reference)

scheduleType is a label only

Instance fan-out uses: slotIndex = weekIndex * daysPerWeek + dayIndex

7) Review checklist

Save rewrites exactly what the UI shows

scoreType/baseMultiplier/logUnilaterally normalized on write

Dense positions; unique dayIndex

Catalog lookups fill name when liftCatalogId provided

All writes inside a single transaction

8) Implementation anchors (where code lives)

Persist: DBService.upsertCustomBlock(CustomBlock block)

Load (template/instance): DBService.loadCustomBlockForEdit({ customBlockId, blockInstanceId? })

Add lift quickly: DBService.addLiftToCustomWorkout({... , double? multiplier})

List/delete blocks: DBService.getCustomBlocks(), DBService.deleteCustomBlock(int id)

9) Future (instance-first authoring)

Week-1 lift_instances act as the live template; clone weeks 2–4

Edits overwrite other weeks from week-1; archive removed lifts if entries exist

When fully migrated, custom_lifts can be retired
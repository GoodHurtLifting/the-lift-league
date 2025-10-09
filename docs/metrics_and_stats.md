metrics_and_stats.md

Scope: Contracts for computing and exposing metrics at lift, workout, block, user, momentum, and leaderboard levels.
Out of scope: Badge rules/assets → badges.md. Per-lift math/estimators → scoring.md.

0) Conventions

Units: lbs.

Time storage:
SQLite: UTC ISO-8601 TEXT (e.g., 2025-03-10T14:03:00Z) for startTime, endTime, startDate, endDate, scheduledDate.

Firestore: Timestamp preferred; ISO string allowed (reader must accept both).

Read sources: instance-frozen fields (*_instances) + logs (lift_entries) + totals tables. Templates are not read after materialization.

1) Authoritative tables (columns used by metrics)

lift_entries: (liftEntryId, liftInstanceId, setIndex, reps, weight, createdAt)

lift_instances: (liftInstanceId, workoutInstanceId, scoreType, baseMultiplier, logUnilaterally, sets, repsPerSet, archived)

workout_instances: (workoutInstanceId, blockInstanceId, sourceWorkoutId, sourceCustomWorkoutId, workoutName, startTime, endTime, completed)

lift_totals: (liftInstanceId [PK], workoutInstanceId, liftReps, liftWorkload, liftScore)

workout_totals: (workoutInstanceId [PK], blockInstanceId, workoutWorkload, workoutScore)

block_totals: (blockInstanceId [PK], userId, blockWorkload, blockScore)

(Firestore) users/{uid} user profile (e.g., displayName, title, totalLbsLifted, optional momentum)

(Firestore) users/{uid}/timeline_entries/{doc}: {type, timestamp, clink?, imagePath?, reactions?}

2) Core definitions

Workout completion: set completed=1; write endTime when the last actionable set is logged.

Block completion: write block_instances.endDate when the final workout completes; startDate = first workout startTime.

Training day: unique calendar dates where any workout transitions to completed=1.

Block calendar days: Compute using completed workouts: (MAX(endTime) − MIN(startTime)) + 1, parsing ISO-8601 strings.

3) Per-lift metrics → lift_totals

Inputs per liftInstanceId:

From lift_entries:
rawReps = Σ(reps), rawWorkload = Σ(reps×weight), rawWeightUsed = Σ(weight)

From lift_instances: logUnilaterally (0/1), scoreType (0=MULTIPLIER, 1=BODYWEIGHT), baseMultiplier

Unilateral rule:

If logUnilaterally=1: totalReps = 2×rawReps, totalWorkload = 2×rawWorkload, totalWeightUsed = 2×rawWeightUsed; else totals = raws.

Scoring (see scoring.md §Rules):

MULTIPLIER: liftScore = totalWeightUsed * totalReps * baseMultiplier

BODYWEIGHT: liftScore = totalReps + 0.5 * totalWeightUsed

Round liftScore to 1 decimal.
Persist: lift_totals(liftReps, liftWorkload, liftScore).

4) Per-workout metrics → workout_totals

From non-archived lifts in the workout:

workoutWorkload = Σ(lift_totals.liftWorkload)
workoutScore    = AVG(lift_totals.liftScore) with denominator = planned lift count


Planned = count of lift_instances WHERE workoutInstanceId=? AND archived=0. Missing/unfilled lifts count as 0 in the average.
Persist: workout_totals(workoutInstanceId, blockInstanceId, workoutWorkload, workoutScore).

5) Per-block metrics → block_totals
   blockWorkload = Σ(workout_totals.workoutWorkload)
   blockScore    = SUM( MAX(workoutScore) per distinct workout identity )


Distinct identity: sourceWorkoutId (stock) or sourceCustomWorkoutId (custom); fallback = normalized workoutName.
Texas Method exception: exclude Recovery (Wed); sum best Mon-A, Mon-B, Fri-A, Fri-B.
Persist: block_totals(blockInstanceId, userId, blockWorkload, blockScore).

6) Recompute cascade (invariant)

lift_entries change → recompute that lift_totals → recompute parent workout_totals → recompute parent block_totals.

7) User-visible metrics (read-side)
   7.1 Dashboard
   Field	Source
   displayName, title	Firestore users/{uid}
   totalLbsLifted	Σ(workout_totals.workoutWorkload) (optionally mirrored to Firestore)
   totalBlocksCompleted	COUNT(DISTINCT blockInstanceId) where endDate IS NOT NULL
   momentumPercent	MomentumService.momentumPercent (see §8)
   7.2 Block Summary
   Metric	Source
   Block Name	block_instances.blockName
   Block Workload	block_totals.blockWorkload
   Block Score	block_totals.blockScore
   Workouts Completed	COUNT(*) FROM workout_instances WHERE completed=1
   Days Taken	`(MAX(endTime) − MIN(startTime)) + 1` over completed workouts (ISO-8601 UTC)
   Big-3 PRs (display)	Parse timeline clink with `New (Bench Press
   7.3 Timeline / Check-ins
   Metric	Source
   Check-ins count	COUNT(timeline_entries WHERE type='checkin')
   Reactions given/received	timeline reactions aggregation
   Before & After	first vs most recent imagePath
   Current Block Tag	block_instances.blockName (Run N)

8) Momentum Meter (contract)

Service: MomentumService.momentumPercent
UI: MomentumMeter polls the service ~every 2s and renders a color-coded linear progress bar with a textual %.

Computation window: last 24 days relative to “now”.

Inputs from workout_instances:

Set of distinct workout days (dates) with completed=1 within the 24-day window.

daysSinceLastCompletion = whole days since the most recent completed workout (0 if today).

Scoring model (abstracted constants; implementation-defined):

Let boostPerActiveDay = constant ≥ 0.

Let decayPerIdleDay = constant ≥ 0.

Base activity score: A = boostPerActiveDay * distinctActiveDaysInWindow.

Recent-activity decay: D = decayPerIdleDay * daysSinceLastCompletion.

Raw momentum: M_raw = A − D.

Clamp and scale to percent: momentumPercent = clamp01(M_raw / MAX_SCORE) * 100, where MAX_SCORE normalizes to 100% for “ideal” activity over 24 days.

Clamp: [0, 100].

Storage/refresh: value is computed on demand; may be mirrored to Firestore (optional). UI reads the service; no direct DB writes required by this spec.

9) Leaderboards (inputs)

Ranking value: best block_totals.blockScore per (userId, blockId); reruns never lower standing.

Display: handle + title + blockName, and the constituent best workout scores.

10) Cross-references

Per-lift math, unilateral duplication, custom estimator: scoring.md.

Badge triggers & award persistence: badges.md.
# scoring.md

## Rules
1. Scoring reads only **instance-frozen** fields (`lift_instances`) and runtime logs (`lift_entries`). Templates do not affect scoring once materialized.
2. Unilateral logging doubles all aggregates for that lift: if `logUnilaterally=1`, multiply reps/workload/weightUsed by 2.
3. Two lift formulas:
    - **MULTIPLIER:** `liftScore = totalWeightUsed * totalReps * baseMultiplier`
    - **BODYWEIGHT:** `liftScore = totalReps + 0.5 * totalWeightUsed`
4. Persist:
    - `lift_totals(liftReps, liftWorkload, liftScore)` with `liftScore` rounded to 1 decimal.
    - `workout_totals(workoutWorkload, workoutScore)`
    - `block_totals(blockWorkload, blockScore)`

## Stock vs Custom
- **Stock lifts:** `scoreType` and `baseMultiplier` are **seeded and fixed** (unless admin override).
- **Custom lifts:** `scoreType` chosen by user; `baseMultiplier` is **estimated once** after the first session in the block (see below).

### Custom — Final-Week Targeting (estimator)
When: after the first completed session for that lift in a custom block (week=1).  
Skip if `scoreType=BODYWEIGHT`.

Inputs (from week-1 + block info):
- `sets`, `repsPerSet`, `logUnilaterally` → `U = (logUnilaterally ? 2 : 1)`
- `W1` = observed average working weight per set (week-1)
- `S = sets * repsPerSet * U`  (effective total reps)
- `N` = block length in weeks (custom blocks: 2–6; stock always 4)
- `Δ` = expected weekly weight increase (lbs): **10** for compound barbell, **5** for accessories/DB (fallbacks)

Projection:
- Final-week weight per set: `WN = W1 + (N - 1) * Δ`
- Final-week sum of weights: `WsumN = sets * WN * U`
- Target final score center: `TN = 100`

Compute:
- `baseMultiplier = TN / (WsumN * S)`

Persist the `baseMultiplier` to all week instances of that lift (this block instance) and recompute totals. Idempotent by design. Admin override allowed.

## Lift
From `lift_entries` for a `liftInstanceId`:
- `rawReps = SUM(reps)`
- `rawWorkload = SUM(reps * weight)`
- `rawWeightUsed = SUM(weight)`

Apply unilateral:
- If `logUnilaterally=1`, double the above three values; else keep raw.

Compute `liftScore` via the formula for the `scoreType` (see Rules §3).  
Write to `lift_totals`.

## Workout
From `lift_totals` for a `workoutInstanceId`:
- `workoutWorkload = SUM(liftWorkload)`
- `workoutScore = AVG(liftScore)` **including zeros for unfilled lifts**

Write to `workout_totals`.

## Block
From `workout_totals` for a `blockInstanceId`:
- `blockWorkload = SUM(workoutWorkload)` → write to `block_totals`
- `blockScore` = **distinct-best sum**:
    1) Group workouts by identity:
        - Stock: `sourceWorkoutId`
        - Custom: `sourceCustomWorkoutId`
        - Fallback: normalized `workoutName`
    2) Take `MAX(workoutScore)` per group
    3) `blockScore = SUM(maxPerGroup)` → write to `block_totals`

**Texas Method exception:** label-only rule—exclude all Wednesday (Recovery) workouts; there are two distinct Mondays and two distinct Fridays across 4 weeks.  
`blockScore = best(Mon-A) + best(Mon-B) + best(Fri-A) + best(Fri-B)`.

## Leaderboard (summary)
- Rank by **best `block_totals.blockScore`** per user per block. Reruns never lower standing.
- Show the constituent best workout scores that formed the block score.

## Invariants
- Scoring never reads templates after instance creation.
- Multipliers/bodyweight flags are taken from `lift_instances`.
- Recomputations cascade: `lift_totals → workout_totals → block_totals`.
- Admin edits use reconciliation (update instances, recompute totals, archive instead of delete when entries exist).

## Notes
- “Recommended weight” UI is not used in scoring.

# badges.md

## Rules
1. Badges are awarded from computed events; awards are **idempotent** (same event won’t award twice).
2. Retroactive runs are allowed (recompute history); keep awards stable.
3. Some badges are **repeatable/tiered** (e.g., per 100k lbs); others are **one-time**.
4. Record awards to `badge_awards(userId, badgeId, awardedAt, metadata)` (or Firestore equivalent).
5. Display surfaces: post-workout **badge carousel**, **block summary** grid, **stats** page.

## Triggers (when to evaluate)
- **On set save:** lightweight checks (rare).
- **On workout finish:** time-of-day / workout completeness / PR bundles.
- **On block finish:** block-wide completion badges.
- **Weekly job:** streaks, Training Circle group badges, rolling windows.
- **On totals update:** lifetime workload tiers.

## Data sources
- `lift_totals`, `workout_totals`, `block_totals`
- `workout_instances(startTime,endTime,completed)`, `block_instances`
- Big-3 PRs (Bench, **Squats**, Deadlift)
- `trainingDays` (unique days with a finished workout)
- Timezone: user’s local time

## Definitions
- **trainingDays:** unique days with a finished workout.
- **Perfect Month (circle):** all 10 members complete **all 12 workouts** of a block within a single calendar month.
- **PR:** best weight entered in single set across all existing sets per lift instance.

## Badge catalog

### Lunch Lady (Personal Record milestones)
- **Trigger (workout finish):** Any weight increase:
    - **Bench Press:** 
    - **Squats:** 
    - **Deadlift:** 
- **Source:** per-set max weight in workout; lifts mapped to Big-3.
- **Notes:** 

### Meat Wagon (lifetime workload tiers)
- **Trigger (totals update):** `floor(totalLbsLifted / 100000)` increases.
- **Source:** user lifetime workload counter (Firestore) or rollup of `workout_totals.workoutWorkload`.
- **Notes:** no limit to number of times awarded per user

### The Punch Card (8-week consistency)
- **Scope:** Individual, repeatable with cooldown (see below).
- **Trigger (weekly job):** **8 consecutive weeks** with **≥3 finished workouts/week**.
- **Week Definition:** Monday 12AM TO Sunday 11:59PM.
- **Cooldown:** Counter resets immediately after award; next streak starts the following week.

### Daily Driver
- **When:** On workout finish and monthly job.
- **Logic:** If finished-this-month count hits **9** (calendar month), award.
- **Notes:** Multiple awards possible across months.

### Hype Man
- **When:** On like.
- **Logic:** When the user **likes** a **training-circle member’s** check-in, increment a counter; award every **10 likes given** (10, 20, 30, …).
- **Notes:** Count **unique** likes per post per user (no double-taps). Likes are not user unique.

### Checkin Head
- **When:** On check-in posted.
- **Logic:** Award user every **5 check-ins** created by the user (5, 10, 15, …).
- **Notes:** Exclude deleted check-ins from the counter.
- **Notes:** no limit to number of times awarded per user

## Invariants
- All badge evaluations are **pure**: same inputs ⇒ same awards.
- Use **UTC** for storage; render in user’s timezone for time-based rules.
- Group awards grant to **each member** meeting eligibility at the time of award.
- Image assets are configurable; IDs stable even if images move to Firestore.

## Implementation notes
- Keep badge rule thresholds in a config map (not hardcoded in multiple places) - lib/services/badge.services.dart
- Use a single `awardBadge(userId, badgeId, metadata)` that:
    - checks existence (idempotent),
    - writes the award,
    - enqueues UI toast/carousel if in-session.
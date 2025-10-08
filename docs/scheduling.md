# scheduling.md

## Rules
1. Stock blocks run **4 weeks**.
2. Custom blocks run **2–6 weeks** (user-selected).
3. Scheduler uses only: `numWeeks`, `numWorkouts`, `workoutsPerWeek`, `position` (0-based).
4. `scheduleType` is a seed label; **ignore at runtime**.
5. `weeklySlots = workoutsPerWeek`.
6. `slotIndex = (weekIndex * weeklySlots) + dayIndex` (0-based).
7. Materialize `workout_instances` for `numWeeks * weeklySlots`; then copy lifts into `lift_instances` from the template
    - Stock: `lift_templates`
    - Custom: week-1 definition (the “live template” cloned to later weeks)
8. Within each week, order workouts by `position` ascending.

## Mapping
- **2 workouts, 3 slots/week:**  
  Week 1: A / B / A  
  Week 2: B / A / B  
  Repeat pattern across all weeks.
- **3+ workouts:** cycle by `position` to fill each week’s slots.
- **Texas Method (label only):** 6 workouts but **3 slots/week** (Mon/Wed/Fri).
- **PPL Plus (label only):** 3 workouts, **21 slots** over 4 weeks (3-on-1-off).

## Invariants
- `slotIndex` never changes once created.
- Reordering historical instances is forbidden.
- Editing custom **week-1** updates mirrored weeks; `slotIndex` values remain.
- Missed/skipped sessions do not shift later `slotIndex` values.

## Edge Cases
- If `numWorkouts > workoutsPerWeek`: continue cycling into the next week.
- If `workoutsPerWeek > numWorkouts`: repeat the cycle to fill weekly slots.

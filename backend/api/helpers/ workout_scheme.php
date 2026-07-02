<?php
/**
 * workout_scheme.php — shared rep/set periodization logic
 * Used by both generate.php (new routines) and continue.php
 * (recalculating existing exercises for the new week's phase).
 */

// Detect isometric/time-based moves (planks, holds) or Cardio exercises
function isTimeBased(array $ex): bool {
    if (($ex['muscle_group'] ?? '') === 'Cardio') return true;
    foreach (['Plank', 'Hold', 'Wall Sit', 'Dead Hang', 'L-Sit'] as $kw) {
        if (stripos($ex['name'] ?? '', $kw) !== false) return true;
    }
    return false;
}

/**
 * Build a realistic sets/reps scheme for ONE exercise based on its type + phase.
 *
 * 4-week mesocycle:
 *   Phase 1 → Hypertrophy: baseline reps/sets
 *   Phase 2 → Volume:      +1 set, standard reps
 *   Phase 3 → Intensity:   heavier (fewer reps), same sets
 *   Phase 4 → Deload:      -1 set, lighter, easier recovery
 *
 * @return array [int $sets, string $repsCsv]
 */
function buildScheme(bool $isCompound, bool $isTimeBased, int $baseSets, int $baseReps, int $phase): array
{
    if ($isTimeBased) {
        $seconds = 20;
        $sets    = $baseSets;
        if ($phase === 2) $seconds += 5;
        if ($phase === 3) $seconds += 10;
        if ($phase === 4) { $seconds = 15; $sets = max(2, $sets - 1); }
        return [$sets, implode(',', array_fill(0, $sets, $seconds . 's'))];
    }

    if ($isCompound) {
        $sets = $baseSets;
        $topReps = $baseReps + (($sets - 1) * 2);

        if ($phase === 2) $sets += 1;
        if ($phase === 3) $topReps = max(4, $topReps - 4);
        if ($phase === 4) { $sets = max(2, $sets - 1); $topReps = $baseReps; }

        $repsArr = [];
        $r = $topReps;
        for ($i = 0; $i < $sets; $i++) {
            $repsArr[] = max(4, $r);
            $r -= 2;
        }
        return [$sets, implode(',', $repsArr)];
    }

    // Isolation
    $sets = $baseSets;
    $reps = $baseReps;
    if ($phase === 2) $reps += 2;
    if ($phase === 3) $reps = max(6, $reps - 2);
    if ($phase === 4) { $sets = max(2, $sets - 1); $reps = $baseReps; }

    return [$sets, implode(',', array_fill(0, $sets, $reps))];
}

// Base sets/reps per goal (before periodization adjustment).
// NOTE: exercise COUNT is no longer decided by goal — see
// exerciseCountForGroups() below, which decides based on how many
// muscle groups a day targets (single vs double split).
function goalBaseConfig(string $goal): array
{
    $config = [
        'build_muscle' => ['sets' => 4, 'reps' => 8],
        'lose_fat'     => ['sets' => 3, 'reps' => 15],
        'maintain'     => ['sets' => 3, 'reps' => 12],
    ];
    return $config[$goal] ?? $config['build_muscle'];
}

// Which 4-week mesocycle phase a given week number falls into (1-4)
function weekPhase(int $weekNumber): int
{
    $phase = $weekNumber % 4;
    return $phase === 0 ? 4 : $phase;
}

// FIX: exercise count is now driven by how many muscle groups a day
// targets, not by fitness goal:
//   1 muscle group  (e.g. "Chest")          → 6 exercises
//   2 muscle groups (e.g. "Chest+Triceps")  → 8 exercises, split evenly
function exerciseCountForGroups(int $numGroups): int
{
    return $numGroups >= 2 ? 8 : 6;
}

/**
 * Fetch exercises for a single muscle group with a 3-tier fallback chain:
 *  Tier 1 — full filters (equipment + difficulty)
 *  Tier 2 — drop equipment filter (small home exercise pool)
 *  Tier 3 — drop difficulty too (guarantees exercises exist)
 *
 * $excludeIds prevents picking the same exercise twice across groups/top-up.
 */
function fetchGroupExercises(
    PDO $pdo, string $group, string $difficulty,
    string $equipmentFilter, string $equipmentOrder,
    string $goalOrder, string $typeOrder,
    int $seed, int $limit, array $excludeIds = []
): array {
    if ($limit <= 0) return [];

    $excludeSql = '';
    if (!empty($excludeIds)) {
        $idPh = implode(',', array_fill(0, count($excludeIds), '?'));
        $excludeSql = "AND e.id NOT IN ($idPh)";
    }

    // ── Tier 1: full filters ────────────────────────────────────────────────
    $sql = "SELECT * FROM exercises e
            WHERE e.muscle_group = ? AND e.difficulty = ?
                  $equipmentFilter $excludeSql
            ORDER BY $typeOrder $goalOrder $equipmentOrder (e.id + ?) % 7, RAND()
            LIMIT $limit";
    $stmt = $pdo->prepare($sql);
    $stmt->execute(array_merge([$group, $difficulty], $excludeIds, [$seed]));
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (count($rows) >= $limit) return $rows;

    // ── Tier 2: drop equipment filter ───────────────────────────────────────
    $gotIds = array_merge($excludeIds, array_column($rows, 'id'));
    $excludeSql2 = '';
    if (!empty($gotIds)) {
        $idPh = implode(',', array_fill(0, count($gotIds), '?'));
        $excludeSql2 = "AND e.id NOT IN ($idPh)";
    }
    $sql2 = "SELECT * FROM exercises e
             WHERE e.muscle_group = ? AND e.difficulty = ? $excludeSql2
             ORDER BY $typeOrder $goalOrder $equipmentOrder (e.id + ?) % 7, RAND()
             LIMIT " . ($limit - count($rows));
    $stmt2 = $pdo->prepare($sql2);
    $stmt2->execute(array_merge([$group, $difficulty], $gotIds, [$seed]));
    $rows = array_merge($rows, $stmt2->fetchAll(PDO::FETCH_ASSOC));
    if (count($rows) >= $limit) return $rows;

    // ── Tier 3: drop difficulty too ─────────────────────────────────────────
    $gotIds = array_merge($excludeIds, array_column($rows, 'id'));
    $excludeSql3 = '';
    if (!empty($gotIds)) {
        $idPh = implode(',', array_fill(0, count($gotIds), '?'));
        $excludeSql3 = "AND e.id NOT IN ($idPh)";
    }
    $sql3 = "SELECT * FROM exercises e
             WHERE e.muscle_group = ? $equipmentFilter $excludeSql3
             ORDER BY $typeOrder $goalOrder $equipmentOrder RAND()
             LIMIT " . ($limit - count($rows));
    $stmt3 = $pdo->prepare($sql3);
    $stmt3->execute(array_merge([$group], $gotIds));
    $rows = array_merge($rows, $stmt3->fetchAll(PDO::FETCH_ASSOC));

    return $rows;
}

/**
 * Fetch a balanced set of exercises across 1-2 muscle groups.
 *   1 group  → all $totalLimit exercises from that group
 *   2 groups → split evenly (e.g. 8 → 4+4), each group independently
 *              runs the fallback chain so a small pool in one group
 *              doesn't starve the other.
 * If the combined result still falls short of $totalLimit (very small
 * exercise pool), tops up from either group, excluding duplicates.
 */
function fetchBalancedExercises(
    PDO $pdo, array $groups, string $difficulty,
    string $equipmentFilter, string $equipmentOrder,
    string $goalOrder, string $typeOrder,
    int $seed, int $totalLimit
): array {
    $numGroups = count($groups);
    $base      = intdiv($totalLimit, $numGroups);
    $remainder = $totalLimit % $numGroups;

    $result  = [];
    $usedIds = [];

    foreach ($groups as $i => $group) {
        // Distribute any remainder to the first group(s) so totals add up exactly
        $limitForGroup = $base + ($i < $remainder ? 1 : 0);
        $rows = fetchGroupExercises(
            $pdo, $group, $difficulty, $equipmentFilter, $equipmentOrder,
            $goalOrder, $typeOrder, $seed, $limitForGroup, $usedIds
        );
        foreach ($rows as $r) {
            $result[]  = $r;
            $usedIds[] = $r['id'];
        }
    }

    // Top-up if the combined pool still came up short overall
    if (count($result) < $totalLimit) {
        $needed       = $totalLimit - count($result);
        $placeholders = implode(',', array_fill(0, $numGroups, '?'));
        $excludeSql   = '';
        $params       = $groups;
        if (!empty($usedIds)) {
            $idPh = implode(',', array_fill(0, count($usedIds), '?'));
            $excludeSql = "AND e.id NOT IN ($idPh)";
            $params = array_merge($params, $usedIds);
        }
        $sql = "SELECT * FROM exercises e
                WHERE e.muscle_group IN ($placeholders) $excludeSql
                ORDER BY $typeOrder $goalOrder $equipmentOrder RAND()
                LIMIT $needed";
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $result = array_merge($result, $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    return $result;
}
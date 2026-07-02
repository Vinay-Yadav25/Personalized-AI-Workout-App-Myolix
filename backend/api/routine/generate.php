<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
require_once __DIR__ . '/../helpers/workout_scheme.php';

if (!isset($uid)) {
    $uid = require_auth();
}

// ── Load Profile ──────────────────────────────────────────────────────────────
$p = $pdo->prepare("SELECT * FROM user_profiles WHERE user_id = ?");
$p->execute([$uid]);
$profile = $p->fetch(PDO::FETCH_ASSOC);

if (!$profile) {
    http_response_code(400);
    echo json_encode(["error" => "Set profile first"]);
    exit;
}

$goal     = $profile['goal']             ?? 'build_muscle';
$split    = $profile['split_type']       ?? 'single';
$location = $profile['workout_location'] ?? 'gym';
$exp      = $profile['experience']       ?? 'beginner';

// ── 1. Goal + Split → 6 workout days (Mon–Sat) ───────────────────────────────
$splitConfig = [
    'build_muscle' => [
        'single' => ["Chest","Back","Legs","Shoulders","Arms","Core"],
        'double' => ["Chest+Triceps","Back+Biceps","Legs+Core",
                     "Shoulders+Arms","Full Body","Cardio+Core"],
    ],
    'lose_fat' => [
        'single' => ["Cardio+Core","Chest","Cardio+Core",
                     "Back","Legs","Shoulders+Arms"],
        'double' => ["Cardio+Core","Chest+Triceps","Cardio+Core",
                     "Back+Biceps","Legs+Core","Cardio+Core"],
    ],
    'maintain' => [
        'single' => ["Chest","Back","Legs","Shoulders","Arms","Cardio+Core"],
        'double' => ["Chest+Triceps","Back+Biceps","Legs+Core",
                     "Shoulders+Arms","Cardio+Core","Full Body"],
    ],
];

$workoutDays = $splitConfig[$goal][$split] ?? $splitConfig['build_muscle']['single'];

// Insert Active Recovery on the Sunday slot
$isoWeekday = (int)date('N');
$sundaySlot = 8 - $isoWeekday;
array_splice($workoutDays, $sundaySlot - 1, 0, ['Active Recovery']);
$splits = $workoutDays;

$gc = goalBaseConfig($goal);

// ── 2. Location → Equipment filter + preference ordering ─────────────────────
$equipmentFilter = '';
$equipmentOrder  = '';

switch ($location) {
    case 'home':
        $equipmentFilter = "AND e.equipment IN (
                                'Bodyweight','Dumbbell',
                                'Resistance Band','Kettlebell'
                            )";
        $equipmentOrder  = "CASE e.equipment
                                WHEN 'Bodyweight'      THEN 1
                                WHEN 'Dumbbell'        THEN 2
                                WHEN 'Resistance Band' THEN 3
                                WHEN 'Kettlebell'      THEN 4
                                ELSE 5
                            END ASC,";
        break;

    case 'both':
        $equipmentOrder  = "CASE e.equipment
                                WHEN 'Bodyweight'      THEN 1
                                WHEN 'Dumbbell'        THEN 2
                                WHEN 'Resistance Band' THEN 3
                                WHEN 'Kettlebell'      THEN 4
                                WHEN 'Barbell'         THEN 5
                                WHEN 'Machine'         THEN 6
                                ELSE 7
                            END ASC,";
        break;

    default: // gym
        $equipmentOrder  = "CASE e.equipment
                                WHEN 'Barbell' THEN 1
                                WHEN 'Machine' THEN 2
                                WHEN 'Cable'   THEN 3
                                WHEN 'Dumbbell'THEN 4
                                ELSE 5
                            END ASC,";
        break;
}

$goalOrder = '';
if ($goal === 'lose_fat') {
    $goalOrder = "CASE e.muscle_group WHEN 'Cardio' THEN 1 ELSE 2 END ASC,";
}

// Compound lifts sequenced FIRST — matches real program design
// (heavy compound work while fresh, isolation moves after)
$typeOrder = "CASE e.exercise_type WHEN 'compound' THEN 1 ELSE 2 END ASC,";

// ── 3. Create Routine Record ──────────────────────────────────────────────────
$cnt = $pdo->prepare("SELECT COUNT(*) FROM routines WHERE user_id = ?");
$cnt->execute([$uid]);
$seed       = (int)$cnt->fetchColumn();
$weekNumber = $seed + 1;
$phase      = weekPhase($weekNumber);

$pdo->prepare("
    INSERT INTO routines (user_id, week_number, variation_seed, start_date)
    VALUES (?, ?, ?, DATE_SUB(CURDATE(), INTERVAL (DAYOFWEEK(CURDATE()) + 5) % 7 DAY))
")->execute([$uid, $weekNumber, $seed]);
$routineId = $pdo->lastInsertId();

// ── 4. Build Each Day ─────────────────────────────────────────────────────────
foreach ($splits as $i => $focus) {
    $pdo->prepare("
        INSERT INTO routine_days (routine_id, day_of_week, focus) VALUES (?, ?, ?)
    ")->execute([$routineId, $i + 1, $focus]);
    $dayId = $pdo->lastInsertId();

    // ── Active Recovery (Sunday) ──────────────────────────────────────────
    if ($focus === 'Active Recovery') {
        $rq = $pdo->prepare("
            SELECT * FROM exercises
            WHERE muscle_group = 'Cardio' AND difficulty = 'beginner'
            ORDER BY RAND()
            LIMIT 3
        ");
        $rq->execute();
        foreach ($rq->fetchAll(PDO::FETCH_ASSOC) as $ex) {
            $pdo->prepare("
                INSERT INTO routine_exercises (routine_day_id, exercise_id, sets, reps)
                VALUES (?, ?, ?, ?)
            ")->execute([$dayId, $ex['id'], 1, '15-20 min']);
        }
        continue;
    }

    $groups    = explode('+', str_replace(' ', '', $focus));
    // FIX: exercise count is now based on how many muscle groups this
    //      day targets (1 → 6 exercises, 2 → 8 exercises balanced
    //      across both), not on the fitness goal.
    $numGroups = count($groups);
    $limit     = exerciseCountForGroups($numGroups);

    $exRows = fetchBalancedExercises(
        $pdo, $groups, $exp, $equipmentFilter, $equipmentOrder,
        $goalOrder, $typeOrder, $seed, $limit
    );

    foreach ($exRows as $ex) {
        $isCompound = ($ex['exercise_type'] ?? 'isolation') === 'compound';
        $timeBased  = isTimeBased($ex);

        [$sets, $repsStr] = buildScheme(
            $isCompound, $timeBased, $gc['sets'], $gc['reps'], $phase
        );

        $pdo->prepare("
            INSERT INTO routine_exercises (routine_day_id, exercise_id, sets, reps)
            VALUES (?, ?, ?, ?)
        ")->execute([$dayId, $ex['id'], $sets, $repsStr]);
    }
}

echo json_encode(["success" => true, "routine_id" => $routineId]);
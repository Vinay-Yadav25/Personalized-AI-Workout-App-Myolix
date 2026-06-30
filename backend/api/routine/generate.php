<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

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

$workoutDays = $splitConfig[$goal][$split]
    ?? $splitConfig['build_muscle']['single'];

// ── 2. Insert "Active Recovery" on the Sunday slot ───────────────────────────
// FIX: previously inserted a focus literally called 'Rest' with ZERO exercises.
//      Now Sunday becomes a light-cardio recovery day (walking/jogging/stretch
//      style movements), so the user always has something gentle to do —
//      but it's clearly distinguished from a hard training day.
$isoWeekday = (int)date('N');          // 1=Mon … 7=Sun
$sundaySlot = 8 - $isoWeekday;          // Mon→7, Tue→6, … Sun→1
array_splice($workoutDays, $sundaySlot - 1, 0, ['Active Recovery']);
$splits = $workoutDays;

// ── 3. Goal → Sets / Reps / Exercise count ───────────────────────────────────
$goalConfig = [
    'build_muscle' => ['sets' => 4, 'reps' => '8',  'limit' => 5],
    'lose_fat'     => ['sets' => 3, 'reps' => '15', 'limit' => 6],
    'maintain'     => ['sets' => 3, 'reps' => '12', 'limit' => 5],
];
$gc = $goalConfig[$goal] ?? $goalConfig['build_muscle'];

// ── 4. Location → Equipment filter + preference ordering ─────────────────────
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

// ── 5. Create Routine Record ──────────────────────────────────────────────────
// FIX: start_date is ALWAYS this Monday (regardless of which day "Generate"
//      is pressed on), guaranteeing day 1 = Mon … day 7 = Sun across the
//      whole app. This keeps Flutter's date labels and the recovery day
//      perfectly aligned with the real calendar.
$cnt = $pdo->prepare("SELECT COUNT(*) FROM routines WHERE user_id = ?");
$cnt->execute([$uid]);
$seed = (int)$cnt->fetchColumn();

$pdo->prepare("
    INSERT INTO routines (user_id, week_number, variation_seed, start_date)
    VALUES (?, ?, ?, DATE_SUB(CURDATE(), INTERVAL (DAYOFWEEK(CURDATE()) + 5) % 7 DAY))
")->execute([$uid, $seed + 1, $seed]);
$routineId = $pdo->lastInsertId();

// ── 6. Build Each Day ─────────────────────────────────────────────────────────
foreach ($splits as $i => $focus) {
    $pdo->prepare("
        INSERT INTO routine_days (routine_id, day_of_week, focus) VALUES (?, ?, ?)
    ")->execute([$routineId, $i + 1, $focus]);
    $dayId = $pdo->lastInsertId();

    // ── Active Recovery (Sunday) — light cardio, fixed light volume ──────────
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

    $groups       = explode('+', str_replace(' ', '', $focus));
    $placeholders = implode(',', array_fill(0, count($groups), '?'));
    $limit        = $gc['limit'];

    $sql = "
        SELECT * FROM exercises e
        WHERE  e.muscle_group IN ($placeholders)
          AND  e.difficulty    = ?
               $equipmentFilter
        ORDER BY
               $goalOrder
               $equipmentOrder
               (e.id + ?) % 7,
               RAND()
        LIMIT  $limit
    ";
    $q = $pdo->prepare($sql);
    $q->execute(array_merge($groups, [$exp, $seed]));
    $exRows = $q->fetchAll(PDO::FETCH_ASSOC);

    if (count($exRows) < 3 && $equipmentFilter !== '') {
        $q2 = $pdo->prepare("
            SELECT * FROM exercises e
            WHERE  e.muscle_group IN ($placeholders)
              AND  e.difficulty    = ?
            ORDER BY $goalOrder $equipmentOrder (e.id + ?) % 7, RAND()
            LIMIT  $limit
        ");
        $q2->execute(array_merge($groups, [$exp, $seed]));
        $exRows = $q2->fetchAll(PDO::FETCH_ASSOC);
    }

    if (count($exRows) < 3) {
        $q3 = $pdo->prepare("
            SELECT * FROM exercises e
            WHERE  e.muscle_group IN ($placeholders)
               $equipmentFilter
            ORDER BY $goalOrder $equipmentOrder RAND()
            LIMIT  $limit
        ");
        $q3->execute($groups);
        $exRows = $q3->fetchAll(PDO::FETCH_ASSOC);
    }

    foreach ($exRows as $ex) {
        $pdo->prepare("
            INSERT INTO routine_exercises (routine_day_id, exercise_id, sets, reps)
            VALUES (?, ?, ?, ?)
        ")->execute([$dayId, $ex['id'], $gc['sets'], $gc['reps']]);
    }
}

echo json_encode(["success" => true, "routine_id" => $routineId]);
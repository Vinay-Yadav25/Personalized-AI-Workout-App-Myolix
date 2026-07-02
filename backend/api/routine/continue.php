<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
require_once __DIR__ . '/../helpers/workout_scheme.php';
$uid = require_auth();

$action = $_GET['action'] ?? 'continue';

if ($action === 'continue') {
    // Get the routine BEFORE updating, so we know the new week number
    $find = $pdo->prepare("
        SELECT id, week_number FROM routines
        WHERE user_id = ? ORDER BY id DESC LIMIT 1
    ");
    $find->execute([$uid]);
    $routine = $find->fetch(PDO::FETCH_ASSOC);

    if (!$routine) {
        http_response_code(400);
        echo json_encode(["error" => "No routine to continue"]);
        exit;
    }

    $newWeekNumber = $routine['week_number'] + 1;
    $phase         = weekPhase($newWeekNumber);

    // Advance week + reset dates to this Monday (keeps Sunday = recovery day)
    $pdo->prepare("
        UPDATE routines
        SET status      = 'active',
            week_number = ?,
            start_date  = DATE_SUB(
                              CURDATE(),
                              INTERVAL (DAYOFWEEK(CURDATE()) + 5) % 7 DAY
                          )
        WHERE id = ?
    ")->execute([$newWeekNumber, $routine['id']]);

    // Reset all checkboxes
    $pdo->prepare("
        UPDATE routine_exercises re
        JOIN routine_days rd ON rd.id = re.routine_day_id
        SET re.is_completed = 0
        WHERE rd.routine_id = ?
    ")->execute([$routine['id']]);

    // FIX: recalculate sets/reps for the NEW week's periodization phase.
    //      Without this, "Continue" just repeated the exact same reps
    //      forever — the exercises never actually got harder or lighter,
    //      which isn't how a real progressive program works.
    $p = $pdo->prepare("SELECT * FROM user_profiles WHERE user_id = ?");
    $p->execute([$uid]);
    $profile = $p->fetch(PDO::FETCH_ASSOC);
    $gc      = goalBaseConfig($profile['goal'] ?? 'build_muscle');

    $exStmt = $pdo->prepare("
        SELECT re.id AS routine_exercise_id, re.reps AS current_reps,
               e.name, e.muscle_group, e.exercise_type
        FROM routine_exercises re
        JOIN routine_days rd ON rd.id = re.routine_day_id
        JOIN exercises e     ON e.id  = re.exercise_id
        WHERE rd.routine_id = ?
    ");
    $exStmt->execute([$routine['id']]);

    foreach ($exStmt->fetchAll(PDO::FETCH_ASSOC) as $ex) {
        // Skip Active Recovery entries — identified by their fixed
        // "15-20 min" format, which never gets periodized
        if (stripos($ex['current_reps'] ?? '', 'min') !== false) continue;

        $isCompound = ($ex['exercise_type'] ?? 'isolation') === 'compound';
        $timeBased  = isTimeBased($ex);

        [$sets, $repsStr] = buildScheme(
            $isCompound, $timeBased, $gc['sets'], $gc['reps'], $phase
        );

        $pdo->prepare("
            UPDATE routine_exercises SET sets = ?, reps = ? WHERE id = ?
        ")->execute([$sets, $repsStr, $ex['routine_exercise_id']]);
    }

    echo json_encode(["mode" => "continued", "week_number" => $newWeekNumber]);
} else {
    include __DIR__ . '/generate.php';
}
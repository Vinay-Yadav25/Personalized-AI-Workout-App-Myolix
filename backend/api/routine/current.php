<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
$uid = require_auth();

// Find the latest routine (active or completed)
$stmt = $pdo->prepare("
    SELECT * FROM routines
    WHERE user_id = ?
    ORDER BY id DESC
    LIMIT 1
");
$stmt->execute([$uid]);
$routine = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$routine) {
    echo json_encode(["days" => [], "status" => "none"]);
    exit;
}

// Fetch all days for this routine
$ds = $pdo->prepare("
    SELECT * FROM routine_days
    WHERE routine_id = ?
    ORDER BY day_of_week ASC
");
$ds->execute([$routine['id']]);
$days = $ds->fetchAll(PDO::FETCH_ASSOC);

// Fetch exercises for each day
$exStmt = $pdo->prepare("
    SELECT re.id, re.sets, re.reps, re.is_completed,
           e.name, e.muscle_group, e.equipment
    FROM routine_exercises re
    JOIN exercises e ON e.id = re.exercise_id
    WHERE re.routine_day_id = ?
");

foreach ($days as &$day) {
    $exStmt->execute([$day['id']]);
    $day['exercises'] = $exStmt->fetchAll(PDO::FETCH_ASSOC);
}

echo json_encode([
    "id"          => $routine['id'],
    "week_number" => $routine['week_number'],
    "status"      => $routine['status'],
    "start_date"  => $routine['start_date'],
    "days"        => $days,
]);
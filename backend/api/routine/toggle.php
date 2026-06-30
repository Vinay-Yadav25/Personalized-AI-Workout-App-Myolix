<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
$uid = require_auth();

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['routine_exercise_id']) || !isset($data['done'])) {
    http_response_code(400);
    echo json_encode(["error" => "Missing routine_exercise_id or done field"]);
    exit;
}

$id   = (int)$data['routine_exercise_id'];
$done = $data['done'] ? 1 : 0;

$pdo->prepare("
    UPDATE routine_exercises SET is_completed = ? WHERE id = ?
")->execute([$done, $id]);

// Auto-mark routine completed if every exercise is done.
// FIX: was filtering WHERE r.status = 'active' which is correct here,
//      but also verify ownership so one user can't complete another's routine.
$check = $pdo->prepare("
    SELECT SUM(re.is_completed) = COUNT(*) AS all_done, r.id AS rid
    FROM routine_exercises re
    JOIN routine_days rd ON rd.id = re.routine_day_id
    JOIN routines r      ON r.id  = rd.routine_id
    WHERE r.user_id = ? AND r.status = 'active'
    GROUP BY r.id
");
$check->execute([$uid]);
$row = $check->fetch(PDO::FETCH_ASSOC);

if ($row && $row['all_done']) {
    $pdo->prepare("
        UPDATE routines SET status = 'completed' WHERE id = ?
    ")->execute([$row['rid']]);
}

echo json_encode(["success" => true]);
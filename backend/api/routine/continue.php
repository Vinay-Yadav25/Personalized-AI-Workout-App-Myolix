<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
$uid = require_auth();

$action = $_GET['action'] ?? 'continue';

if ($action === 'continue') {
    // FIX: also update start_date to CURDATE() so that the Flutter week-strip
    //      always shows correct calendar dates for the NEW week.
    //      Previously start_date was never updated, so week 7 still showed
    //      the original generation date instead of this week's Monday.
    $pdo->prepare("
        UPDATE routines
        SET status      = 'active',
            week_number = week_number + 1,
            start_date  = CURDATE()
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT 1
    ")->execute([$uid]);

    // Reset all exercise checkboxes
    $pdo->prepare("
        UPDATE routine_exercises re
        JOIN routine_days rd ON rd.id = re.routine_day_id
        JOIN routines r      ON r.id  = rd.routine_id
        SET re.is_completed = 0
        WHERE r.user_id = ? AND r.status = 'active'
    ")->execute([$uid]);

    echo json_encode(["mode" => "continued"]);
} else {
    include __DIR__ . '/generate.php';
}
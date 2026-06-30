<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
$uid = require_auth();

// ── 1. Get latest routine ────────────────────────────────────────────────────
$routineStmt = $pdo->prepare("
    SELECT id, start_date FROM routines
    WHERE user_id = ?
    ORDER BY id DESC LIMIT 1
");
$routineStmt->execute([$uid]);
$latestRoutine = $routineStmt->fetch(PDO::FETCH_ASSOC);

// ── 2. Snapshot TODAY's completion state ─────────────────────────────────────
if ($latestRoutine) {
    $rid = $latestRoutine['id'];

    $today = $pdo->prepare("
        SELECT SUM(re.is_completed) AS done, COUNT(re.id) AS total
        FROM routine_exercises re
        JOIN routine_days rd ON rd.id = re.routine_day_id
        WHERE rd.routine_id = ?
          AND rd.day_of_week = (
              SELECT day_of_week FROM routine_days
              WHERE routine_id = ?
              ORDER BY ABS(DATEDIFF(
                  DATE_ADD(
                      (SELECT start_date FROM routines WHERE id = ?),
                      INTERVAL (day_of_week - 1) DAY
                  ), CURDATE()
              )) ASC
              LIMIT 1
          )
    ");
    $today->execute([$rid, $rid, $rid]);
    $row = $today->fetch(PDO::FETCH_ASSOC);

    if ($row && $row['total'] > 0) {
        $check = $pdo->prepare("
            SELECT id FROM progress_log WHERE user_id = ? AND log_date = CURDATE()
        ");
        $check->execute([$uid]);
        $exists = $check->fetchColumn();

        if ($exists) {
            $pdo->prepare("
                UPDATE progress_log SET completed_exercises=?, total_exercises=?
                WHERE id=?
            ")->execute([(int)$row['done'], (int)$row['total'], $exists]);
        } else {
            $pdo->prepare("
                INSERT INTO progress_log (user_id, log_date, completed_exercises, total_exercises)
                VALUES (?, CURDATE(), ?, ?)
            ")->execute([$uid, (int)$row['done'], (int)$row['total']]);
        }
    }

    // ── 3. Auto-log SKIPPED past days ────────────────────────────────────────
    // For every routine day whose date has already passed (before today),
    // insert a progress_log entry if one doesn't exist yet.
    $startDate = new DateTime($latestRoutine['start_date']);
    $todayDate = new DateTime('today');

    for ($dayNum = 1; $dayNum <= 7; $dayNum++) {
        $dayDate = (clone $startDate)->modify('+' . ($dayNum - 1) . ' days');
        // Only process days strictly before today
        if ($dayDate >= $todayDate) break;

        $dayDateStr = $dayDate->format('Y-m-d');

        // Skip if already logged
        $alreadyLogged = $pdo->prepare("
            SELECT id FROM progress_log WHERE user_id = ? AND log_date = ?
        ");
        $alreadyLogged->execute([$uid, $dayDateStr]);
        if ($alreadyLogged->fetchColumn()) continue;

        // Get exercise counts for this day
        $exStmt = $pdo->prepare("
            SELECT
                COUNT(re.id)         AS total,
                SUM(re.is_completed) AS done
            FROM routine_exercises re
            JOIN routine_days rd ON rd.id = re.routine_day_id
            WHERE rd.routine_id = ? AND rd.day_of_week = ?
        ");
        $exStmt->execute([$rid, $dayNum]);
        $ex = $exStmt->fetch(PDO::FETCH_ASSOC);

        // Skip rest days
        if (!$ex || (int)$ex['total'] === 0) continue;

        $pdo->prepare("
            INSERT INTO progress_log (user_id, log_date, completed_exercises, total_exercises)
            VALUES (?, ?, ?, ?)
        ")->execute([$uid, $dayDateStr, (int)$ex['done'], (int)$ex['total']]);
    }
}

// ── 4. Return last 30 days ───────────────────────────────────────────────────
$log = $pdo->prepare("
    SELECT log_date, completed_exercises, total_exercises, weight_kg
    FROM progress_log
    WHERE user_id = ?
    ORDER BY log_date ASC
    LIMIT 30
");
$log->execute([$uid]);

echo json_encode(["log" => $log->fetchAll(PDO::FETCH_ASSOC)]);
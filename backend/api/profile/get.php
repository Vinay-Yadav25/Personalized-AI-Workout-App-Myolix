<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
$uid = require_auth();

$stmt = $pdo->prepare("
    SELECT height_cm, weight_kg, experience, split_type, goal
    FROM user_profiles
    WHERE user_id = ?
");
$stmt->execute([$uid]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

echo json_encode($row ?: new stdClass());
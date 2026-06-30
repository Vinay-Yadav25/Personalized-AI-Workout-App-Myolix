<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';
$uid = require_auth();

$d = json_decode(file_get_contents("php://input"), true);

$required = ['height_cm', 'weight_kg', 'experience', 'split_type', 'goal', 'workout_location'];
foreach ($required as $field) {
    if (!isset($d[$field]) || $d[$field] === '' || $d[$field] === null) {
        http_response_code(400);
        echo json_encode(["error" => "Missing required field: $field"]);
        exit;
    }
}

$height   = (float)$d['height_cm'];
$weight   = (float)$d['weight_kg'];
$location = $d['workout_location'];

if ($height <= 0 || $weight <= 0) {
    http_response_code(400);
    echo json_encode(["error" => "height_cm and weight_kg must be positive numbers"]);
    exit;
}

$validLocations = ['home', 'gym', 'both'];
if (!in_array($location, $validLocations)) {
    http_response_code(400);
    echo json_encode(["error" => "workout_location must be: home, gym, or both"]);
    exit;
}

$stmt = $pdo->prepare("SELECT id FROM user_profiles WHERE user_id = ?");
$stmt->execute([$uid]);
$exists = $stmt->fetchColumn();

if ($exists) {
    $pdo->prepare("
        UPDATE user_profiles
        SET height_cm=?, weight_kg=?, experience=?, split_type=?, goal=?, workout_location=?
        WHERE user_id=?
    ")->execute([$height, $weight, $d['experience'], $d['split_type'], $d['goal'], $location, $uid]);
} else {
    $pdo->prepare("
        INSERT INTO user_profiles
            (user_id, height_cm, weight_kg, experience, split_type, goal, workout_location)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ")->execute([$uid, $height, $weight, $d['experience'], $d['split_type'], $d['goal'], $location]);
}

echo json_encode(["success" => true]);
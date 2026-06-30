<?php
require_once __DIR__ . '/config/db.php';

$row = $pdo->query("SELECT COUNT(*) AS users FROM users")->fetch(PDO::FETCH_ASSOC);
echo json_encode(["db" => "ok", "user_count" => $row['users']]);
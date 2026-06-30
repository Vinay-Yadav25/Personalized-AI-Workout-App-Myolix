<?php
// Suppress HTML error output — prevents PHP notices from corrupting JSON responses
// Errors are logged to PHP error_log instead (check xampp/php/logs/)
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
error_reporting(E_ALL);
ini_set('log_errors', '1');

// Output buffer catches any accidental whitespace/output before headers
ob_start();

// Load DB credentials from environment; fallback for local dev only
$host = getenv('DB_HOST') ?: "localhost";
$db   = getenv('DB_NAME') ?: "workout_ai";
$user = getenv('DB_USER') ?: "root";
$pass = getenv('DB_PASS') ?: "";

try {
    $pdo = new PDO(
        "mysql:host=$host;dbname=$db;charset=utf8mb4",
        $user,
        $pass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["error" => "DB connection failed"]);
    exit;
}

header("Content-Type: application/json");
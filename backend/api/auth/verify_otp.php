<?php
require_once __DIR__ . '/../config/db.php';

$data  = json_decode(file_get_contents("php://input"), true);
$email = trim($data['email'] ?? '');
$otp   = trim($data['otp']   ?? '');

if (!$email || !$otp) {
    http_response_code(400);
    echo json_encode(["error" => "Email and OTP are required"]);
    exit;
}

// Fetch the most recent non-expired OTP for this email
$stmt = $pdo->prepare("
    SELECT otp FROM password_resets
    WHERE email = ? AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1
");
$stmt->execute([$email]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$row || !password_verify($otp, $row['otp'])) {
    http_response_code(400);
    echo json_encode(["error" => "Invalid or expired OTP"]);
    exit;
}

// OTP is valid — don't delete it yet; reset_password.php will verify again
echo json_encode(["success" => true, "message" => "OTP verified"]);
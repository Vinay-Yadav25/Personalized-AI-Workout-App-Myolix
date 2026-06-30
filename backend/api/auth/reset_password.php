<?php
require_once __DIR__ . '/../config/db.php';

$data        = json_decode(file_get_contents("php://input"), true);
$email       = trim($data['email']    ?? '');
$otp         = trim($data['otp']      ?? '');
$newPassword = $data['new_password']  ?? '';

if (!$email || !$otp || strlen($newPassword) < 6) {
    http_response_code(400);
    echo json_encode(["error" => "Email, OTP and new password (min 6 chars) required"]);
    exit;
}

// Re-verify OTP (double-check to prevent skipping verify_otp.php)
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

// Update the password
$hash = password_hash($newPassword, PASSWORD_BCRYPT);
$pdo->prepare("UPDATE users SET password_hash = ? WHERE email = ?")
    ->execute([$hash, $email]);

// Delete all OTPs for this email — cannot reuse
$pdo->prepare("DELETE FROM password_resets WHERE email = ?")
    ->execute([$email]);

echo json_encode(["success" => true, "message" => "Password updated successfully"]);
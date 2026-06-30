<?php

header("Content-Type: application/json");

// Set timezone
date_default_timezone_set('Asia/Kolkata');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/send_mail.php';

// Read JSON input
$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "error" => "Invalid request data."
    ]);
    exit;
}

$email = trim($data['email'] ?? '');

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "error" => "Invalid email address."
    ]);
    exit;
}

try {

    // Find user
    $stmt = $pdo->prepare("
        SELECT name
        FROM users
        WHERE email = ?
        LIMIT 1
    ");

    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    // Don't reveal whether email exists
    if (!$user) {
        echo json_encode([
            "success" => true,
            "message" => "If this email is registered, an OTP has been sent."
        ]);
        exit;
    }

    // Generate secure 6-digit OTP
    $otp = str_pad(random_int(0, 999999), 6, "0", STR_PAD_LEFT);

    // Hash OTP
    $hashedOtp = password_hash($otp, PASSWORD_BCRYPT);

    // Remove previous OTPs
    $delete = $pdo->prepare("
        DELETE FROM password_resets
        WHERE email = ?
    ");

    $delete->execute([$email]);

    // Save new OTP (expires in 10 minutes using MySQL time)
    $insert = $pdo->prepare("
        INSERT INTO password_resets
        (email, otp, expires_at)
        VALUES
        (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))
    ");

    $insert->execute([
        $email,
        $hashedOtp
    ]);

    // Send OTP email
    $sent = sendOtpEmail(
        $email,
        $user['name'],
        $otp
    );

    if (!$sent) {
        http_response_code(500);

        echo json_encode([
            "success" => false,
            "error" => "Failed to send OTP email."
        ]);
        exit;
    }

    echo json_encode([
        "success" => true,
        "message" => "OTP sent successfully."
    ]);

} catch (PDOException $e) {

    http_response_code(500);

    echo json_encode([
        "success" => false,
        "error" => "Database error.",
        "details" => $e->getMessage()
    ]);
}
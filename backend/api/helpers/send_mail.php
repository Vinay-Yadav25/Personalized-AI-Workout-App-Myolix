<?php
/**
 * send_mail.php — PHPMailer SMTP helper
 *
 * SETUP (one-time):
 *  1. Download PHPMailer: https://github.com/PHPMailer/PHPMailer/archive/refs/heads/master.zip
 *  2. Extract it → rename folder to "phpmailer"
 *  3. Place the "phpmailer" folder inside:  backend/  (same level as api/)
 *     So the path is:  backend/phpmailer/src/PHPMailer.php
 *  4. Create a Gmail App Password:
 *       Google Account → Security → 2-Step Verification → App Passwords
 *       → Select "Mail" → Generate → copy the 16-char password
 *  5. Fill in MAIL_USER and MAIL_PASS below (or set as server env vars)
 */

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/../../phpmailer/src/Exception.php';
require_once __DIR__ . '/../../phpmailer/src/PHPMailer.php';
require_once __DIR__ . '/../../phpmailer/src/SMTP.php';

function sendOtpEmail(string $toEmail, string $toName, string $otp): bool
{
    $mailUser = getenv('MAIL_USER') ?: 'myolix.app@gmail.com';   // ← change this
    $mailPass = getenv('MAIL_PASS') ?: 'vtqljcvbwukmkkxg';      // ← change this

    $mail = new PHPMailer(true);
    try {
        // SMTP config
        $mail->isSMTP();
        $mail->Host       = 'smtp.gmail.com';
        $mail->SMTPAuth   = true;
        $mail->Username   = $mailUser;
        $mail->Password   = $mailPass;
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = 587;

        // Sender / recipient
        $mail->setFrom($mailUser, 'Myolix');
        $mail->addAddress($toEmail, $toName ?: $toEmail);

        // Content
        $mail->isHTML(true);
        $mail->Subject = 'Your Password Reset OTP — AI Workout';
        $mail->Body    = "
        <div style='font-family:Arial,sans-serif;max-width:480px;margin:auto'>
          <h2 style='color:#6C5CE7'>AI Workout</h2>
          <p>We received a request to reset your password.</p>
          <p>Your one-time password (OTP) is:</p>
          <div style='font-size:36px;font-weight:bold;letter-spacing:12px;
                      color:#6C5CE7;padding:16px 0'>$otp</div>
          <p style='color:#888'>This OTP expires in <b>10 minutes</b>.</p>
          <p style='color:#888'>If you didn't request this, ignore this email —
             your password will not change.</p>
        </div>";
        $mail->AltBody = "Your AI Workout OTP is: $otp  (expires in 10 minutes)";

        $mail->send();
        return true;
    } catch (Exception $e) {
        error_log("PHPMailer error: {$mail->ErrorInfo}");
        return false;
    }
}
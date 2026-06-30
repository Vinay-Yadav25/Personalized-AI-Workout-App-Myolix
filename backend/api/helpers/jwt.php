<?php
// Load secret from environment variable; fallback for local dev only
$JWT_SECRET = getenv('JWT_SECRET') ?: "change-this-secret";

function b64($s) {
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}

function jwt_encode($payload) {
    global $JWT_SECRET;
    $h   = b64(json_encode(["alg" => "HS256", "typ" => "JWT"]));
    $p   = b64(json_encode($payload));
    $sig = b64(hash_hmac('sha256', "$h.$p", $JWT_SECRET, true));
    return "$h.$p.$sig";
}

function jwt_decode($jwt) {
    global $JWT_SECRET;
    $parts = explode('.', $jwt);
    if (count($parts) !== 3) return null;
    [$h, $p, $s] = $parts;
    $valid = b64(hash_hmac('sha256', "$h.$p", $JWT_SECRET, true));
    if (!hash_equals($valid, $s)) return null;
    return json_decode(base64_decode(strtr($p, '-_', '+/')), true);
}

function require_auth() {
    header('Content-Type: application/json');

    $headers    = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (!$authHeader) {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "status"  => 401,
            "message" => "Authorization header missing"
        ]);
        exit;
    }

    if (!preg_match('/Bearer\s+(.+)/', $authHeader, $matches)) {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "status"  => 401,
            "message" => "Invalid Authorization format. Use: Bearer <token>"
        ]);
        exit;
    }

    $token   = $matches[1];
    $decoded = jwt_decode($token); // FIX: was decode_jwt() — function did not exist

    // FIX: jwt_decode() returns array not object; also validate expiry
    if (
        !$decoded ||
        !isset($decoded['uid']) ||
        (isset($decoded['exp']) && $decoded['exp'] < time())
    ) {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "status"  => 401,
            "message" => "Invalid or expired token"
        ]);
        exit;
    }

    return $decoded['uid']; // FIX: was $decoded->user_id ?? $decoded->uid (object on array)
}
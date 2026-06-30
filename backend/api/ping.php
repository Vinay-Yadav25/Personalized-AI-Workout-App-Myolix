<?php
ini_set('display_errors', '0');
error_reporting(0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

echo json_encode([
    "status"      => "ok",
    "message"     => "Backend is alive",
    "time"        => date("Y-m-d H:i:s"),
    "php_version" => PHP_VERSION
]);
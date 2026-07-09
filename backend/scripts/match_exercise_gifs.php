<?php
/**
 * match_exercise_gifs.php
 * ------------------------------------------------------------
 * ONE-TIME SCRIPT — run this once from your browser, not an API
 * endpoint your app calls repeatedly.
 *
 * SETUP:
 *  1. Go to https://rapidapi.com/exercisedb-exercisedb-default/api/exercisedb
 *  2. Subscribe to the FREE tier (500 requests/month is enough — this
 *     script only needs ~2-3 requests total, not one per exercise).
 *  3. Copy your RapidAPI key from the dashboard.
 *  4. Paste it into RAPIDAPI_KEY below.
 *  5. Place this file at: backend/scripts/match_exercise_gifs.php
 *  6. Open in browser: http://localhost/backend/scripts/match_exercise_gifs.php
 *  7. Read the output report carefully — it shows EVERY match with a
 *     confidence score. Anything under 60% should be manually checked.
 *
 * WHY FUZZY MATCHING:
 *  Your exercise names ("Barbell Flat Bench Press") won't exactly match
 *  ExerciseDB's naming ("barbell bench press"). This script scores each
 *  candidate using:
 *    - Text similarity of the name (60% weight)
 *    - Equipment match bonus       (25% weight)
 *    - Muscle group match bonus    (15% weight)
 *  and picks the highest-scoring candidate above a minimum threshold.
 * ------------------------------------------------------------
 */

require_once __DIR__ . '/../config/db.php';

// ⚠️ PASTE YOUR RAPIDAPI KEY HERE
const RAPIDAPI_KEY = '72422b34bfmsh9b877134e4bc919p13a6e9jsn2493c3279d9c';

const MIN_CONFIDENCE = 40; // % — below this, we leave gif_url as NULL

// Map your muscle_group values to ExerciseDB's "target"/"bodyPart" vocabulary
$muscleGroupMap = [
    'Chest'    => ['pectorals'],
    'Back'     => ['lats', 'upper back', 'traps'],
    'Legs'     => ['quads', 'hamstrings', 'glutes', 'calves', 'adductors', 'abductors'],
    'Shoulders'=> ['delts'],
    'Arms'     => ['biceps', 'triceps', 'forearms'],
    'Triceps'  => ['triceps'],
    'Biceps'   => ['biceps'],
    'Core'     => ['abs', 'waist'],
    'Cardio'   => ['cardio', 'cardiovascular system'],
    'FullBody' => ['cardio', 'upper legs', 'chest', 'back'],
];

// Map your equipment values to ExerciseDB's equipment vocabulary
$equipmentMap = [
    'Bodyweight'      => ['body weight'],
    'Barbell'         => ['barbell', 'ez barbell'],
    'Dumbbell'        => ['dumbbell'],
    'Cable'           => ['cable'],
    'Machine'         => ['leverage machine', 'sled machine', 'smith machine'],
    'Resistance Band' => ['band'],
    'Kettlebell'      => ['kettlebell'],
    'TRX'             => ['trx'],
];

function similarityScore(string $a, string $b): float {
    $a = strtolower(trim($a));
    $b = strtolower(trim($b));
    similar_text($a, $b, $percent);
    return $percent;
}

function fetchExerciseDbList(): array {
    $ch = curl_init("https://exercisedb.p.rapidapi.com/exercises?limit=0");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "X-RapidAPI-Key: " . RAPIDAPI_KEY,
        "X-RapidAPI-Host: exercisedb.p.rapidapi.com",
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200) {
        die("❌ Failed to fetch ExerciseDB list. HTTP $httpCode. Response: $response");
    }
    return json_decode($response, true) ?? [];
}

// ── Main ──────────────────────────────────────────────────────────────────────
header('Content-Type: text/html; charset=utf-8');
echo "<h2>🔍 Exercise GIF Matcher</h2>";

if (RAPIDAPI_KEY === 'YOUR_RAPIDAPI_KEY_HERE') {
    die("<p style='color:red'>⚠️ Please paste your RapidAPI key into the script first.</p>");
}

echo "<p>Fetching ExerciseDB library (one-time request)...</p>";
flush();
$exerciseDbList = fetchExerciseDbList();
echo "<p>✅ Loaded " . count($exerciseDbList) . " exercises from ExerciseDB.</p>";

// Load your local exercises
$local = $pdo->query("SELECT id, name, muscle_group, equipment FROM exercises")
              ->fetchAll(PDO::FETCH_ASSOC);
echo "<p>Matching against your " . count($local) . " exercises...</p><hr>";

echo "<table border='1' cellpadding='6' style='border-collapse:collapse;font-family:monospace;font-size:13px'>
<tr style='background:#333;color:#fff'>
  <th>Your Exercise</th><th>Matched To</th><th>Confidence</th><th>GIF</th>
</tr>";

$updated = 0;
$skipped = 0;

foreach ($local as $ex) {
    $bestScore = 0;
    $bestMatch = null;

    $allowedTargets   = $muscleGroupMap[$ex['muscle_group']] ?? [];
    $allowedEquipment = $equipmentMap[$ex['equipment']] ?? [];

    foreach ($exerciseDbList as $candidate) {
        $nameScore = similarityScore($ex['name'], $candidate['name']);

        $equipmentBonus = in_array(strtolower($candidate['equipment']), $allowedEquipment) ? 25 : 0;
        $muscleBonus    = in_array(strtolower($candidate['target']), $allowedTargets)
                       || in_array(strtolower($candidate['bodyPart']), $allowedTargets)
                          ? 15 : 0;

        $totalScore = ($nameScore * 0.6) + $equipmentBonus + $muscleBonus;

        if ($totalScore > $bestScore) {
            $bestScore = $totalScore;
            $bestMatch = $candidate;
        }
    }

    $confidence = round($bestScore, 1);
    $rowColor = $confidence >= 60 ? '#d4edda' : ($confidence >= MIN_CONFIDENCE ? '#fff3cd' : '#f8d7da');

    echo "<tr style='background:$rowColor'>
            <td>{$ex['name']}</td>
            <td>" . ($bestMatch['name'] ?? '—') . "</td>
            <td>{$confidence}%</td>
            <td>" . ($bestMatch ? "<img src='{$bestMatch['gifUrl']}' width='60'>" : '—') . "</td>
          </tr>";

    if ($bestMatch && $confidence >= MIN_CONFIDENCE) {
        $pdo->prepare("
            UPDATE exercises SET gif_url = ?, gif_match_score = ? WHERE id = ?
        ")->execute([$bestMatch['gifUrl'], (int)$confidence, $ex['id']]);
        $updated++;
    } else {
        $skipped++;
    }
}

echo "</table><hr>";
echo "<h3>✅ Done — $updated matched, $skipped skipped (below {$confidence}% threshold)</h3>";
echo "<p><b>Review rows highlighted in red/yellow above.</b> To manually fix a bad match, run:</p>";
echo "<pre>UPDATE exercises SET gif_url = 'CORRECT_URL_HERE' WHERE name = 'Exercise Name';</pre>";
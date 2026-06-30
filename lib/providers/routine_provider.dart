import 'package:flutter/foundation.dart';
import '../services/api.dart';

class RoutineProvider extends ChangeNotifier {
  Map<String, dynamic>? routine;
  bool loading = false;
  String? error;
  // FIX: expose a flag so HomeScreen can trigger progress reload
  //      when the routine transitions to 'completed'
  bool justCompleted = false;

  bool get isCompleted => routine?['status'] == 'completed';
  List get days => routine?['days'] as List? ?? [];

  Future<void> loadCurrent() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await Api.get('/routine/current.php');
      if (data.containsKey('error')) {
        error = data['error'] as String;
      } else {
        final wasCompleted = isCompleted;
        routine = data;
        // Flag if this load reveals a fresh completion
        justCompleted = !wasCompleted && isCompleted;
      }
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> generate() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await Api.post('/routine/generate.php', {});
      if (res.containsKey('error')) {
        error = res['error'] as String;
        loading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
      return;
    }
    await loadCurrent();
  }

  Future<void> toggleExercise(int routineExerciseId, bool done) async {
    // Optimistic UI update
    for (final day in days) {
      final exercises = day['exercises'] as List? ?? [];
      for (final ex in exercises) {
        if ((ex['id'] as num).toInt() == routineExerciseId) {
          ex['is_completed'] = done ? 1 : 0;
        }
      }
    }
    notifyListeners();

    try {
      await Api.post('/routine/toggle.php', {
        'routine_exercise_id': routineExerciseId,
        'done': done,
      });
    } catch (_) {
      // Revert optimistic update on failure
      for (final day in days) {
        final exercises = day['exercises'] as List? ?? [];
        for (final ex in exercises) {
          if ((ex['id'] as num).toInt() == routineExerciseId) {
            ex['is_completed'] = done ? 0 : 1;
          }
        }
      }
      notifyListeners();
      return;
    }
    await loadCurrent(); // refresh to detect auto-completion status change
  }

  Future<void> continueRoutine() async {
    loading = true;
    justCompleted = false;
    notifyListeners();
    try {
      await Api.get('/routine/continue.php?action=continue');
    } catch (_) {}
    await loadCurrent();
  }

  Future<void> generateNewRoutine() async {
    loading = true;
    justCompleted = false;
    notifyListeners();
    try {
      await Api.get('/routine/continue.php?action=new');
    } catch (_) {}
    await loadCurrent();
  }

  int get totalExercises {
    int n = 0;
    for (final d in days) {
      n += ((d['exercises'] as List?)?.length ?? 0);
    }
    return n;
  }

  int get completedExercises {
    int n = 0;
    for (final d in days) {
      for (final e in (d['exercises'] as List? ?? [])) {
        if (e['is_completed'] == 1) n++;
      }
    }
    return n;
  }

  double get completionPercent =>
      totalExercises == 0 ? 0.0 : completedExercises / totalExercises;
}
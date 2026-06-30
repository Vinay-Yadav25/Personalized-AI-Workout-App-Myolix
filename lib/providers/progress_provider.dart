import 'package:flutter/foundation.dart';
import '../services/api.dart';

class ProgressProvider extends ChangeNotifier {
  List<Map<String, dynamic>> log = [];
  bool loading = false;
  String? error;

  int get totalWorkouts => log.length;

  int get totalCompleted => log.fold(
    0,
        (sum, e) => sum + ((e['completed_exercises'] ?? 0) as num).toInt(),
  );

  double get avgCompletion {
    if (log.isEmpty) return 0.0;
    // FIX: was using integer division — done/total with two ints = int in Dart.
    //      Must cast to double first.
    final pcts = log.map((e) {
      final total = ((e['total_exercises']     ?? 0) as num).toInt();
      final done  = ((e['completed_exercises'] ?? 0) as num).toInt();
      return total == 0 ? 0.0 : done.toDouble() / total.toDouble();
    });
    return pcts.reduce((a, b) => a + b) / log.length;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await Api.get('/progress/summary.php');
      if (data.containsKey('error')) {
        error = data['error'] as String;
        log = [];
      } else {
        log = List<Map<String, dynamic>>.from(data['log'] ?? []);
      }
    } catch (e) {
      error = e.toString();
      log = [];
    }
    loading = false;
    notifyListeners();
  }
}
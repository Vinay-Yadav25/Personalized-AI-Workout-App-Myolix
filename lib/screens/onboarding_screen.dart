import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/routine_provider.dart';
import '../services/api.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _height  = TextEditingController();
  final _weight  = TextEditingController();
  String _experience       = 'beginner';
  String _split            = 'single';
  String _goal             = 'build_muscle';
  String _workoutLocation  = 'gym';
  bool   _loading          = false;

  @override
  void dispose() { _height.dispose(); _weight.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await Api.post('/profile/save.php', {
      'height_cm':        double.parse(_height.text),
      'weight_kg':        double.parse(_weight.text),
      'experience':       _experience,
      'split_type':       _split,
      'goal':             _goal,
      'workout_location': _workoutLocation,
    });

    if (!mounted) return;
    if (res.containsKey('error')) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: ${res['error']}')),
      );
      return;
    }

    await context.read<AuthProvider>().markProfileComplete();
    await context.read<RoutineProvider>().generate();

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about you')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      kToolbarHeight -
                      48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'We will craft a weekly plan tailored to you.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller:  _height,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:  'Height (cm)',
                          prefixIcon: Icon(Icons.height),
                        ),
                        validator: (v) =>
                        v == null || double.tryParse(v) == null
                            ? 'Enter valid number' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller:   _weight,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:  'Weight (kg)',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        validator: (v) =>
                        v == null || double.tryParse(v) == null
                            ? 'Enter valid number' : null,
                      ),
                      const SizedBox(height: 24),
                      _drop(
                        label:    'Experience',
                        icon:     Icons.bar_chart,
                        value:    _experience,
                        items:    const {
                          'beginner':     'Beginner',
                          'intermediate': 'Intermediate',
                          'advanced':     'Advanced',
                        },
                        onChanged: (v) => setState(() => _experience = v!),
                      ),
                      const SizedBox(height: 16),
                      _drop(
                        label:    'Workout Split',
                        icon:     Icons.splitscreen,
                        value:    _split,
                        items:    const {
                          'single': 'Single muscle group / day',
                          'double': 'Double muscle group / day',
                        },
                        onChanged: (v) => setState(() => _split = v!),
                      ),
                      const SizedBox(height: 16),
                      _drop(
                        label:    'Goal',
                        icon:     Icons.flag_outlined,
                        value:    _goal,
                        items:    const {
                          'lose_fat':     'Lose Fat',
                          'build_muscle': 'Build Muscle',
                          'maintain':     'Maintain',
                        },
                        onChanged: (v) => setState(() => _goal = v!),
                      ),
                      const SizedBox(height: 16),
                      _drop(
                        label:    'Workout Location',
                        icon:     Icons.place_outlined,
                        value:    _workoutLocation,
                        items:    const {
                          'gym':  '🏋️ Gym — full equipment',
                          'home': '🏠 Home — bodyweight & dumbbells',
                          'both': '🔄 Both — mix of equipment',
                        },
                        onChanged: (v) => setState(() => _workoutLocation = v!),
                      ),
                      const SizedBox(height: 32),
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                        onPressed: _save,
                        icon:  const Icon(Icons.auto_awesome),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Generate My Routine'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drop({
    required String label,
    required IconData icon,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon),
      ),
      dropdownColor: const Color(0xFF1A1A2E),
      isExpanded: true,
      items: items.entries
          .map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value, overflow: TextOverflow.ellipsis, maxLines: 1),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
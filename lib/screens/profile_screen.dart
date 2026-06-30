import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profile;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await Api.get('/profile/get.php');
      profile = Map<String, dynamic>.from(data);
    } catch (_) {
      profile = null;
    }
    setState(() => loading = false);
  }

  static const _locationLabels = {
    'home': '🏠 Home',
    'gym':  '🏋️ Gym',
    'both': '🔄 Both',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF6C5CE7),
                child: Text(
                  (auth.userName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(auth.userName ?? 'User',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 24),
          _row('Height',   '${profile?['height_cm'] ?? '-'} cm',
              Icons.height),
          _row('Weight',   '${profile?['weight_kg'] ?? '-'} kg',
              Icons.monitor_weight_outlined),
          _row('Experience', profile?['experience'] ?? '-',
              Icons.bar_chart),
          _row('Split',    profile?['split_type'] ?? '-',
              Icons.splitscreen),
          _row('Goal',     profile?['goal'] ?? '-',
              Icons.flag_outlined),
          // NEW — workout location
          _row(
            'Location',
            _locationLabels[profile?['workout_location']] ??
                (profile?['workout_location'] ?? '-'),
            Icons.place_outlined,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/onboarding'),
            icon:  const Icon(Icons.edit),
            label: const Text('Edit Preferences'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
            icon:  const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF00CEC9)),
      title: Text(label),
      trailing: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );
}
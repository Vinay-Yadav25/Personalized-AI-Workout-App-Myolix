import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/progress_provider.dart';
import 'routine_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [
    RoutineScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadCurrent();
      context.read<ProgressProvider>().load();
    });
  }

  void _onTabSelected(int i) {
    setState(() => _index = i);
    if (i == 1) context.read<ProgressProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final routine = context.watch<RoutineProvider>();

    if (routine.justCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProgressProvider>().load();
        routine.justCompleted = false;
      });
    }

    // Routine tab (index 0) has its own header — hide shell AppBar for it
    final showAppBar = _index != 0;

    return Scaffold(
      // Only show AppBar for Progress and Profile tabs
      appBar: showAppBar
          ? AppBar(
        title: Text(_titleFor(_index)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'logout') {
                await auth.logout();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      )
          : null,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: const Color(0xFF6C5CE7).withOpacity(0.3),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Routine'),
          NavigationDestination(
              icon: Icon(Icons.show_chart), label: 'Progress'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  String _titleFor(int i) {
    switch (i) {
      case 1:  return 'My Progress';
      default: return 'Profile';
    }
  }
}
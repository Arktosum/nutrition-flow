import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';

void main() {
  runApp(const ProviderScope(child: NutritionFlowApp()));
}

class NutritionFlowApp extends StatelessWidget {
  const NutritionFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          surface: Color(0xFF1E1E1E),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const MainNavigationShell(),
    );
  }
}

// 1. The Modern Riverpod approach (Notifier)
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0; // Initial state is index 0

  void setIndex(int index) {
    state = index;
  }
}

// 2. The Provider for the Notifier
final bottomNavIndexProvider = NotifierProvider<NavIndexNotifier, int>(() {
  return NavIndexNotifier();
});

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Watch the state
    final currentIndex = ref.watch(bottomNavIndexProvider);

    final screens = [
      const Center(
        child: Text(
          'Dashboard Engine\n(Progress Rings Go Here)',
          textAlign: TextAlign.center,
        ),
      ),
      const Center(
        child: Text(
          'Logging Hub\n(Quick Add Buttons Go Here)',
          textAlign: TextAlign.center,
        ),
      ),
      const ProfileScreen()
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nutrition Flow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: screens[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        // 4. Update the state
        onDestinationSelected: (index) =>
            ref.read(bottomNavIndexProvider.notifier).setIndex(index),
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: const Color(0xFF00E676).withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

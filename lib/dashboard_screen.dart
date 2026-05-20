import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_screen.dart';

// --- 1. The State Model ---
class DailyIntake {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double waterLiters;

  DailyIntake({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.waterLiters = 0,
  });

  DailyIntake copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? waterLiters,
  }) {
    return DailyIntake(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      waterLiters: waterLiters ?? this.waterLiters,
    );
  }
}

// --- 2. The Modern Riverpod Provider ---
class IntakeNotifier extends Notifier<DailyIntake> {
  @override
  DailyIntake build() => DailyIntake();

  // We can use this to add water from the button!
  void addWater(double amount) {
    state = state.copyWith(waterLiters: state.waterLiters + amount);
  }
}

final intakeProvider = NotifierProvider<IntakeNotifier, DailyIntake>(() {
  return IntakeNotifier();
});

// --- 3. The UI Screen ---
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final intake = ref.watch(intakeProvider);
    final intakeNotifier = ref.read(intakeProvider.notifier);

    // Calculate percentages (clamped so the rings don't break if you overeat)
    double calPercent = profile.targetCalories > 0
        ? (intake.calories / profile.targetCalories).clamp(0.0, 1.0)
        : 0.0;
    double proPercent = profile.proteinTarget > 0
        ? (intake.protein / profile.proteinTarget).clamp(0.0, 1.0)
        : 0.0;
    double carbPercent = profile.carbsTarget > 0
        ? (intake.carbs / profile.carbsTarget).clamp(0.0, 1.0)
        : 0.0;
    double fatPercent = profile.fatsTarget > 0
        ? (intake.fats / profile.fatsTarget).clamp(0.0, 1.0)
        : 0.0;
    double waterPercent = profile.hydrationTarget > 0
        ? (intake.waterLiters / profile.hydrationTarget).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.goal,
            style: const TextStyle(fontSize: 16, color: Color(0xFF00E676)),
          ),
          const SizedBox(height: 30),

          // THE HERO CALORIE RING
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 16,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: calPercent,
                    strokeWidth: 16,
                    backgroundColor: Colors.transparent,
                    color: const Color(0xFF00E676),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(profile.targetCalories - intake.calories).toInt()}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'kcal left',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // MACROS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MacroRing(
                'Protein',
                intake.protein,
                profile.proteinTarget.toDouble(),
                proPercent,
                Colors.pinkAccent,
              ),
              _MacroRing(
                'Carbs',
                intake.carbs,
                profile.carbsTarget.toDouble(),
                carbPercent,
                Colors.amberAccent,
              ),
              _MacroRing(
                'Fats',
                intake.fats,
                profile.fatsTarget.toDouble(),
                fatPercent,
                Colors.purpleAccent,
              ),
            ],
          ),
          const SizedBox(height: 30),

          // HYDRATION CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.lightBlueAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: waterPercent,
                        strokeWidth: 6,
                        color: Colors.lightBlueAccent,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const Icon(
                      Icons.water_drop,
                      color: Colors.lightBlueAccent,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hydration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${intake.waterLiters.toStringAsFixed(1)} / ${profile.hydrationTarget.toStringAsFixed(1)} Liters',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // WORKING ADD WATER BUTTON!
                IconButton(
                  onPressed: () {
                    // Adds 250ml (0.25 L) of water each tap
                    intakeNotifier.addWater(0.25);
                  },
                  icon: const Icon(Icons.add_circle),
                  color: Colors.lightBlueAccent,
                  iconSize: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _MacroRing(
    String label,
    double consumed,
    double target,
    double percent,
    Color color,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 8,
                backgroundColor: Colors.transparent,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${consumed.toInt()}g',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '/${target.toInt()}g',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

// --- 1. The State Model & Math Engine ---
class ProfileState {
  final int age;
  final double height;
  final double weight;
  final String gender;
  final double activityMultiplier;
  final String goal;

  ProfileState({
    this.age = 25,
    this.height = 175,
    this.weight = 70,
    this.gender = 'Male',
    this.activityMultiplier = 1.2,
    this.goal = 'Maintain',
  });

  ProfileState copyWith({
    int? age,
    double? height,
    double? weight,
    String? gender,
    double? activityMultiplier,
    String? goal,
  }) {
    return ProfileState(
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      activityMultiplier: activityMultiplier ?? this.activityMultiplier,
      goal: goal ?? this.goal,
    );
  }

  double get bmr {
    double base = (10 * weight) + (6.25 * height) - (5 * age);
    return gender == 'Male' ? base + 5 : base - 161;
  }

  double get maintenanceCalories => bmr * activityMultiplier;

  double get targetCalories {
    if (goal == 'Lose Fat') return maintenanceCalories - 500;
    if (goal == 'Build Muscle') return maintenanceCalories + 300;
    return maintenanceCalories;
  }

  double get hydrationTarget {
    double baseLiters = weight * 0.035;
    double activityBump = (activityMultiplier - 1.2) * 1.5;
    return baseLiters + activityBump;
  }

  int get proteinTarget => (weight * 1.8).toInt();
  int get fatsTarget => ((targetCalories * 0.25) / 9).toInt();
  int get carbsTarget {
    double remainingCals =
        targetCalories - (proteinTarget * 4) - (fatsTarget * 9);
    return (remainingCals / 4).toInt();
  }

  double get bmi {
    if (height <= 0) return 0;
    double heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String get bmiCategory {
    final b = bmi;
    if (b <= 0) return 'Invalid';
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  String get idealWeightRange {
    if (height <= 0) return '-';
    double heightInMeters = height / 100;
    double minWeight = 18.5 * pow(heightInMeters, 2);
    double maxWeight = 24.9 * pow(heightInMeters, 2);
    return '${minWeight.toStringAsFixed(1)}-${maxWeight.toStringAsFixed(1)} kg';
  }
}

// --- 2. The Riverpod Provider ---
class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() => ProfileState();

  void updateField({
    int? age,
    double? height,
    double? weight,
    String? gender,
    double? activity,
    String? goal,
  }) {
    state = state.copyWith(
      age: age,
      height: height,
      weight: weight,
      gender: gender,
      activityMultiplier: activity,
      goal: goal,
    );
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  () => ProfileNotifier(),
);

// --- 3. The UI Screen ---
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);

    Color bmiColor = const Color(0xFF00E676);
    if (profile.bmiCategory == 'Underweight') bmiColor = Colors.blue;
    if (profile.bmiCategory == 'Overweight') bmiColor = Colors.orange;
    if (profile.bmiCategory == 'Obese') bmiColor = Colors.redAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARD 1: DAILY TARGETS
          const Text(
            'Daily Targets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E676).withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      context,
                      'Target Calories',
                      '${profile.targetCalories.toInt()} kcal',
                      const Color(0xFF00E676),
                      infoTitle: 'Calorie Target',
                      infoDesc:
                          'Based on your selected goal. This is your total daily maintenance (TDEE) adjusted for fat loss or muscle gain.',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade800,
                    ),
                    _StatColumn(
                      context,
                      'Hydration',
                      '${profile.hydrationTarget.toStringAsFixed(1)} L',
                      Colors.lightBlueAccent,
                      infoTitle: 'Hydration Target',
                      infoDesc:
                          'Calculated using 35ml per kg of bodyweight, dynamically increased based on your chosen physical activity level.',
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white12),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MacroColumn(
                      context,
                      'Protein',
                      '${profile.proteinTarget}g',
                      Colors.pinkAccent,
                      'Protects and builds muscle mass. Set to a highly optimal 1.8g per kg of body weight.',
                    ),
                    _MacroColumn(
                      context,
                      'Carbs',
                      '${profile.carbsTarget}g',
                      Colors.amberAccent,
                      'Your body\'s preferred energy source. Calculated using your remaining calories after Protein and Fats are set.',
                    ),
                    _MacroColumn(
                      context,
                      'Fats',
                      '${profile.fatsTarget}g',
                      Colors.purpleAccent,
                      'Crucial for hormone regulation and brain health. Set to safely make up 25% of your total calories.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CARD 2: BODY DIAGNOSTICS (Now fully matching theme!)
          const Text(
            'Body Diagnostics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E676).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _StatColumn(
                    context,
                    'BMR',
                    '${profile.bmr.toInt()}',
                    Colors.white70,
                    infoTitle: 'Basal Metabolic Rate (BMR)',
                    infoDesc:
                        'The calories your body burns just keeping you alive (organs, breathing). What you burn if you stayed in bed all day.',
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    context,
                    'BMI (${profile.bmiCategory})',
                    profile.bmi.toStringAsFixed(1),
                    bmiColor,
                    infoTitle: 'Body Mass Index (BMI)',
                    infoDesc:
                        'A ratio of your height to your weight. While it doesn\'t account for muscle mass, it is a baseline for assessing healthy brackets.',
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    context,
                    'Healthy Range',
                    profile.idealWeightRange,
                    Colors.white70,
                    infoTitle: 'Ideal Weight Range',
                    infoDesc:
                        'The weight bracket for your specific height that keeps your BMI in the "Normal" category (18.5 - 24.9).',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Goal Selection (Overflow and spacing fixed)
          const Text(
            'Primary Goal',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false, // Fixes the squishing/overflow bug!
              segments: const [
                ButtonSegment(
                  value: 'Lose Fat',
                  label: Text('Lose Fat', style: TextStyle(fontSize: 13)),
                ),
                ButtonSegment(
                  value: 'Maintain',
                  label: Text('Maintain', style: TextStyle(fontSize: 13)),
                ),
                ButtonSegment(
                  value: 'Build Muscle',
                  label: Text('Muscle', style: TextStyle(fontSize: 13)),
                ),
              ],
              selected: {profile.goal},
              onSelectionChanged: (set) =>
                  notifier.updateField(goal: set.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.transparent,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: const Color(0xFF00E676),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Compact Inputs: Row 1
          Row(
            children: [
              Expanded(
                child: _MetricInput('Age', profile.age.toString(), (val) {
                  notifier.updateField(age: int.tryParse(val) ?? 0);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GenderDropdown(
                  profile.gender,
                  (val) => notifier.updateField(gender: val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compact Inputs: Row 2
          Row(
            children: [
              Expanded(
                child: _MetricInput('Weight (kg)', profile.weight.toString(), (
                  val,
                ) {
                  notifier.updateField(weight: double.tryParse(val) ?? 0);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricInput('Height (cm)', profile.height.toString(), (
                  val,
                ) {
                  notifier.updateField(height: double.tryParse(val) ?? 0);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compact Inputs: Activity Level
          _ActivityDropdown(
            profile.activityMultiplier,
            (val) => notifier.updateField(activity: val),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // UI Helpers (Stat Columns & Inputs)
  Widget _StatColumn(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    String? infoTitle,
    String? infoDesc,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            if (infoTitle != null && infoDesc != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showInfoSheet(context, infoTitle, infoDesc),
                child: const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _MacroColumn(
    BuildContext context,
    String label,
    String value,
    Color color,
    String desc,
  ) {
    return GestureDetector(
      onTap: () => _showInfoSheet(context, '$label Target', desc),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 12, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String title, String description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _MetricInput(
    String label,
    String initialValue,
    Function(String) onChanged,
  ) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _GenderDropdown(String value, Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: const Color(0xFF1E1E1E),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
      ],
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }

  Widget _ActivityDropdown(double value, Function(double) onChanged) {
    return DropdownButtonFormField<double>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Activity Level',
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: const Color(0xFF1E1E1E),
      items: const [
        DropdownMenuItem(value: 1.2, child: Text('Sedentary (Office job)')),
        DropdownMenuItem(value: 1.375, child: Text('Light (1-3 days/wk)')),
        DropdownMenuItem(value: 1.55, child: Text('Moderate (3-5 days/wk)')),
        DropdownMenuItem(value: 1.725, child: Text('Active (6-7 days/wk)')),
      ],
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}

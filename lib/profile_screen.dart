import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

// --- 1. The State Model & Math Engine ---
// (Unchanged from before)
class ProfileState {
  final int age;
  final double height;
  final double weight;
  final String gender;
  final double activityMultiplier;

  ProfileState({
    this.age = 25,
    this.height = 175,
    this.weight = 70,
    this.gender = 'Male',
    this.activityMultiplier = 1.2,
  });

  ProfileState copyWith({
    int? age,
    double? height,
    double? weight,
    String? gender,
    double? activityMultiplier,
  }) {
    return ProfileState(
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      activityMultiplier: activityMultiplier ?? this.activityMultiplier,
    );
  }

  double get bmr {
    double base = (10 * weight) + (6.25 * height) - (5 * age);
    return gender == 'Male' ? base + 5 : base - 161;
  }

  double get maintenanceCalories => bmr * activityMultiplier;

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
    return '${minWeight.toStringAsFixed(1)} - ${maxWeight.toStringAsFixed(1)} kg';
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
  }) {
    state = state.copyWith(
      age: age,
      height: height,
      weight: weight,
      gender: gender,
      activityMultiplier: activity,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      context,
                      'Maintenance',
                      '${profile.maintenanceCalories.toInt()} kcal',
                      const Color(0xFF00E676),
                      infoTitle: 'Maintenance Calories (TDEE)',
                      infoDesc:
                          'Total Daily Energy Expenditure. This is the exact number of calories your body burns in a 24-hour period, including your physical activity. Eat this amount to stay exactly the same weight.',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade800,
                    ),
                    _StatColumn(
                      context,
                      'Base Burn',
                      '${profile.bmr.toInt()} kcal',
                      Colors.white,
                      infoTitle: 'Basal Metabolic Rate (BMR)',
                      infoDesc:
                          'The calories your body burns just keeping you alive (organs, breathing, brain function). This is what you would burn if you stayed in bed all day and did absolutely nothing.',
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white12),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      context,
                      'BMI (${profile.bmiCategory})',
                      profile.bmi.toStringAsFixed(1),
                      bmiColor,
                      infoTitle: 'Body Mass Index (BMI)',
                      infoDesc:
                          'A general mathematical ratio of your height to your weight. While it doesn\'t account for muscle mass, it is a universally used baseline for assessing healthy weight brackets.',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade800,
                    ),
                    _StatColumn(
                      context,
                      'Healthy Range',
                      profile.idealWeightRange,
                      Colors.white70,
                      infoTitle: 'Ideal Weight Range',
                      infoDesc:
                          'The weight bracket for your specific height that keeps your BMI in the "Normal" category (18.5 - 24.9).',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // ... (The rest of the form remains exactly the same)
          const Text(
            'Gender',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Male', label: Text('Male')),
              ButtonSegment(value: 'Female', label: Text('Female')),
            ],
            selected: {profile.gender},
            onSelectionChanged: (set) =>
                notifier.updateField(gender: set.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.transparent,
              selectedForegroundColor: Colors.black,
              selectedBackgroundColor: const Color(0xFF00E676),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _MetricInput('Age', profile.age.toString(), (val) {
                  notifier.updateField(age: int.tryParse(val) ?? 0);
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricInput('Weight (kg)', profile.weight.toString(), (
                  val,
                ) {
                  notifier.updateField(weight: double.tryParse(val) ?? 0);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MetricInput('Height (cm)', profile.height.toString(), (val) {
            notifier.updateField(height: double.tryParse(val) ?? 0);
          }),
          const SizedBox(height: 20),

          const Text(
            'Activity Level',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: profile.activityMultiplier,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E1E),
                items: const [
                  DropdownMenuItem(
                    value: 1.2,
                    child: Text('Sedentary (Little to no exercise)'),
                  ),
                  DropdownMenuItem(
                    value: 1.375,
                    child: Text('Lightly Active (1-3 days/week)'),
                  ),
                  DropdownMenuItem(
                    value: 1.55,
                    child: Text('Moderately Active (3-5 days/week)'),
                  ),
                  DropdownMenuItem(
                    value: 1.725,
                    child: Text('Very Active (6-7 days/week)'),
                  ),
                ],
                onChanged: (val) => notifier.updateField(activity: val),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // UPDATED Helper widget for the Hero Card (Now with Info Icon support)
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
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (infoTitle != null && infoDesc != null) ...[
              const SizedBox(width: 6),
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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // NEW: Premium Bottom Sheet for Definitions
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
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E676)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dashboard_screen.dart';

// --- 1. The Data Models ---
class FoodEntry {
  final String id;
  final String name;
  final String? description; // NEW: Holds the AI's explanation!
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final bool isFromApi;
  final bool isFromAi;

  FoodEntry({
    String? id,
    required this.name,
    this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.isFromApi = false,
    this.isFromAi = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

// --- 2. Live Riverpod Database ---
class FoodDatabaseNotifier extends Notifier<List<FoodEntry>> {
  @override
  List<FoodEntry> build() {
    return [
      FoodEntry(
        name: 'Egg (1 large)',
        calories: 70,
        protein: 6,
        carbs: 0,
        fats: 5,
      ),
      FoodEntry(
        name: 'Whole Wheat Bread (1 slice)',
        calories: 65,
        protein: 2.5,
        carbs: 12,
        fats: 1,
      ),
      FoodEntry(
        name: 'Chicken Biryani (100g)',
        calories: 160,
        protein: 8,
        carbs: 18,
        fats: 6,
      ),
      FoodEntry(
        name: 'Coffee (with Milk & Sugar)',
        calories: 80,
        protein: 3,
        carbs: 12,
        fats: 2,
      ),
      FoodEntry(
        name: 'Dosa (1 plain)',
        calories: 130,
        protein: 3,
        carbs: 23,
        fats: 3,
      ),
      FoodEntry(
        name: 'Gobi 65 (100g)',
        calories: 175,
        protein: 3,
        carbs: 17,
        fats: 10,
      ),
    ];
  }

  void saveFoodToDatabase(FoodEntry food) {
    if (!state.any((e) => e.name.toLowerCase() == food.name.toLowerCase())) {
      state = [food, ...state];
    }
  }
}

final foodDatabaseProvider =
    NotifierProvider<FoodDatabaseNotifier, List<FoodEntry>>(
      () => FoodDatabaseNotifier(),
    );

// --- 3. Live Daily Log ---
class MealLogNotifier extends Notifier<List<FoodEntry>> {
  @override
  List<FoodEntry> build() => [];

  void addEntry(FoodEntry entry) {
    state = [...state, entry];
  }

  void removeEntry(String id) {
    state = state.where((entry) => entry.id != id).toList();
  }
}

final mealLogProvider = NotifierProvider<MealLogNotifier, List<FoodEntry>>(
  () => MealLogNotifier(),
);

// --- 4. The UI Screen ---
class LoggingScreen extends ConsumerStatefulWidget {
  const LoggingScreen({super.key});

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoadingApi = false;
  List<FoodEntry> _apiResults = [];
  Timer? _debounce;

  // ==========================================
  // 🔴 PASTE YOUR GEMINI API KEY HERE 🔴
  // ==========================================
  final String _geminiApiKey = 'AIzaSyB-v6IYCzXvEVeg8FH9tpXmoHR7qWQAy28';

  // --- GEMINI AI INTEGRATION ---
  Future<FoodEntry?> _fetchFromGemini(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
            "generationConfig": {"responseMimeType": "application/json"},
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String rawJsonText = data['candidates'][0]['content']['parts'][0]['text'];
      rawJsonText = rawJsonText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> mealData = jsonDecode(rawJsonText);
      return FoodEntry(
        name: mealData['name'] ?? 'Custom AI Meal',
        description: mealData['description'], // NEW: Grab the description
        calories: _parseDouble(mealData['calories']),
        protein: _parseDouble(mealData['protein']),
        carbs: _parseDouble(mealData['carbs']),
        fats: _parseDouble(mealData['fats']),
        isFromAi: true,
      );
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error']['message'] ?? 'API Error ${response.statusCode}',
      );
    }
  }

  // Generate Initial AI Meal (Updated Prompt)
  Future<FoodEntry?> _generateAiMeal(String mealDescription) {
    final prompt =
        "Analyze this meal and return ONLY a valid JSON object. Do not include markdown formatting. The JSON keys MUST be exactly: 'name' (string), 'description' (string, a brief 1-sentence explanation of what you think this food is to prove you understood it), 'calories' (number), 'protein' (number), 'carbs' (number), 'fats' (number). The meal is: $mealDescription";
    return _fetchFromGemini(prompt);
  }

  // Interrogate/Audit AI Meal (Updated Prompt)
  Future<FoodEntry?> _interrogateAiMeal(FoodEntry food) {
    final prompt =
        "You are a strict nutrition auditor. I previously generated macros for a meal named '${food.name}'. The estimated values were: ${food.calories} kcal, ${food.protein}g protein, ${food.carbs}g carbs, ${food.fats}g fats. Please double-check these values. If they are hallucinated or absurd, correct them. Return ONLY a valid JSON object with keys: 'name', 'description' (a brief 1-sentence explanation of the food), 'calories', 'protein', 'carbs', 'fats'. No markdown.";
    return _fetchFromGemini(prompt);
  }

  // --- API CALL (OpenFoodFacts) ---
  Future<void> _searchApi(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _apiResults = [];
      });
      return;
    }
    setState(() {
      _isLoadingApi = true;
    });
    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=10&sort_by=unique_scans_n',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final products = data['products'] as List;
        List<FoodEntry> fetchedFoods = [];
        for (var p in products) {
          String name = p['product_name']?.toString() ?? '';
          final brand = p['brands']?.toString() ?? '';
          final nutriments = p['nutriments'];
          if (name.isNotEmpty && nutriments != null) {
            if (brand.isNotEmpty &&
                !name.toLowerCase().contains(brand.toLowerCase()))
              name = '$brand $name';
            final cals = _parseDouble(nutriments['energy-kcal_100g']);
            final pro = _parseDouble(nutriments['proteins_100g']);
            final carb = _parseDouble(nutriments['carbohydrates_100g']);
            final fat = _parseDouble(nutriments['fat_100g']);
            if (cals > 0)
              fetchedFoods.add(
                FoodEntry(
                  name: '$name (100g)',
                  calories: cals,
                  protein: pro,
                  carbs: carb,
                  fats: fat,
                  isFromApi: true,
                ),
              );
          }
        }
        setState(() {
          _apiResults = fetchedFoods;
        });
      }
    } catch (e) {
      debugPrint('API Error: $e');
    } finally {
      if (mounted)
        setState(() {
          _isLoadingApi = false;
        });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // --- UI: MAGIC AI INPUT SHEET ---
  void _showAiInputSheet() {
    final aiController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isAnalyzing = false;
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF00E676)),
                      SizedBox(width: 10),
                      Text(
                        'Magic AI Log',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Describe exactly what you ate.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: aiController,
                    maxLines: 3,
                    enabled: !isAnalyzing,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. "I had a bonda"',
                      hintStyle: TextStyle(color: Colors.grey.shade700),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: isAnalyzing
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00E676),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () async {
                              if (aiController.text.isEmpty) return;
                              setSheetState(() {
                                isAnalyzing = true;
                                errorMessage = null;
                              });
                              try {
                                final food = await _generateAiMeal(
                                  aiController.text,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  if (food != null) _showQuantitySheet(food);
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isAnalyzing = false;
                                  errorMessage = e
                                      .toString()
                                      .replaceAll('Exception:', '')
                                      .trim();
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.auto_awesome,
                              color: Colors.black,
                            ),
                            label: const Text(
                              'Analyze Meal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- UI: OVERHAULED QUANTITY & SAVE SHEET ---
  void _showQuantitySheet(FoodEntry initialFood) {
    FocusScope.of(context).unfocus();
    double multiplier = 1.0;
    FoodEntry currentFood = initialFood;
    bool isSaved = false;
    bool isAuditing = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final double previewCals = currentFood.calories * multiplier;
            final double previewPro = currentFood.protein * multiplier;
            final double previewCarb = currentFood.carbs * multiplier;
            final double previewFat = currentFood.fats * multiplier;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    currentFood.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (currentFood.isFromAi)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: Color(0xFF00E676),
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Base: ${currentFood.calories.toInt()} kcal per unit',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (currentFood.isFromAi || currentFood.isFromApi)
                        isSaved
                            ? const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF00E676),
                                      size: 20,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Saved',
                                      style: TextStyle(
                                        color: Color(0xFF00E676),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : TextButton.icon(
                                onPressed: () {
                                  ref
                                      .read(foodDatabaseProvider.notifier)
                                      .saveFoodToDatabase(currentFood);
                                  setSheetState(() => isSaved = true);
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Saved to My Foods!'),
                                      backgroundColor: Colors.blueAccent,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.bookmark_add_outlined,
                                  color: Colors.blueAccent,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.blueAccent),
                                ),
                              ),
                    ],
                  ),

                  // NEW: AI Description Display
                  if (currentFood.description != null &&
                      currentFood.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.psychology,
                            color: Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI thinks: "${currentFood.description}"',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Text(
                        'Servings:',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Color(0xFF00E676),
                        ),
                        onPressed: () {
                          if (multiplier > 0.5)
                            setSheetState(() => multiplier -= 0.5);
                        },
                      ),
                      Text(
                        multiplier.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF00E676),
                        ),
                        onPressed: () {
                          setSheetState(() => multiplier += 0.5);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMacroPill(
                          'Calories',
                          previewCals,
                          Colors.white,
                          'kcal',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade800,
                        ),
                        _buildMacroPill(
                          'Protein',
                          previewPro,
                          Colors.pinkAccent,
                          'g',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade800,
                        ),
                        _buildMacroPill(
                          'Carbs',
                          previewCarb,
                          Colors.amberAccent,
                          'g',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade800,
                        ),
                        _buildMacroPill(
                          'Fats',
                          previewFat,
                          Colors.purpleAccent,
                          'g',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (currentFood.isFromAi) ...[
                    Center(
                      child: isAuditing
                          ? const CircularProgressIndicator(
                              color: Colors.orangeAccent,
                            )
                          : TextButton.icon(
                              onPressed: () async {
                                setSheetState(() => isAuditing = true);
                                try {
                                  final updatedFood = await _interrogateAiMeal(
                                    currentFood,
                                  );
                                  if (updatedFood != null) {
                                    setSheetState(() {
                                      currentFood = updatedFood;
                                      isAuditing = false;
                                    });
                                  }
                                } catch (e) {
                                  setSheetState(() => isAuditing = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Audit failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.policy_outlined,
                                color: Colors.orangeAccent,
                                size: 18,
                              ),
                              label: const Text(
                                'Looks wrong? Double check AI.',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logFood(currentFood, multiplier);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log Meal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMacroPill(String label, double val, Color color, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          '${val.toInt()}$unit',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _logFood(FoodEntry baseFood, double multiplier) {
    final cals = baseFood.calories * multiplier;
    final pro = baseFood.protein * multiplier;
    final carb = baseFood.carbs * multiplier;
    final fat = baseFood.fats * multiplier;
    String finalName = multiplier == 1.0
        ? baseFood.name
        : '${baseFood.name} (x$multiplier)';

    final finalFood = FoodEntry(
      name: finalName,
      description: baseFood.description,
      calories: cals,
      protein: pro,
      carbs: carb,
      fats: fat,
      isFromAi: baseFood.isFromAi,
    );

    ref.read(intakeProvider.notifier).addMeal(cals, pro, carb, fat);
    ref.read(mealLogProvider.notifier).addEntry(finalFood);

    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _apiResults = [];
    });
  }

  // --- The Build Method ---
  @override
  Widget build(BuildContext context) {
    final mealHistory = ref.watch(mealLogProvider);
    final myFoodDatabase = ref.watch(foodDatabaseProvider);
    final bool isSearching = _searchQuery.isNotEmpty;

    final localResults = myFoodDatabase.where((food) {
      return food.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log Meal',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 600),
                      () => _searchApi(value),
                    );
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search food...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF00E676),
                    ),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _apiResults = [];
                              });
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00E676).withOpacity(0.5),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF00E676),
                  ),
                  onPressed: _showAiInputSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isSearching
                ? _buildCombinedSearchResults(localResults)
                : _buildMealHistory(mealHistory),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedSearchResults(List<FoodEntry> localResults) {
    return ListView(
      children: [
        if (localResults.isNotEmpty) ...[
          const Text(
            'My Foods',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...localResults.map((food) => _buildFoodCard(food)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Global Database',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            if (_isLoadingApi)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E676),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_apiResults.isEmpty && !_isLoadingApi && _searchQuery.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Type a specific brand to search the web.',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ),
        ..._apiResults.map((food) => _buildFoodCard(food)),
      ],
    );
  }

  Widget _buildFoodCard(FoodEntry food) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(
                food.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (food.isFromApi)
              const Icon(Icons.cloud_outlined, size: 16, color: Colors.grey),
          ],
        ),
        subtitle: Text(
          '${food.calories.toInt()} kcal • ${food.protein.toInt()}g Pro',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.add_circle,
          color: Color(0xFF00E676),
          size: 28,
        ),
        onTap: () => _showQuantitySheet(food),
      ),
    );
  }

  Widget _buildMealHistory(List<FoodEntry> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Log',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Nothing logged yet today.\nTap the ✨ to describe your meal!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final food = history[index];
                return Dismissible(
                  key: Key(food.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    ref.read(mealLogProvider.notifier).removeEntry(food.id);
                    ref
                        .read(intakeProvider.notifier)
                        .removeMeal(
                          food.calories,
                          food.protein,
                          food.carbs,
                          food.fats,
                        );
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${food.name} deleted'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      food.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (food.isFromAi) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: Color(0xFF00E676),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${food.protein.toInt()}g P • ${food.carbs.toInt()}g C • ${food.fats.toInt()}g F',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${food.calories.toInt()} kcal',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

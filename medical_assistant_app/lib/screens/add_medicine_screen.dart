import 'dart:async';
import 'package:flutter/material.dart';
import 'package:medicine_reminder/models/medicine.dart';
import 'package:medicine_reminder/widgets/large_button.dart';
import 'package:medicine_reminder/widgets/times_per_day_picker.dart';
import 'package:medicine_reminder/screens/interaction_warning_screen.dart';
import 'package:medicine_reminder/repositories/medicine_repository.dart';
import 'package:medicine_reminder/services/dailymed_service.dart';
import 'package:medicine_reminder/services/interaction_service.dart';
import 'package:medicine_reminder/services/rxnorm_service.dart';
import 'package:medicine_reminder/services/stt_service.dart';

import 'package:intl/intl.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine;

  const AddMedicineScreen({
    super.key,
    this.medicine,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  late final bool _isEditMode;
  late final String _medicineId;
  @override
void initState() {
  super.initState();

  if (widget.medicine != null) {
    _isEditMode = true;
    final m = widget.medicine!;
    _medicineId = m.id;

    _nameController.text = m.name;
    _dosageController.text = m.dosage;
    _notesController.text = m.notes ?? '';
    _selectedType = m.type;
    _startDate = m.startDate;
    _endDate = m.endDate;
    _selectedTimes = m.reminderTimes
        .map(_minutesToTimeOfDay)
        .toList();

    _selectedDays = _daysOfWeek
        .map((day) => m.daysOfWeek.contains(day))
        .toList();
    _selectedRxcui = m.rxcui;
    _selectedNormalizedName = m.normalizedName;
    _selectedIngredientRxcuis = (m.ingredientRxcui ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    _selectedDailymedSetid = m.dailymedSetid;
  } else {
    _isEditMode = false;
    _medicineId = DateTime.now().millisecondsSinceEpoch.toString();
    _selectedTimes = const [TimeOfDay(hour: 8, minute: 0)];
  }

  if (_selectedRxcui != null &&
      (_selectedIngredientRxcuis.isEmpty || _selectedDailymedSetid == null)) {
    _enrichSelectedRxCuiMetadata();
  }
}


  final _formKey = GlobalKey<FormState>();
  final SttService _sttService = SttService();
  final RxNormService _rxNormService = RxNormService();
  final DailyMedService _dailyMedService = DailyMedService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // RxNorm search state
  Timer? _debounceTimer;
  List<Map<String, String>> _rxNormSuggestions = [];
  bool _isSearching = false;
  String? _selectedRxcui;
  String? _selectedNormalizedName;
  List<String> _selectedIngredientRxcuis = [];
  String? _selectedDailymedSetid;
  
  String _selectedType = 'Tablet';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  List<TimeOfDay> _selectedTimes = [];
  final List<String> _daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<bool> _selectedDays = List.filled(7, true);
  
  final List<String> _medicineTypes = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Drops',
    'Inhaler',
    'Cream',
    'Other'
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _rxNormService.dispose();
    _dailyMedService.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    // Clear previous selection when user types a new name
    _selectedRxcui = null;
    _selectedNormalizedName = null;
    _selectedIngredientRxcuis = [];
    _selectedDailymedSetid = null;

    _debounceTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _rxNormSuggestions = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await _rxNormService.searchRxCuiByName(value);
      if (mounted) {
        setState(() {
          _rxNormSuggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectRxNormSuggestion(Map<String, String> suggestion) {
    setState(() {
      _selectedRxcui = suggestion['rxcui'];
      _selectedNormalizedName = suggestion['name'];
      _nameController.text = suggestion['name'] ?? _nameController.text;
      _selectedIngredientRxcuis = [];
      _selectedDailymedSetid = null;
      _rxNormSuggestions = [];
    });
    _enrichSelectedRxCuiMetadata();
  }

  Future<void> _enrichSelectedRxCuiMetadata() async {
    final rxcui = _selectedRxcui?.trim();
    if (rxcui == null || rxcui.isEmpty) return;

    final ingredients = await _rxNormService.getIngredients(rxcui);
    final setId = await _dailyMedService.getSetIdByRxcui(rxcui);
    if (!mounted) return;

    setState(() {
      _selectedIngredientRxcuis = ingredients;
      _selectedDailymedSetid = setId;
    });
  }

  Future<void> _selectDate(bool isStartDate) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = isStartDate ? _startDate : _endDate;
    final normalizedInitial = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    final firstAllowedDate =
        normalizedInitial.isBefore(today) ? normalizedInitial : today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: normalizedInitial,
      firstDate: firstAllowedDate,
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _saveMedicine() async {
  if (_formKey.currentState!.validate()) {
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one reminder time'),
        ),
      );
      return;
    }

    // Check for interactions using merged RxNorm + local logic
    final repository = MedicineRepository();
    final interactionService = InteractionService();

    // Build a temporary Medicine to check against
    final tempMedicine = Medicine(
      id: '',
      name: _nameController.text,
      dosage: _dosageController.text,
      type: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      reminderTimes: [],
      daysOfWeek: [],
      rxcui: _selectedRxcui,
      ingredientRxcui: _selectedIngredientRxcuis.join(','),
    );

    final existingMedicines = await repository.getActiveMedicines();
    final warnings = await interactionService.checkInteractions(
      newMedicine: tempMedicine,
      existingMedicines: existingMedicines,
    );
    if (!mounted) return;

    if (warnings.isNotEmpty) {
      final proceed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => InteractionWarningScreen(
            medicineName: _nameController.text,
            warnings: warnings,
          ),
        ),
      ) ?? false;
      if (!proceed) return;
    }

    final String medicineId = _isEditMode
        ? _medicineId
        : DateTime.now().millisecondsSinceEpoch.toString();

    final sortedSelectedTimes = List<TimeOfDay>.from(_selectedTimes)
      ..sort(_compareTimeOfDay);

    final medicine = Medicine(
      id: medicineId,
      name: _nameController.text,
      dosage: _dosageController.text,
      type: _selectedType,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      startDate: _startDate,
      endDate: _endDate,
      reminderTimes: sortedSelectedTimes.map(_timeOfDayToMinutes).toList(),
      daysOfWeek: _daysOfWeek
          .asMap()
          .entries
          .where((entry) => _selectedDays[entry.key])
          .map((entry) => entry.value)
          .toList(),
      rxcui: _selectedRxcui,
      normalizedName: _selectedNormalizedName,
      ingredientRxcui: _selectedIngredientRxcuis.join(','),
      dailymedSetid: _selectedDailymedSetid,
    );

    bool saveSucceeded = true;
    try {
      if (_isEditMode) {
        final oldMedicine =
          await repository.getMedicineWithReminders(widget.medicine!.id);
          debugPrint('--- EDIT MODE DEBUG ---');
          debugPrint('Old medicine ID: ${oldMedicine.id}');
          debugPrint('Old reminderTimes: ${oldMedicine.reminderTimes}');
          debugPrint('Old daysOfWeek: ${oldMedicine.daysOfWeek}');
          debugPrint('----------------------');
        await repository.updateMedicine(
          oldMedicine: oldMedicine,
          updatedMedicine: medicine,
        );
      } else {
        await repository.insertMedicine(medicine);
      }
    } catch (e) {
      saveSucceeded = false;
      debugPrint('Error saving medicine: $e');
    }

    if (!mounted) return;

    if (!saveSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save medicine. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditMode
              ? 'Medicine updated successfully!'
              : 'Medicine added successfully!',
        ),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }
}

  static int _timeOfDayToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay _minutesToTimeOfDay(int minutes) => TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      );

  static int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final aMinutes = _timeOfDayToMinutes(a);
    final bMinutes = _timeOfDayToMinutes(b);
    return aMinutes.compareTo(bMinutes);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Medicine' : 'Add Medicine',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Medicine Name with RxNorm debounced search
                TextFormField(
                  controller: _nameController,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText: 'Medicine Name',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.medication),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _selectedRxcui != null
                            ? const Icon(Icons.verified, color: Colors.green)
                            : null,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                // RxNorm suggestions dropdown
                if (_rxNormSuggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).cardColor,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _rxNormSuggestions.length,
                      itemBuilder: (context, index) {
                        final s = _rxNormSuggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(s['name'] ?? ''),
                          subtitle: Text(
                            '${s['tty']} · RxCUI: ${s['rxcui']}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          onTap: () => _selectRxNormSuggestion(s),
                        );
                      },
                    ),
                  ),
                if (_selectedRxcui == null && _nameController.text.isNotEmpty && !_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Unverified — no RxCUI match selected',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),
                
                // Voice Input Button
                LargeButton(
                  text: 'Voice Input',
                  icon: Icons.mic,
                  onPressed: () async {
                    final result = await _sttService.speechToText();
                    if (result != null && result.isNotEmpty) {
                      _nameController.text = result;
                      _onNameChanged(result);
                    } else {
                      if (!context.mounted) return;
                      final message = _sttService.lastSttError ??
                          'Could not capture voice input. Please try again.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  backgroundColor: Colors.orange,
                ),
                const SizedBox(height: 20),
                 
                // Dosage
                TextFormField(
                  controller: _dosageController,
                  decoration: InputDecoration(
                    labelText: 'Dosage (e.g., 500mg)',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.line_weight),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter dosage';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Medicine Type
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Medicine Type',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  items: _medicineTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_startDate),
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_endDate),
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Days of Week
                Text(
                  'Days to Remind',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    return ChoiceChip(
                      label: Text(_daysOfWeek[index]),
                      selected: _selectedDays[index],
                      onSelected: (selected) {
                        setState(() {
                          _selectedDays[index] = selected;
                        });
                      },
                      selectedColor: Colors.blue,
                      labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _selectedDays[index] ? Colors.white : Colors.black,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                
                // Reminder Times
                TimesPerDayPicker(
                  initialTimes: _selectedTimes,
                  onChanged: (times) {
                    setState(() {
                      _selectedTimes = times;
                    });
                  },
                ),
                const SizedBox(height: 20),
                
                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 30),
                
                // Save Button
                LargeButton(
                  text: 'Save Medicine',
                  icon: Icons.save,
                  onPressed: _saveMedicine,
                  backgroundColor: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

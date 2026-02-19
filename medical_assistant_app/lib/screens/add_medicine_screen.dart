import 'package:flutter/material.dart';
import 'package:medicine_reminder/models/medicine.dart';
import 'package:medicine_reminder/widgets/large_button.dart';
import 'package:medicine_reminder/screens/interaction_warning_screen.dart';
import 'package:medicine_reminder/repositories/medicine_repository.dart';
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
    _selectedTimes = List.from(m.reminderTimes);

    _selectedDays = _daysOfWeek
        .map((day) => m.daysOfWeek.contains(day))
        .toList();
  } else {
    _isEditMode = false;
    _medicineId = DateTime.now().millisecondsSinceEpoch.toString();
  }
}


  final _formKey = GlobalKey<FormState>();
  final SttService _sttService = SttService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  String _selectedType = 'Tablet';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  List<int> _selectedTimes = [];
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
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final selectedMinutes = picked.hour * 60 + picked.minute;
      if (_selectedTimes.contains(selectedMinutes)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That reminder time is already added'),
          ),
        );
        return;
      }
      setState(() {
        _selectedTimes.add(selectedMinutes);
        _selectedTimes.sort();
      });
    }
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

    // Check for interactions
    final interactions =
        MedicineInteraction.checkInteractions(_nameController.text);

    if (interactions.isNotEmpty) {
      final proceed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => InteractionWarningScreen(
            medicineName: _nameController.text,
            conflictingMedicines: interactions,
          ),
        ),
      ) ?? false;
      if (!proceed) return;
    }

    // Use existing ID in edit mode, new ID in add mode
    final String medicineId = _isEditMode
        ? _medicineId
        : DateTime.now().millisecondsSinceEpoch.toString();

    final medicine = Medicine(
      id: medicineId,
      name: _nameController.text,
      dosage: _dosageController.text,
      type: _selectedType,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      startDate: _startDate,
      endDate: _endDate,
      reminderTimes: _selectedTimes,
      daysOfWeek: _daysOfWeek
          .asMap()
          .entries
          .where((entry) => _selectedDays[entry.key])
          .map((entry) => entry.value)
          .toList(),
    );

    final repository = MedicineRepository();

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
                // Medicine Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Medicine Name',
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.medication),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
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
                Text(
                  'Reminder Times',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                LargeButton(
                  text: 'Add Reminder Time',
                  icon: Icons.access_time,
                  onPressed: _selectTime,
                ),
                const SizedBox(height: 10),
                ..._selectedTimes.map((time) {
                  final hour = time ~/ 60;
                  final minute = time % 60;
                  final period = hour >= 12 ? 'PM' : 'AM';
                  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                  return ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      '$displayHour:${minute.toString().padLeft(2, '0')} $period',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _selectedTimes.remove(time);
                        });
                      },
                    ),
                  );
                }).toList(),
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

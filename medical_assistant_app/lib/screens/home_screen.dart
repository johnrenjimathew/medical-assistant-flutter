import 'package:flutter/material.dart';
import 'package:medicine_reminder/widgets/medicine_card.dart';
import 'package:medicine_reminder/screens/add_medicine_screen.dart';
import 'package:medicine_reminder/screens/history_screen.dart';
import 'package:medicine_reminder/screens/medicine_detail_screen.dart';
import 'package:medicine_reminder/screens/settings_screen.dart';
import 'package:medicine_reminder/models/medicine.dart';
import 'package:medicine_reminder/repositories/medicine_repository.dart';
import 'package:medicine_reminder/services/notification_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
 const HomeScreen({super.key});

 @override
 State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
 List<Medicine> medicines = [];
 final MedicineRepository _repository = MedicineRepository();

 @override
 void initState() {
   super.initState();
   _loadMedicines();
   _checkPermissions();
 }
 Future<void> _checkPermissions() async {
   final notificationService = NotificationService();
   await notificationService.requestExactAlarmPermission();
 }

  Future<void> _loadMedicines() async {
   final data = await _repository.getActiveMedicines();
   final now = DateTime.now();
   final today = DateTime(now.year, now.month, now.day);
   final todayShort = DateFormat('EEE').format(today);
   final todaysMedicines = data.where((medicine) {
     final startDate = DateTime(
       medicine.startDate.year,
       medicine.startDate.month,
       medicine.startDate.day,
     );
     return !startDate.isAfter(today) &&
         medicine.daysOfWeek.contains(todayShort);
   }).toList();

   if (!mounted) return;

   setState(() {
     medicines = todaysMedicines;
   });
  }

 Future<void> _deleteMedicine(Medicine medicine) async {
   final confirmed = await showDialog<bool>(
     context: context,
     builder: (context) => AlertDialog(
       title: const Text('Delete Medicine'),
       content: Text(
         'Are you sure you want to delete "${medicine.name}"?',
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context, false),
           child: const Text('Cancel'),
         ),
         TextButton(
           onPressed: () => Navigator.pop(context, true),
           child: const Text(
             'Delete',
             style: TextStyle(color: Colors.red),
           ),
         ),
       ],
     ),
   );

   if (confirmed == true) {
     await _repository.deleteMedicine(medicine);
     _loadMedicines();

     if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('Medicine deleted'),
         backgroundColor: Colors.red,
       ),
     );
   }
 }

 String _getGreeting() {
   final hour = DateTime.now().hour;
   if (hour < 12) return 'Good Morning!';
   if (hour < 17) return 'Good Afternoon!';
   return 'Good Evening!';
 }

 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: Text(
         'Medicine Reminder',
         style: Theme.of(context).textTheme.displayMedium,
       ),
        actions: [
         IconButton(
           onPressed: () {
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (_) => const HistoryScreen(),
               ),
             );
           },
           icon: const Icon(Icons.history, size: 30),
           tooltip: 'History',
         ),
         IconButton(
           onPressed: () {
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (_) => const SettingsScreen(),
               ),
             );
           },
           icon: const Icon(Icons.settings, size: 30),
           tooltip: 'Settings',
         ),
       ],
     ),
     body: SafeArea(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               _getGreeting(),
               style: Theme.of(context).textTheme.displayLarge?.copyWith(
                     color: Colors.blue,
                   ),
             ),
             const SizedBox(height: 8),
             Text(
               'Today: ${DateFormat('EEEE, MMMM d').format(DateTime.now())}',
               style: Theme.of(context).textTheme.bodyLarge,
             ),
             const SizedBox(height: 24),
             Text(
               'Today\'s Medicines',
               style: Theme.of(context).textTheme.displayMedium,
             ),
             const SizedBox(height: 16),
             Expanded(
               child: medicines.isEmpty
                   ? Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(
                             Icons.medication_liquid,
                             size: 80,
                             color: Colors.grey[400],
                           ),
                           const SizedBox(height: 16),
                           Text(
                             'No medicines scheduled',
                             style: Theme.of(context).textTheme.bodyLarge,
                           ),
                           const SizedBox(height: 8),
                           Text(
                             'Add your first medicine to get started',
                             style: Theme.of(context).textTheme.bodyMedium,
                           ),
                         ],
                       ),
                     )
                   : ListView.builder(
                       itemCount: medicines.length,
                       itemBuilder: (context, index) {
                         final medicine = medicines[index];
                         return MedicineCard(
                           medicine: medicine,

                           // TAP to view details
                           onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => MedicineDetailScreen(
                                   medicine: medicine,
                                 ),
                               ),
                             );
                           },

                           // EDIT
                           onEdit: () async {
                             await Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => AddMedicineScreen(
                                   medicine: medicine,
                                 ),
                               ),
                             );


                             await _loadMedicines();
                           },

                           // DELETE
                           onLongPress: () => _deleteMedicine(medicine),
                         );

                       },
                     ),
             ),
             const SizedBox(height: 20),
             SizedBox(
                width: double.infinity, 
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddMedicineScreen(),
                      ),
                    );
                    _loadMedicines();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), 
                    ),
                    elevation: 2, 
                  ),
                  icon: const Icon(Icons.add, size: 28),
                  label: const Text(
                    'Add New Medicine',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), 
           ],
         ),
       ),
     ),
   );
 }
}

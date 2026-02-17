import 'package:flutter/material.dart';
import 'package:medicine_reminder/widgets/large_button.dart';

class InteractionWarningScreen extends StatelessWidget {
  final String medicineName;
  final List<String> conflictingMedicines;

  const InteractionWarningScreen({
    super.key,
    required this.medicineName,
    required this.conflictingMedicines,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Interaction Warning',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 20),
              Text(
                'Potential Interaction Detected!',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$medicineName may interact with:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              ...conflictingMedicines.map((medicine) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        medicine,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Warning:',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Taking these medicines together may cause adverse effects. '
                      'Please consult your doctor or pharmacist before proceeding.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              LargeButton(
                text: 'I Understand, Continue Anyway',
                icon: Icons.arrow_forward,
                onPressed: () {
                  Navigator.pop(context, true);
                },
                backgroundColor: Colors.orange,
              ),
              const SizedBox(height: 10),
              LargeButton(
                text: 'Cancel and Edit',
                icon: Icons.edit,
                onPressed: () {
                  Navigator.pop(context, false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

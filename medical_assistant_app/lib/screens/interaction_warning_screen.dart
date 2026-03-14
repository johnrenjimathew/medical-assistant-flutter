import 'package:flutter/material.dart';
import 'package:medicine_reminder/widgets/large_button.dart';
import 'package:medicine_reminder/services/interaction_service.dart';

class InteractionWarningScreen extends StatelessWidget {
  final String medicineName;
  final List<InteractionWarning> warnings;

  const InteractionWarningScreen({
    super.key,
    required this.medicineName,
    required this.warnings,
  });

  Color _severityColor(String severity) {
    switch (severity) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.orange;
      case 'Local':
        return Colors.amber.shade700;
      case 'Unknown':
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'High':
        return Icons.error;
      case 'Low':
        return Icons.warning_amber_rounded;
      case 'Local':
        return Icons.info_outline;
      case 'Unknown':
      default:
        return Icons.help_outline;
    }
  }

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
                '$medicineName may have interactions:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: warnings.length,
                  itemBuilder: (context, index) {
                    final warning = warnings[index];
                    final color = _severityColor(warning.severity);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _severityIcon(warning.severity),
                              color: color,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          warning.severity,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Source: ${warning.source}',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    warning.description,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 16),
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

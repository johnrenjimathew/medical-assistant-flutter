import 'package:flutter/material.dart';
import 'package:medicine_reminder/models/medicine.dart';
import 'package:medicine_reminder/repositories/medicine_repository.dart';
import 'package:medicine_reminder/services/dailymed_service.dart';
import 'package:intl/intl.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;

  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final MedicineRepository _repository = MedicineRepository();
  DrugInfo? _drugInfo;
  bool _isLoading = true;
  final Set<String> _sectionsShowingFullText = <String>{};

  @override
  void initState() {
    super.initState();
    _loadDrugInfo();
  }

  Future<void> _loadDrugInfo() async {
    if (widget.medicine.rxcui != null && widget.medicine.rxcui!.isNotEmpty) {
      final info = await _repository.getDrugInfo(widget.medicine.rxcui!);
      if (mounted) {
        setState(() {
          _drugInfo = info;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final medicine = widget.medicine;
    final isVerified = medicine.rxcui != null && medicine.rxcui!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          medicine.name,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status badge
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.warning_amber_rounded,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isVerified
                      ? 'Verified (RxCUI: ${medicine.rxcui})'
                      : 'Unverified — No RxCUI',
                  style: TextStyle(
                    color: isVerified ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Basic Info
            _infoRow(context, 'Dosage', medicine.dosage),
            _infoRow(context, 'Type', medicine.type),
            _infoRow(context, 'Duration',
                '${DateFormat('MMM d, yyyy').format(medicine.startDate)} — ${DateFormat('MMM d, yyyy').format(medicine.endDate)}'),
            if (medicine.notes != null && medicine.notes!.isNotEmpty)
              _infoRow(context, 'Notes', medicine.notes!),

            const SizedBox(height: 8),
            Text(
              'Reminder Times',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: medicine.reminderTimes.map((t) {
                return Chip(
                  avatar: const Icon(Icons.access_time, size: 16),
                  label: Text(_formatTime(t)),
                );
              }).toList(),
            ),

            const Divider(height: 32),

            // DailyMed Drug Info
            Text(
              'Drug Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_drugInfo == null && !isVerified)
              const Text(
                'No drug information available for unverified medicines.',
                style: TextStyle(color: Colors.grey),
              )
            else if (_drugInfo == null)
              const Text(
                'Drug information not yet available. It will be fetched in the background.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              if (_drugInfo!.indicationsUsage != null)
                _expandableSection(
                  context,
                  'Indications & Usage',
                  _drugInfo!.indicationsUsage!,
                  rawText: _drugInfo!.rawIndicationsUsage,
                ),
              if (_drugInfo!.dosageAdministration != null)
                _expandableSection(
                  context,
                  'Dosage & Administration',
                  _drugInfo!.dosageAdministration!,
                  rawText: _drugInfo!.rawDosageAdministration,
                ),
              if (_drugInfo!.warnings != null)
                _expandableSection(
                  context,
                  'Warnings',
                  _drugInfo!.warnings!,
                  rawText: _drugInfo!.rawWarnings,
                ),
              if (_drugInfo!.adverseReactions != null)
                _expandableSection(
                  context,
                  'Adverse Reactions',
                  _drugInfo!.adverseReactions!,
                  rawText: _drugInfo!.rawAdverseReactions,
                ),

              const SizedBox(height: 12),
              Text(
                'Data source: DailyMed (NIH)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  Widget _expandableSection(
    BuildContext context,
    String title,
    String content, {
    String? rawText,
  }) {
    final isShowingFullText = _sectionsShowingFullText.contains(title);
    final displayText = isShowingFullText && rawText != null ? rawText : content;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (rawText != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isShowingFullText) {
                          _sectionsShowingFullText.remove(title);
                        } else {
                          _sectionsShowingFullText.add(title);
                        }
                      });
                    },
                    child: Text(
                      isShowingFullText ? 'Hide full $title' : 'Show full $title',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

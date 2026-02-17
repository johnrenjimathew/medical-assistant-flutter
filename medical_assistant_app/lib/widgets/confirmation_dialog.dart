import 'package:flutter/material.dart';
import 'package:medicine_reminder/widgets/large_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.question_mark,
              size: 60,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: LargeButton(
                    text: cancelText,
                    icon: Icons.cancel,
                    onPressed: onCancel,
                    backgroundColor: Colors.grey,
                    height: 50,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LargeButton(
                    text: confirmText,
                    icon: Icons.check,
                    onPressed: onConfirm,
                    backgroundColor: Colors.green,
                    height: 50,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
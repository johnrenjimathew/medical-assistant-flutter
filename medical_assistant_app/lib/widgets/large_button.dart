import 'package:flutter/material.dart';

class LargeButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;

  const LargeButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 30,
        ),
        label: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: textColor ?? Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 4,
        ),
      ),
    );
  }
}
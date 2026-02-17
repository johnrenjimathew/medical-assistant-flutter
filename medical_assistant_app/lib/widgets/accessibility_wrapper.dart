import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicine_reminder/services/settings_sync_service.dart';

class AccessibilityWrapper extends StatefulWidget {
  final Widget child;

  const AccessibilityWrapper({super.key, required this.child});

  @override
  State<AccessibilityWrapper> createState() => _AccessibilityWrapperState();
}

class _AccessibilityWrapperState extends State<AccessibilityWrapper> {
  bool _largeText = true;
  bool _highContrast = false;

  @override
  void initState() {
    super.initState();
    SettingsSyncService.settingsVersion.addListener(_loadSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    SettingsSyncService.settingsVersion.removeListener(_loadSettings);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _largeText = prefs.getBool('largeText') ?? true;
      _highContrast = prefs.getBool('highContrast') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: _largeText
            ? Theme.of(context).textTheme.copyWith(
                  displayLarge: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 36),
                  displayMedium: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: 32),
                  bodyLarge: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontSize: 24),
                  bodyMedium: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 20),
                )
            : Theme.of(context).textTheme,
        colorScheme: _highContrast
            ? Theme.of(context).colorScheme.copyWith(
                  primary: Colors.black,
                  secondary: Colors.white,
                  surface: Colors.white,
                  onPrimary: Colors.white,
                  onSecondary: Colors.black,
                  onSurface: Colors.black,
                )
            : Theme.of(context).colorScheme,
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _largeText
              ? const TextScaler.linear(1.2)
              : const TextScaler.linear(1.0),
        ),
        child: widget.child,
      ),
    );
  }
}

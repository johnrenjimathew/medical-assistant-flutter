import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicine_reminder/widgets/large_button.dart';
import 'package:medicine_reminder/services/settings_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _largeText = true;
  bool _highContrast = false;
  bool _voiceReminders = true;
  bool _vibration = true;
  int _snoozeDuration = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _largeText = prefs.getBool('largeText') ?? true;
      _highContrast = prefs.getBool('highContrast') ?? false;
      _voiceReminders = prefs.getBool('voiceReminders') ?? true;
      _vibration = prefs.getBool('vibration') ?? true;
      _snoozeDuration = prefs.getInt('snoozeDuration') ?? 10;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('largeText', _largeText);
    await prefs.setBool('highContrast', _highContrast);
    await prefs.setBool('voiceReminders', _voiceReminders);
    await prefs.setBool('vibration', _vibration);
    await prefs.setInt('snoozeDuration', _snoozeDuration);
    SettingsSyncService.notifySettingsChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Accessibility Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accessibility',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Large Text',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'Increase text size throughout the app',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: _largeText,
                        onChanged: (value) {
                          setState(() {
                            _largeText = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          'High Contrast',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'Increase contrast for better visibility',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: _highContrast,
                        onChanged: (value) {
                          setState(() {
                            _highContrast = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          'Voice Reminders',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'Read reminders aloud',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: _voiceReminders,
                        onChanged: (value) {
                          setState(() {
                            _voiceReminders = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Notification Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Vibration',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        value: _vibration,
                        onChanged: (value) {
                          setState(() {
                            _vibration = value;
                          });
                        },
                      ),
                      ListTile(
                        title: Text(
                          'Snooze Duration',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          '$_snoozeDuration minutes',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_snoozeDuration > 5) {
                                  setState(() {
                                    _snoozeDuration -= 5;
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove),
                            ),
                            Text(
                              '$_snoozeDuration',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            IconButton(
                              onPressed: () {
                                if (_snoozeDuration < 60) {
                                  setState(() {
                                    _snoozeDuration += 5;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // About
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: Text(
                          'Version',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          '1.0.0',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.school),
                        title: Text(
                          'Student Project',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'KTU University - 3rd Year B.Tech',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Save Button
              LargeButton(
                text: 'Save Settings',
                icon: Icons.save,
                onPressed: _saveSettings,
                backgroundColor: Colors.green,
              ),
              const SizedBox(height: 10),
              
              // Reset Button
              LargeButton(
                text: 'Reset to Defaults',
                icon: Icons.restore,
                onPressed: () {
                  setState(() {
                    _largeText = true;
                    _highContrast = false;
                    _voiceReminders = true;
                    _vibration = true;
                    _snoozeDuration = 10;
                  });
                },
                backgroundColor: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

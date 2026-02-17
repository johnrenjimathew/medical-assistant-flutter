import 'package:flutter/foundation.dart';

class SettingsSyncService {
  static final ValueNotifier<int> _settingsVersion = ValueNotifier<int>(0);

  static ValueListenable<int> get settingsVersion => _settingsVersion;

  static void notifySettingsChanged() {
    _settingsVersion.value++;
  }
}

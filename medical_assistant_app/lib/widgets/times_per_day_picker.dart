import 'package:flutter/material.dart';

List<TimeOfDay> suggestedTimes(int n) {
  switch (n) {
    case 1:
      return const [TimeOfDay(hour: 8, minute: 0)];
    case 2:
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    case 3:
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 13, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    case 4:
      return const [
        TimeOfDay(hour: 7, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 17, minute: 0),
        TimeOfDay(hour: 22, minute: 0),
      ];
    default:
      throw ArgumentError.value(n, 'n', 'Supported values are 1 to 4');
  }
}

class TimesPerDayPicker extends StatefulWidget {
  final List<TimeOfDay> initialTimes;
  final ValueChanged<List<TimeOfDay>> onChanged;

  const TimesPerDayPicker({
    super.key,
    required this.initialTimes,
    required this.onChanged,
  });

  @override
  State<TimesPerDayPicker> createState() => _TimesPerDayPickerState();
}

class _TimesPerDayPickerState extends State<TimesPerDayPicker> {
  static const int _minTimesPerDay = 1;
  static const int _maxTimesPerDay = 4;
  static const TimeOfDay _defaultAppendTime = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _fallbackAppendTime = TimeOfDay(hour: 9, minute: 0);

  late List<TimeOfDay> _times;
  late int _timesPerDay;
  bool _hasManualEdits = false;

  @override
  void initState() {
    super.initState();
    _times = List<TimeOfDay>.from(widget.initialTimes);
    if (_times.isEmpty) {
      _times = List<TimeOfDay>.from(suggestedTimes(1));
    }
    _timesPerDay = _times.length.clamp(_minTimesPerDay, _maxTimesPerDay);
    if (_times.length != _timesPerDay) {
      _times = _times.take(_timesPerDay).toList();
    }
  }

  Future<void> _editTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _times[index] = picked;
      _hasManualEdits = true;
    });
    widget.onChanged(List<TimeOfDay>.from(_times));
  }

  void _increaseTimesPerDay() {
    if (_timesPerDay >= _maxTimesPerDay) return;

    final int newCount = _timesPerDay + 1;
    final bool isOnSuggestedSchedule =
        !_hasManualEdits && _sameTimes(_times, suggestedTimes(_timesPerDay));

    setState(() {
      _timesPerDay = newCount;
      if (isOnSuggestedSchedule) {
        _times = List<TimeOfDay>.from(suggestedTimes(newCount));
      } else {
        final timeToAppend = _containsTime(_times, _defaultAppendTime)
            ? _fallbackAppendTime
            : _defaultAppendTime;
        _times = [..._times, timeToAppend];
      }
    });
    widget.onChanged(List<TimeOfDay>.from(_times));
  }

  void _decreaseTimesPerDay() {
    if (_timesPerDay <= _minTimesPerDay) return;

    setState(() {
      _timesPerDay -= 1;
      _times = _times.sublist(0, _times.length - 1);
    });
    widget.onChanged(List<TimeOfDay>.from(_times));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Times per day',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _timesPerDay > _minTimesPerDay ? _decreaseTimesPerDay : null,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Decrease times per day',
            ),
            Text(
              '$_timesPerDay',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              onPressed: _timesPerDay < _maxTimesPerDay ? _increaseTimesPerDay : null,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Increase times per day',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_times.length, (index) {
          final time = _times[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: Text(MaterialLocalizations.of(context).formatTimeOfDay(time)),
            onTap: () => _editTime(index),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editTime(index),
            ),
          );
        }),
      ],
    );
  }

  static bool _containsTime(List<TimeOfDay> times, TimeOfDay value) {
    return times.any((time) => time.hour == value.hour && time.minute == value.minute);
  }

  static bool _sameTimes(List<TimeOfDay> a, List<TimeOfDay> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].hour != b[i].hour || a[i].minute != b[i].minute) {
        return false;
      }
    }
    return true;
  }
}

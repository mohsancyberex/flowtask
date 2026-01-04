import 'package:intl/intl.dart';

class DateParser {
  static DateTime? parse(String input) {
    input = input.toLowerCase().trim();
    final now = DateTime.now();

    if (input == 'today') return DateTime(now.year, now.month, now.day);
    if (input == 'tomorrow') return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    // in N days
    final inDaysRegex = RegExp(r'in (\d+) days?');
    if (inDaysRegex.hasMatch(input)) {
      final days = int.parse(inDaysRegex.firstMatch(input)!.group(1)!);
      return DateTime(now.year, now.month, now.day).add(Duration(days: days));
    }

    // in N hours
    final inHoursRegex = RegExp(r'in (\d+) hours?');
    if (inHoursRegex.hasMatch(input)) {
      final hours = int.parse(inHoursRegex.firstMatch(input)!.group(1)!);
      return now.add(Duration(hours: hours));
    }

    // next [day]
    final nextDayRegex = RegExp(r'next (monday|tuesday|wednesday|thursday|friday|saturday|sunday)');
    if (nextDayRegex.hasMatch(input)) {
      final targetDay = nextDayRegex.firstMatch(input)!.group(1)!;
      return _getNextDay(targetDay);
    }

    // specific weekdays (e.g. "monday")
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    if (weekdays.contains(input)) {
      return _getNextDay(input);
    }

    return null;
  }

  static DateTime _getNextDay(String dayName) {
    final now = DateTime.now();
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    int targetWeekday = weekdays[dayName]!;
    int daysUntil = targetWeekday - now.weekday;
    if (daysUntil <= 0) daysUntil += 7;

    return DateTime(now.year, now.month, now.day).add(Duration(days: daysUntil));
  }
}

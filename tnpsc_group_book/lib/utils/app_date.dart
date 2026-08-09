import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'app_language.dart';

class AppDate {
  /// The single source of truth for "Now" in the application, forced to IST (UTC+5:30).
  static DateTime getISTNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Converts any DateTime to IST (UTC+5:30) value.
  static DateTime toIST(DateTime date) {
    return date.toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Returns today's date string in yyyy-MM-dd format for internal use/keys.
  static String getTodayString() {
    return DateFormat('yyyy-MM-dd', 'en_US').format(getISTNow());
  }

  /// Returns localized date string for UI display.
  static String getDisplayDate(DateTime date) {
    return DateFormat.yMMMMd(AppLanguage.languageNotifier.value).format(date);
  }

  /// Converts an IST DateTime to a TimeOfDay object.
  static TimeOfDay getISTTimeOfDay([DateTime? istDate]) {
    final date = istDate ?? getISTNow();
    return TimeOfDay(hour: date.hour, minute: date.minute);
  }

  /// Constructs a DateTime object specifically for the today in IST.
  /// This is used for Time Pickers to avoid local timezone interference.
  static DateTime getISTDateTime(int year, int month, int day, [int hour = 0, int minute = 0]) {
    // Construct as UTC then shift by 5:30 to match the app's internal "IST as UTC" representation
    return DateTime.utc(year, month, day, hour, minute).subtract(const Duration(hours: 5, minutes: 30)).toUtc().add(const Duration(hours: 5, minutes: 30));
  }
  
  /// Helper to create an IST DateTime from components for "Today".
  static DateTime getISTTodayWithTime(int hour, int minute) {
    final now = getISTNow();
    return DateTime.utc(now.year, now.month, now.day, hour, minute).subtract(const Duration(hours: 5, minutes: 30)).toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Keep this as yyyy-MM-dd because it is used for Firestore/Hive keys throughout the app.
  static String format(DateTime date) {
    return DateFormat('yyyy-MM-dd', 'en_US').format(date);
  }
  
  static DateTime parse(String dateStr) {
    return DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
  }

  /// Returns true if the current IST time is after 11:00 PM.
  static bool isAfter11PM() {
    final now = getISTNow();
    return now.hour >= 23;
  }




  /// Returns a seed that changes every 6 hours and is consistent across all users.
  static int getSlotSeed() {
    final now = getISTNow();
    // Use hours since epoch to create a global unique seed for every 6-hour block
    return (now.millisecondsSinceEpoch / (1000 * 60 * 60 * 6)).floor();
  }

  /// Returns an index (0-3) representing the current 6-hour slot of the day.
  static int getSlotOfDay() {
    return (getISTNow().hour / 6).floor();
  }
}

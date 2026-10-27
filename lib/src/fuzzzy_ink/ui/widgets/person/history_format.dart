import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// How a person's history names days, times and sizes, in the phone's own
/// language (no date package: Material's localizations already cover both
/// languages).
abstract final class HistoryFormat {
  /// Lets tests fix "today".
  static DateTime Function() now = DateTime.now;

  /// The calendar day [time] fell on, in local time.
  static DateTime dayOf(DateTime time) {
    final local = time.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// "Today", "Yesterday", or the date ("Tue, Oct 20").
  static String dayLabel(BuildContext context, DateTime time) {
    final localizations = context.fuzzzyInkLocalizations;
    final day = dayOf(time);
    final today = dayOf(now());
    final difference = today.difference(day).inDays;
    if (difference == 0) return localizations.historyToday;
    if (difference == 1) return localizations.historyYesterday;
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }

  /// "9:20" (or "9:20 AM", as the phone shows times).
  static String timeLabel(BuildContext context, DateTime time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  /// "812 B", "3.1 KB", "4.2 MB", "1.3 GB".
  static String fileSize(int bytes) {
    const kb = 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < kb * kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < kb * kb * kb) {
      return '${(bytes / (kb * kb)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (kb * kb * kb)).toStringAsFixed(1)} GB';
  }
}

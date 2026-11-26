import 'package:flutter/material.dart';
import '../../auth/models/public_user.dart';

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Name shown in the chat (an account may have no name yet).
String chatName(PublicUser user) => user.fullName.isEmpty ? 'ColoHouse member' : user.fullName;

/// "14:05" (or "2:05 PM", following the phone settings).
String messageTime(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(date),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Day separator: "Today", "Yesterday", "Mon, Nov 24", "Nov 24, 2025".
String dayLabel(BuildContext context, DateTime date) {
  final now = DateTime.now();
  if (isSameDay(date, now)) return 'Today';
  if (isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  final loc = MaterialLocalizations.of(context);
  return date.year == now.year ? loc.formatMediumDate(date) : loc.formatShortDate(date);
}

/// Chat list: "now", "5 min", "3 h", "Yesterday", "Nov 20".
String relativeTime(BuildContext context, DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (isSameDay(date, now)) return '${diff.inHours} h';
  if (isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  final loc = MaterialLocalizations.of(context);
  return date.year == now.year ? loc.formatShortMonthDay(date) : loc.formatShortDate(date);
}

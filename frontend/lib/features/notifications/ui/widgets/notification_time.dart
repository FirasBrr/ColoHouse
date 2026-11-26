const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "just now", "5 min ago", "2 h ago", "yesterday", or a date ("Nov 12", "Nov 12, 2025").
String notificationTimeAgo(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (isSameDay(time, now)) return '${diff.inHours} h ago';
  if (isSameDay(time, DateTime(now.year, now.month, now.day - 1))) return 'yesterday';
  final date = '${_months[time.month - 1]} ${time.day}';
  return time.year == now.year ? date : '$date, ${time.year}';
}

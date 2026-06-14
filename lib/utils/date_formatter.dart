class DateFormatter {
  DateFormatter._();

  static const List<String> _monthsFull = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Format timestamp as a date header (e.g. "Hari ini", "Kemarin", "14 Juni 2025")
  static String formatDateHeader(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) return 'Hari ini';
    if (messageDate == yesterday) return 'Kemarin';
    return '${dateTime.day} ${_monthsFull[dateTime.month - 1]} ${dateTime.year}';
  }

  /// Format timestamp for search result display (e.g. "Hari ini 14:30", "14 Jun 2025 09:00")
  static String formatSearchResultTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (date == today) return 'Hari ini $timeStr';
    if (date == yesterday) return 'Kemarin $timeStr';
    return '${dateTime.day} ${_monthsShort[dateTime.month - 1]} ${dateTime.year} $timeStr';
  }
}

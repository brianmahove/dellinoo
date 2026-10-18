import '../data/models.dart';

String money(double value) => '\$${value.toStringAsFixed(2)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Sep 2026" — for things like "Member since".
String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String dateTime(DateTime d) =>
    '${d.day} ${_months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String weekdayDayMonth(DateTime d) => '${_weekdays[d.weekday - 1]}, ${dayMonth(d)}';

/// Short arrival promise for cards: "Get it by 28 Sep", or "Out of stock".
String arrivalShort(StockStatus s, [DateTime? orderedAt]) {
  if (s != StockStatus.inStock) return s.label;
  return 'Get it by ${dayMonth(s.arrivalFrom(orderedAt ?? DateTime.now()))}';
}

/// Full arrival promise: "In stock · Get it by Mon, 28 Sep".
String arrivalLong(StockStatus s, [DateTime? orderedAt]) {
  if (s != StockStatus.inStock) return s.label;
  return 'In stock · Get it by ${weekdayDayMonth(s.arrivalFrom(orderedAt ?? DateTime.now()))}';
}

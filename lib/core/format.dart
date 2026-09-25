import '../data/models.dart';

String money(double value) => '\$${value.toStringAsFixed(2)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String dateTime(DateTime d) =>
    '${d.day} ${_months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String weekdayDayMonth(DateTime d) => '${_weekdays[d.weekday - 1]}, ${dayMonth(d)}';

/// Short arrival promise for cards: "Get it by 28 Sep" / "Arrives 16 Oct".
String arrivalShort(StockStatus s, [DateTime? orderedAt]) {
  final d = s.arrivalFrom(orderedAt ?? DateTime.now());
  return s == StockStatus.inStock ? 'Get it by ${dayMonth(d)}' : 'Arrives ${dayMonth(d)}';
}

/// Full arrival promise: "In stock · Get it by Mon, 28 Sep".
String arrivalLong(StockStatus s, [DateTime? orderedAt]) {
  final d = s.arrivalFrom(orderedAt ?? DateTime.now());
  return s == StockStatus.inStock
      ? 'In stock · Get it by ${weekdayDayMonth(d)}'
      : 'From China · Arrives by ${weekdayDayMonth(d)}';
}

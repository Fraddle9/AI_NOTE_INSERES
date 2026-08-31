/// Liste arama / sıralama yardımcıları (web tablolarındaki CrmQuery ile aynı amaç).
bool matchesQuery(String query, Iterable<Object?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final field in fields) {
    if (field == null) continue;
    if (field.toString().toLowerCase().contains(q)) return true;
  }
  return false;
}

int compareText(Object? a, Object? b, {bool desc = false}) {
  final sa = (a ?? '').toString().toLowerCase();
  final sb = (b ?? '').toString().toLowerCase();
  final c = sa.compareTo(sb);
  return desc ? -c : c;
}

int compareDate(String? a, String? b, {bool desc = false}) {
  final da = DateTime.tryParse(a ?? '');
  final db = DateTime.tryParse(b ?? '');
  if (da == null && db == null) return compareText(a, b, desc: desc);
  if (da == null) return desc ? -1 : 1;
  if (db == null) return desc ? 1 : -1;
  final c = da.compareTo(db);
  return desc ? -c : c;
}

int compareNum(Object? a, Object? b, {bool desc = false}) {
  final na = num.tryParse('${a ?? ''}');
  final nb = num.tryParse('${b ?? ''}');
  if (na != null && nb != null) {
    final c = na.compareTo(nb);
    return desc ? -c : c;
  }
  return compareText(a, b, desc: desc);
}

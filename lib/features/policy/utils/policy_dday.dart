/// Shared D-Day label for a policy's `applicationEndDate`.
///
/// Same rule Calendar already uses (day_detail_sheet.dart / calendar_screen.dart):
/// `days = applicationEndDate - referenceDay`. Kept here as its own small
/// function for Policy's new screens instead of duplicating the inline
/// version those two files already have - not retrofitted into Calendar to
/// avoid touching already-shipped, already-committed code for no functional
/// reason.
String? policyDDayLabel(String? applicationEndDate, {DateTime? referenceDay}) {
  if (applicationEndDate == null || applicationEndDate.isEmpty) return null;
  final end = DateTime.tryParse(applicationEndDate);
  if (end == null) return null;

  final ref = referenceDay ?? DateTime.now();
  final endDay = DateTime(end.year, end.month, end.day);
  final refDay = DateTime(ref.year, ref.month, ref.day);
  final days = endDay.difference(refDay).inDays;

  if (days < 0) return '마감';
  if (days == 0) return 'D-Day';
  return 'D-$days';
}

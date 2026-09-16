/// Calendar policy-deadline badges ("정책 D-5" / "정책 D-3" / "정책 D-Day").
///
/// Only bookmarked ("관심") policies are considered, and only exactly 5/3/0
/// days before the deadline produce a badge - D-4/D-2/D-1 etc. are
/// intentionally never shown.
enum PolicyAlertType { d5, d3, dDay }

class PolicyAlert {
  final String policyId;
  final String policyTitle;
  final PolicyAlertType type;

  const PolicyAlert({
    required this.policyId,
    required this.policyTitle,
    required this.type,
  });
}

String policyAlertLabel(PolicyAlertType type) {
  switch (type) {
    case PolicyAlertType.d5:
      return '정책 D-5';
    case PolicyAlertType.d3:
      return '정책 D-3';
    case PolicyAlertType.dDay:
      return '정책 D-Day';
  }
}

/// Lower = more urgent, used to pick which alert leads a multi-policy badge.
int policyAlertUrgency(PolicyAlertType type) {
  switch (type) {
    case PolicyAlertType.dDay:
      return 0;
    case PolicyAlertType.d3:
      return 1;
    case PolicyAlertType.d5:
      return 2;
  }
}

/// Maps a calendar-day count-down to a badge type. Calendar-day based (the
/// caller diffs two midnight-normalized DateTimes), never a raw millisecond
/// division, so timezone/DST cannot shift which day a badge lands on.
PolicyAlertType? policyAlertTypeForDaysRemaining(int days) {
  switch (days) {
    case 5:
      return PolicyAlertType.d5;
    case 3:
      return PolicyAlertType.d3;
    case 0:
      return PolicyAlertType.dDay;
    default:
      return null;
  }
}

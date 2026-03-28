class PendingCounts {
  final int loan;
  final int leave;
  final int other;

  PendingCounts({
    required this.loan,
    required this.leave,
    required this.other,
  });

  factory PendingCounts.fromJson(Map<String, dynamic> json) {
    int parse(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }
    return PendingCounts(
      loan: parse(json['Loan'] ?? json['loan']),
      leave: parse(json['Leave'] ?? json['leave']),
      other: parse(json['Other'] ?? json['other']),
    );
  }
}

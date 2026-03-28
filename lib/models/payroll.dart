class PayrollItem {
  final String id;
  final String employeeId;
  final int year;
  final int month;
  final double basicSalary;
  final double allowances;
  final double overtime;
  final double deductions;
  final double bonuses;
  final double netSalary;
  final DateTime paymentDate;
  final String? notes;
  final bool isPaid;

  PayrollItem({
    required this.id,
    required this.employeeId,
    required this.year,
    required this.month,
    required this.basicSalary,
    required this.allowances,
    required this.overtime,
    required this.deductions,
    required this.bonuses,
    required this.netSalary,
    required this.paymentDate,
    this.notes,
    this.isPaid = false,
  });

  factory PayrollItem.fromJson(Map<String, dynamic> json) {
    return PayrollItem(
      id: json['id'],
      employeeId: json['employeeId'],
      year: json['year'],
      month: json['month'],
      basicSalary: json['basicSalary'].toDouble(),
      allowances: json['allowances'].toDouble(),
      overtime: json['overtime'].toDouble(),
      deductions: json['deductions'].toDouble(),
      bonuses: json['bonuses'].toDouble(),
      netSalary: json['netSalary'].toDouble(),
      paymentDate: DateTime.parse(json['paymentDate']),
      notes: json['notes'],
      isPaid: json['isPaid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'year': year,
      'month': month,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'overtime': overtime,
      'deductions': deductions,
      'bonuses': bonuses,
      'netSalary': netSalary,
      'paymentDate': paymentDate.toIso8601String(),
      'notes': notes,
      'isPaid': isPaid,
    };
  }
}

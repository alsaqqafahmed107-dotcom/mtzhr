class SalaryDetailsModel {
  final double basicSalary;
  final List<SalaryItemModel> additions;
  final List<SalaryItemModel> deductions;
  final double totalAdditions;
  final double totalDeductions;
  final double netSalary;
  final String month;
  final String year;

  SalaryDetailsModel({
    required this.basicSalary,
    required this.additions,
    required this.deductions,
    required this.totalAdditions,
    required this.totalDeductions,
    required this.netSalary,
    required this.month,
    required this.year,
  });

  factory SalaryDetailsModel.fromJson(Map<String, dynamic> json) {
    var additionsList = (json['additions'] as List?)
            ?.map((i) => SalaryItemModel.fromJson(i))
            .toList() ??
        [];
    var deductionsList = (json['deductions'] as List?)
            ?.map((i) => SalaryItemModel.fromJson(i))
            .toList() ??
        [];

    return SalaryDetailsModel(
      basicSalary: (json['basicSalary'] ?? 0).toDouble(),
      additions: additionsList,
      deductions: deductionsList,
      totalAdditions: (json['totalAdditions'] ?? 0).toDouble(),
      totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
      netSalary: (json['netSalary'] ?? 0).toDouble(),
      month: json['month']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'basicSalary': basicSalary,
      'additions': additions.map((e) => e.toJson()).toList(),
      'deductions': deductions.map((e) => e.toJson()).toList(),
      'totalAdditions': totalAdditions,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
      'month': month,
      'year': year,
    };
  }
}

class SalaryItemModel {
  final String nameAr;
  final String nameEn;
  final double amount;

  SalaryItemModel({
    required this.nameAr,
    required this.nameEn,
    required this.amount,
  });

  factory SalaryItemModel.fromJson(Map<String, dynamic> json) {
    return SalaryItemModel(
      nameAr: json['nameAr'] ?? '',
      nameEn: json['nameEn'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nameAr': nameAr,
      'nameEn': nameEn,
      'amount': amount,
    };
  }
}

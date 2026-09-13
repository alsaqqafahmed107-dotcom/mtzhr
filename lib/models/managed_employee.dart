class ManagedEmployee {
  final int employeeId;
  final String? employeeNumber;
  final String name;
  final int? departmentId;
  final String? departmentName;

  const ManagedEmployee({
    required this.employeeId,
    required this.employeeNumber,
    required this.name,
    required this.departmentId,
    required this.departmentName,
  });

  factory ManagedEmployee.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return ManagedEmployee(
      employeeId: toInt(json['EmployeeID'] ?? json['employeeId']),
      employeeNumber: json['EmployeeNumber']?.toString(),
      name: (json['EmployeeName'] ?? json['employeeName'] ?? '').toString(),
      departmentId: json['DepartmentID'] == null ? null : toInt(json['DepartmentID']),
      departmentName: json['DepartmentName']?.toString(),
    );
  }
}


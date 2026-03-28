class Employee {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String department;
  final String position;
  final String employeeNumber;
  final double salary;
  final DateTime hireDate;
  final String? profileImage;
  final String? fingerprintData;
  final String? faceData;
  final bool isActive;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.position,
    required this.employeeNumber,
    required this.salary,
    required this.hireDate,
    this.profileImage,
    this.fingerprintData,
    this.faceData,
    this.isActive = true,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      department: json['department'],
      position: json['position'],
      employeeNumber: json['employeeNumber'],
      salary: json['salary'].toDouble(),
      hireDate: DateTime.parse(json['hireDate']),
      profileImage: json['profileImage'],
      fingerprintData: json['fingerprintData'],
      faceData: json['faceData'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'position': position,
      'employeeNumber': employeeNumber,
      'salary': salary,
      'hireDate': hireDate.toIso8601String(),
      'profileImage': profileImage,
      'fingerprintData': fingerprintData,
      'faceData': faceData,
      'isActive': isActive,
    };
  }
}

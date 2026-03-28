class EmployeeFullInfo {
  final int id;
  final int employeeId;
  final String name;
  final String mail;
  final String rules;
  final String databaseName;
  final bool isActive;
  final int clientId;
  final String modifiedDate;
  final String employeeNumber;
  final String firstName;
  final String middleName;
  final String lastName;
  final String firstNameEn;
  final String middleNameEn;
  final String lastNameEn;
  final String nationalId;
  final String nationalIdIssueDate;
  final String nationalIdExpiryDate;
  final String passportNumber;
  final String passportIssueDate;
  final String passportExpiryDate;
  final int nationalityId;
  final String birthDate;
  final String gender;
  final String maritalStatus;
  final String mobileNumber;
  final String email;
  final String address;
  final String city;
  final String contractStartDate;
  final String contractEndDate;
  final String hireDate;
  final int departmentId;
  final String? departmentName; // New field
  final String positionId;
  final String? positionName; // New field
  final String? jobTitle; // New field
  final String? qualification; // New field
  final int managerId;
  final String? managerName; // New field
  final String employmentType;
  final String insuranceNumber;
  final String insuranceStartDate;
  final String insuranceEndDate;
  final String bankName;
  final String iban;
  final double leaveBalances;
  final String personalPhoto;
  final String createdDate;
  final String? lastModifiedDate;
  final String createdBy;
  final String? updatedBy;
  final String updatedDate;
  final String nationalityCategory;
  final String employeeClassification;
  final String clientName;

  EmployeeFullInfo({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.mail,
    required this.rules,
    required this.databaseName,
    required this.isActive,
    required this.clientId,
    required this.modifiedDate,
    required this.employeeNumber,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.firstNameEn,
    required this.middleNameEn,
    required this.lastNameEn,
    required this.nationalId,
    required this.nationalIdIssueDate,
    required this.nationalIdExpiryDate,
    required this.passportNumber,
    required this.passportIssueDate,
    required this.passportExpiryDate,
    required this.nationalityId,
    required this.birthDate,
    required this.gender,
    required this.maritalStatus,
    required this.mobileNumber,
    required this.email,
    required this.address,
    required this.city,
    required this.contractStartDate,
    required this.contractEndDate,
    required this.hireDate,
    required this.departmentId,
    this.departmentName,
    required this.positionId,
    this.positionName,
    this.jobTitle,
    this.qualification,
    required this.managerId,
    this.managerName,
    required this.employmentType,
    required this.insuranceNumber,
    required this.insuranceStartDate,
    required this.insuranceEndDate,
    required this.bankName,
    required this.iban,
    required this.leaveBalances,
    required this.personalPhoto,
    required this.createdDate,
    this.lastModifiedDate,
    required this.createdBy,
    this.updatedBy,
    required this.updatedDate,
    required this.nationalityCategory,
    required this.employeeClassification,
    required this.clientName,
  });

  factory EmployeeFullInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeFullInfo(
      id: json['ID'] ?? json['id'] ?? 0,
      employeeId: json['EmployeeID'] ?? json['employeeId'] ?? 0,
      name: json['Name'] ?? json['name'] ?? '',
      mail: json['Mail'] ?? json['mail'] ?? '',
      rules: json['Rules'] ?? json['rules'] ?? '',
      databaseName: json['DatabaseName'] ?? json['databaseName'] ?? '',
      isActive: json['IsActive'] ?? json['isActive'] ?? false,
      clientId: json['ClientID'] ?? json['clientId'] ?? 0,
      modifiedDate: json['ModifiedDate'] ?? json['modifiedDate'] ?? '',
      employeeNumber: json['EmployeeNumber'] ?? json['employeeNumber'] ?? '',
      firstName: json['FirstName'] ?? json['firstName'] ?? '',
      middleName: json['MiddleName'] ?? json['middleName'] ?? '',
      lastName: json['LastName'] ?? json['lastName'] ?? '',
      firstNameEn: json['FirstNameEn'] ?? json['firstNameEn'] ?? '',
      middleNameEn: json['MiddleNameEn'] ?? json['middleNameEn'] ?? '',
      lastNameEn: json['LastNameEn'] ?? json['lastNameEn'] ?? '',
      nationalId: json['NationalID'] ?? json['nationalId'] ?? '',
      nationalIdIssueDate: json['NationalIDIssueDate'] ?? json['nationalIdIssueDate'] ?? '',
      nationalIdExpiryDate: json['NationalIDExpiryDate'] ?? json['nationalIdExpiryDate'] ?? '',
      passportNumber: json['PassportNumber'] ?? json['passportNumber'] ?? '',
      passportIssueDate: json['PassportIssueDate'] ?? json['passportIssueDate'] ?? '',
      passportExpiryDate: json['PassportExpiryDate'] ?? json['passportExpiryDate'] ?? '',
      nationalityId: json['NationalityID'] ?? json['nationalityId'] ?? 0,
      birthDate: json['BirthDate'] ?? json['birthDate'] ?? '',
      gender: json['Gender'] ?? json['gender'] ?? '',
      maritalStatus: json['MaritalStatus'] ?? json['maritalStatus'] ?? '',
      mobileNumber: json['MobileNumber'] ?? json['mobileNumber'] ?? '',
      email: json['Email'] ?? json['email'] ?? '',
      address: json['Address'] ?? json['address'] ?? '',
      city: json['City'] ?? json['city'] ?? '',
      contractStartDate: json['ContractStartDate'] ?? json['contractStartDate'] ?? '',
      contractEndDate: json['ContractEndDate'] ?? json['contractEndDate'] ?? '',
      hireDate: json['HireDate'] ?? json['hireDate'] ?? '',
      departmentId: json['DepartmentID'] ?? json['departmentId'] ?? 0,
      departmentName: json['DepartmentName'] ?? json['departmentName'],
      positionId: json['PositionID']?.toString() ?? json['positionId']?.toString() ?? '',
      positionName: json['PositionName']?.toString() ?? json['Position']?.toString() ?? json['positionName']?.toString(),
      jobTitle: json['JobTitle']?.toString() ?? json['jobTitle']?.toString(),
      qualification: json['Qualification']?.toString() ?? json['qualification']?.toString(),
      managerId: json['ManagerID'] ?? json['managerId'] ?? 0,
      managerName: json['ManagerName'] ?? json['managerName'],
      employmentType: json['EmploymentType'] ?? json['employmentType'] ?? '',
      insuranceNumber: json['InsuranceNumber'] ?? json['insuranceNumber'] ?? '',
      insuranceStartDate: json['InsuranceStartDate'] ?? json['insuranceStartDate'] ?? '',
      insuranceEndDate: json['InsuranceEndDate'] ?? json['insuranceEndDate'] ?? '',
      bankName: json['BankName'] ?? json['bankName'] ?? '',
      iban: json['IBAN'] ?? json['iban'] ?? '',
      leaveBalances: (json['LeaveBalances'] ?? json['leaveBalances'] ?? 0.0).toDouble(),
      personalPhoto: json['PersonalPhoto'] ?? json['personalPhoto'] ?? '',
      createdDate: json['CreatedDate'] ?? json['createdDate'] ?? '',
      lastModifiedDate: json['LastModifiedDate'] ?? json['lastModifiedDate'],
      createdBy: json['CreatedBy'] ?? json['createdBy'] ?? '',
      updatedBy: json['UpdatedBy'] ?? json['updatedBy'],
      updatedDate: json['UpdatedDate'] ?? json['updatedDate'] ?? '',
      nationalityCategory: json['NationalityCategory'] ?? json['nationalityCategory'] ?? '',
      employeeClassification: json['EmployeeClassification'] ?? json['employeeClassification'] ?? '',
      clientName: json['ClientName'] ?? json['clientName'] ?? '',
    );
  }

  String get fullName => '$firstName $middleName $lastName'.trim();
  
  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'EmployeeID': employeeId,
      'Name': name,
      'DepartmentName': departmentName,
      'PositionID': positionId,
      'PositionName': positionName,
      'JobTitle': jobTitle,
      'Qualification': qualification,
      'ManagerName': managerName,
      // Add other fields as needed for debugging
    };
  }

  String formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
} 
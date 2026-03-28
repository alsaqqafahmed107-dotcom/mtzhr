class BiometricModel {
  final String employeeNumber;
  final String biometricData; // Base64 encoded biometric data
  final String biometricType; // FINGERPRINT, FACE
  final String? deviceInfo;
  final DateTime? createdDate;

  BiometricModel({
    required this.employeeNumber,
    required this.biometricData,
    this.biometricType = 'FINGERPRINT',
    this.deviceInfo,
    this.createdDate,
  });

  factory BiometricModel.fromJson(Map<String, dynamic> json) {
    return BiometricModel(
      employeeNumber: json['EmployeeNumber'] ?? '',
      biometricData: json['BiometricData'] ?? '',
      biometricType: json['BiometricType'] ?? 'FINGERPRINT',
      deviceInfo: json['DeviceInfo'],
      createdDate: json['CreatedDate'] != null
          ? DateTime.parse(json['CreatedDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EmployeeNumber': employeeNumber,
      'BiometricData': biometricData,
      'BiometricType': biometricType,
      'DeviceInfo': deviceInfo,
      'CreatedDate': createdDate?.toIso8601String(),
    };
  }
}

class BiometricResponse {
  final bool success;
  final String message;
  final BiometricInfo? biometric;

  BiometricResponse({
    required this.success,
    required this.message,
    this.biometric,
  });

  factory BiometricResponse.fromJson(Map<String, dynamic> json) {
    return BiometricResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      biometric: json['Biometric'] != null
          ? BiometricInfo.fromJson(json['Biometric'])
          : null,
    );
  }
}

class BiometricInfo {
  final int id;
  final String employeeNumber;
  final String biometricData;
  final String biometricType;
  final String? deviceInfo;
  final DateTime createdDate;
  final DateTime? modifiedDate;
  final bool isActive;

  BiometricInfo({
    required this.id,
    required this.employeeNumber,
    required this.biometricData,
    required this.biometricType,
    this.deviceInfo,
    required this.createdDate,
    this.modifiedDate,
    required this.isActive,
  });

  factory BiometricInfo.fromJson(Map<String, dynamic> json) {
    return BiometricInfo(
      id: json['ID'] ?? 0,
      employeeNumber: json['EmployeeNumber'] ?? '',
      biometricData: json['BiometricData'] ?? '',
      biometricType: json['BiometricType'] ?? 'FINGERPRINT',
      deviceInfo: json['DeviceInfo'],
      createdDate: DateTime.parse(json['CreatedDate']),
      modifiedDate: json['ModifiedDate'] != null
          ? DateTime.parse(json['ModifiedDate'])
          : null,
      isActive: json['IsActive'] ?? true,
    );
  }
}

class BiometricCheckResponse {
  final bool success;
  final String message;
  final bool hasBiometric;
  final BiometricInfo? biometric;

  BiometricCheckResponse({
    required this.success,
    required this.message,
    required this.hasBiometric,
    this.biometric,
  });

  factory BiometricCheckResponse.fromJson(Map<String, dynamic> json) {
    return BiometricCheckResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      hasBiometric: json['HasBiometric'] ?? false,
      biometric: json['Biometric'] != null
          ? BiometricInfo.fromJson(json['Biometric'])
          : null,
    );
  }
}

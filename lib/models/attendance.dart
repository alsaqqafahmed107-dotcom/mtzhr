enum AttendanceType {
  checkIn,
  checkOut,
}

enum AuthenticationMethod {
  gps,
  fingerprint,
  face,
  manual,
}

class Attendance {
  final String id;
  final String employeeId;
  final DateTime timestamp;
  final AttendanceType type;
  final AuthenticationMethod method;
  final double? latitude;
  final double? longitude;
  final String? location;
  final String? notes;
  final bool isVerified;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.timestamp,
    required this.type,
    required this.method,
    this.latitude,
    this.longitude,
    this.location,
    this.notes,
    this.isVerified = false,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      employeeId: json['employeeId'],
      timestamp: DateTime.parse(json['timestamp']),
      type: AttendanceType.values.firstWhere(
        (e) => e.toString() == 'AttendanceType.${json['type']}',
      ),
      method: AuthenticationMethod.values.firstWhere(
        (e) => e.toString() == 'AuthenticationMethod.${json['method']}',
      ),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      location: json['location'],
      notes: json['notes'],
      isVerified: json['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'method': method.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'notes': notes,
      'isVerified': isVerified,
    };
  }
}

class AttendanceModel {
  final String employeeNumber;
  String punchState; // "0" للحضور أو "1" للانصراف
  final DateTime? punchTime; // سيتم تعيينه من السيرفر
  final String? gpsLocation;
  final double? longitude;
  final double? latitude;
  final String? mobile;
  final String? notes;
  final String? deviceInfo;
  final double? temperature;
  final String? authenticationMethod; // "GPS", "FINGERPRINT", "FACE"

  // حقول جودة GPS الجديدة
  final int? estimatedSatellites;
  final double? gpsAccuracy;
  final double? gpsConfidenceLevel;
  final bool? isGpsGoodQuality;
  final String? gpsQualityDescription;

  // حقول ثبات الموقع الجديدة
  final bool? isLocationStable;
  final double? locationMaxVariation;
  final double? locationAverageDistance;
  final int? locationTotalReadings;
  final String? locationStabilityDescription;
  final bool? isLocationSuspiciouslyStable;
  final bool? isLocationFake;
  final double? locationAverageVariationPercentage;
  final double? locationMinVariationPercentage;

  AttendanceModel({
    required this.employeeNumber,
    required this.punchState,
    this.punchTime, // سيتم تعيينه من السيرفر
    this.gpsLocation,
    this.longitude,
    this.latitude,
    this.mobile,
    this.notes,
    this.deviceInfo,
    this.temperature,
    this.authenticationMethod,
    this.estimatedSatellites,
    this.gpsAccuracy,
    this.gpsConfidenceLevel,
    this.isGpsGoodQuality,
    this.gpsQualityDescription,
    this.isLocationStable,
    this.locationMaxVariation,
    this.locationAverageDistance,
    this.locationTotalReadings,
    this.locationStabilityDescription,
    this.isLocationSuspiciouslyStable,
    this.isLocationFake,
    this.locationAverageVariationPercentage,
    this.locationMinVariationPercentage,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      employeeNumber: json['EmployeeNumber'] ?? '',
      punchState: json['PunchState'] ?? '',
      punchTime: json['PunchTime'] != null
          ? DateTime.parse(json['PunchTime'])
          : null, // من السيرفر
      gpsLocation: json['GPSLocation'],
      longitude: json['Longitude']?.toDouble(),
      latitude: json['Latitude']?.toDouble(),
      mobile: json['Mobile'],
      notes: json['Notes'],
      deviceInfo: json['DeviceInfo'],
      temperature: json['Temperature']?.toDouble(),
      authenticationMethod: json['AuthenticationMethod'],
      estimatedSatellites: json['EstimatedSatellites']?.toInt(),
      gpsAccuracy: json['GpsAccuracy']?.toDouble(),
      gpsConfidenceLevel: json['GpsConfidenceLevel']?.toDouble(),
      isGpsGoodQuality: json['IsGpsGoodQuality']?.toBool(),
      gpsQualityDescription: json['GpsQualityDescription'],
      isLocationStable: json['IsLocationStable']?.toBool(),
      locationMaxVariation: json['LocationMaxVariation']?.toDouble(),
      locationAverageDistance: json['LocationAverageDistance']?.toDouble(),
      locationTotalReadings: json['LocationTotalReadings']?.toInt(),
      locationStabilityDescription: json['LocationStabilityDescription'],
      isLocationSuspiciouslyStable:
          json['IsLocationSuspiciouslyStable']?.toBool(),
      isLocationFake: json['IsLocationFake']?.toBool(),
      locationAverageVariationPercentage:
          json['LocationAverageVariationPercentage']?.toDouble(),
      locationMinVariationPercentage:
          json['LocationMinVariationPercentage']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EmployeeNumber': employeeNumber,
      'PunchState': punchState,
      // 'PunchTime': punchTime?.toIso8601String(), // لن يتم إرساله - سيتم تعيينه من السيرفر لضمان الدقة
      'GPSLocation': gpsLocation,
      'Longitude': longitude,
      'Latitude': latitude,
      'Mobile': mobile,
      'Notes': notes,
      'DeviceInfo': deviceInfo,
      'Temperature': temperature,
      'AuthenticationMethod': authenticationMethod,
      'EstimatedSatellites': estimatedSatellites,
      'GpsAccuracy': gpsAccuracy,
      'GpsConfidenceLevel': gpsConfidenceLevel,
      'IsGpsGoodQuality': isGpsGoodQuality,
      'GpsQualityDescription': gpsQualityDescription,
      'IsLocationStable': isLocationStable,
      'LocationMaxVariation': locationMaxVariation,
      'LocationAverageDistance': locationAverageDistance,
      'LocationTotalReadings': locationTotalReadings,
      'LocationStabilityDescription': locationStabilityDescription,
      'IsLocationSuspiciouslyStable': isLocationSuspiciouslyStable,
      'IsLocationFake': isLocationFake,
      'LocationAverageVariationPercentage': locationAverageVariationPercentage,
      'LocationMinVariationPercentage': locationMinVariationPercentage,
    };
  }
}

class AttendanceResponse {
  final bool success;
  final String message;
  final AttendanceData? attendance;

  AttendanceResponse({
    required this.success,
    required this.message,
    this.attendance,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      attendance: json['Attendance'] != null
          ? AttendanceData.fromJson(json['Attendance'])
          : null,
    );
  }
}

class AttendanceData {
  final int id;
  final String employeeNumber;
  final String? employeeName;
  final DateTime punchTime;
  final String punchState;
  final int verifyType;
  final String? workCode;
  final String? terminalSn;
  final String? terminalAlias;
  final String? areaAlias;
  final double? longitude;
  final double? latitude;
  final String? gpsLocation;
  final String? mobile;
  final int? source;
  final int? purpose;
  final String? crc;
  final int? isAttendance;
  final String? reserved;
  final DateTime? uploadTime;
  final int? syncStatus;
  final DateTime? syncTime;
  final int? empId;
  final int? terminalId;
  final int? isMask;
  final double? temperature;

  AttendanceData({
    required this.id,
    required this.employeeNumber,
    this.employeeName,
    required this.punchTime,
    required this.punchState,
    required this.verifyType,
    this.workCode,
    this.terminalSn,
    this.terminalAlias,
    this.areaAlias,
    this.longitude,
    this.latitude,
    this.gpsLocation,
    this.mobile,
    this.source,
    this.purpose,
    this.crc,
    this.isAttendance,
    this.reserved,
    this.uploadTime,
    this.syncStatus,
    this.syncTime,
    this.empId,
    this.terminalId,
    this.isMask,
    this.temperature,
  });

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    return AttendanceData(
      id: json['ID'] ?? 0,
      employeeNumber: json['EmployeeNumber'] ?? '',
      employeeName: json['EmployeeName'],
      punchTime: DateTime.parse(json['PunchTime']),
      punchState: json['PunchState'] ?? '',
      verifyType: json['VerifyType'] ?? 0,
      workCode: json['WorkCode'],
      terminalSn: json['TerminalSn'],
      terminalAlias: json['TerminalAlias'],
      areaAlias: json['AreaAlias'],
      longitude: json['Longitude']?.toDouble(),
      latitude: json['Latitude']?.toDouble(),
      gpsLocation: json['GPSLocation'],
      mobile: json['Mobile'],
      source: json['Source'],
      purpose: json['Purpose'],
      crc: json['Crc'],
      isAttendance: json['IsAttendance'],
      reserved: json['Reserved'],
      uploadTime: json['UploadTime'] != null
          ? DateTime.parse(json['UploadTime'])
          : null,
      syncStatus: json['SyncStatus'],
      syncTime:
          json['SyncTime'] != null ? DateTime.parse(json['SyncTime']) : null,
      empId: json['EmpId'],
      terminalId: json['TerminalId'],
      isMask: json['IsMask'],
      temperature: json['Temperature']?.toDouble(),
    );
  }
}

class AttendanceListResponse {
  final bool success;
  final String message;
  final List<AttendanceData> attendances;
  final int totalCount;

  AttendanceListResponse({
    required this.success,
    required this.message,
    required this.attendances,
    required this.totalCount,
  });

  factory AttendanceListResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceListResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      attendances: (json['Attendances'] as List<dynamic>?)
              ?.map((attendance) => AttendanceData.fromJson(attendance))
              .toList() ??
          [],
      totalCount: json['TotalCount'] ?? 0,
    );
  }
}

class AttendanceStatsResponse {
  final bool success;
  final String message;
  final AttendanceStats? stats;

  AttendanceStatsResponse({
    required this.success,
    required this.message,
    this.stats,
  });

  factory AttendanceStatsResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      stats: json['Stats'] != null
          ? AttendanceStats.fromJson(json['Stats'])
          : null,
    );
  }
}

class AttendanceStats {
  final String employeeNumber;
  final String? employeeName;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final Duration? totalHours;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final String status; // "Present", "Absent", "Late", "Early"
  final String? location;
  final double? temperature;

  AttendanceStats({
    required this.employeeNumber,
    this.employeeName,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.totalHours,
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    required this.status,
    this.location,
    this.temperature,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      employeeNumber: json['EmployeeNumber'] ?? '',
      employeeName: json['EmployeeName'],
      date: DateTime.parse(json['Date']),
      checkInTime: json['CheckInTime'] != null
          ? DateTime.parse(json['CheckInTime'])
          : null,
      checkOutTime: json['CheckOutTime'] != null
          ? DateTime.parse(json['CheckOutTime'])
          : null,
      totalHours: json['TotalHours'] != null
          ? Duration(milliseconds: json['TotalHours'])
          : null,
      hasCheckedIn: json['HasCheckedIn'] ?? false,
      hasCheckedOut: json['HasCheckedOut'] ?? false,
      status: json['Status'] ?? '',
      location: json['Location'],
      temperature: json['Temperature']?.toDouble(),
    );
  }
}

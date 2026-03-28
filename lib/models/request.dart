import 'dart:convert';
import 'dart:typed_data';

enum RequestType {
  leave,
  overtime,
  sick,
  vacation,
  other,
  loan,
}

enum RequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class EmployeeRequest {
  final String id;
  final String requestNumber;
  final String employeeId;
  final String employeeName;
  final RequestType type;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final RequestStatus status;
  final String priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final List<String> attachments;
  final String? employeeNumber;

  EmployeeRequest({
    required this.id,
    required this.requestNumber,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.rejectionReason,
    this.attachments = const [],
    this.employeeNumber,
  });

  factory EmployeeRequest.fromJson(Map<String, dynamic> json) {
    return EmployeeRequest(
      id: json['id'],
      requestNumber: json['requestNumber'] ?? '',
      employeeId: json['employeeId'],
      employeeName: json['employeeName'] ?? '',
      type: RequestType.values.firstWhere(
        (e) => e.toString() == 'RequestType.${json['type']}',
      ),
      title: json['title'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: RequestStatus.values.firstWhere(
        (e) => e.toString() == 'RequestStatus.${json['status']}',
      ),
      priority: json['priority'] ?? 'Normal',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      approvedBy: json['approvedBy'],
      rejectionReason: json['rejectionReason'],
      attachments: List<String>.from(json['attachments'] ?? []),
      employeeNumber: json['employeeNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestNumber': requestNumber,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'attachments': attachments,
      'employeeNumber': employeeNumber,
    };
  }
}

// نموذج إنشاء طلب سلفة
class LoanRequestCreateModel {
  final String requestType;
  final int employeeID;
  final String employeeName;
  final String loanType;
  final double loanAmount;
  final double monthlyInstallment;
  final int numberOfInstallments;
  final DateTime loanStartDate;
  final DateTime loanEndDate;
  final String? loanDescription;
  final String? attachmentFileName;
  final Uint8List? attachmentContent;
  final int? createdBy;

  LoanRequestCreateModel({
    required this.requestType,
    required this.employeeID,
    required this.employeeName,
    required this.loanType,
    required this.loanAmount,
    required this.monthlyInstallment,
    required this.numberOfInstallments,
    required this.loanStartDate,
    required this.loanEndDate,
    this.loanDescription,
    this.attachmentFileName,
    this.attachmentContent,
    this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'RequestType': requestType,
      'EmployeeID': employeeID,
      'EmployeeName': employeeName,
      'LoanType': loanType,
      'LoanAmount': loanAmount,
      'MonthlyInstallment': monthlyInstallment,
      'NumberOfInstallments': numberOfInstallments,
      'LoanStartDateString': loanStartDate.toIso8601String(),
      'LoanEndDateString': loanEndDate.toIso8601String(),
      'LoanDescription': loanDescription,
      'AttachmentFileName': attachmentFileName,
      'AttachmentContent':
          attachmentContent != null ? base64Encode(attachmentContent!) : null,
      'CreatedBy': createdBy,
    };
  }
}

// نموذج إنشاء طلب إجازة
class LeaveRequestCreateModel {
  final String requestType;
  final int employeeID;
  final String employeeName;
  final int leaveTypeID;
  final String leaveTypeName;
  final DateTime leaveStartDate;
  final DateTime leaveEndDate;
  final int leaveDays;
  final String leaveReason;
  final String? attachmentFileName;
  final Uint8List? attachmentContent;
  final int? createdBy;

  LeaveRequestCreateModel({
    required this.requestType,
    required this.employeeID,
    required this.employeeName,
    required this.leaveTypeID,
    required this.leaveTypeName,
    required this.leaveStartDate,
    required this.leaveEndDate,
    required this.leaveDays,
    required this.leaveReason,
    this.attachmentFileName,
    this.attachmentContent,
    this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'RequestType': requestType,
      'EmployeeID': employeeID,
      'EmployeeName': employeeName,
      'LeaveTypeID': leaveTypeID,
      'LeaveTypeName': leaveTypeName,
      'LeaveStartDateString': leaveStartDate.toIso8601String(),
      'LeaveEndDateString': leaveEndDate.toIso8601String(),
      'LeaveDays': leaveDays,
      'LeaveReason': leaveReason,
      'AttachmentFileName': attachmentFileName,
      'AttachmentContent':
          attachmentContent != null ? base64Encode(attachmentContent!) : null,
      'CreatedBy': createdBy,
    };
  }
}

// نموذج إنشاء طلب من نوع "أخرى"
class OtherRequestCreateModel {
  final String requestType;
  final int employeeID;
  final String employeeName;
  final String otherDescription;
  final String? attachmentFileName;
  final Uint8List? attachmentContent;
  final int? createdBy;

  OtherRequestCreateModel({
    required this.requestType,
    required this.employeeID,
    required this.employeeName,
    required this.otherDescription,
    this.attachmentFileName,
    this.attachmentContent,
    this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'RequestType': requestType,
      'EmployeeID': employeeID,
      'EmployeeName': employeeName,
      'OtherDescription': otherDescription,
      'AttachmentFileName': attachmentFileName,
      'AttachmentContent':
          attachmentContent != null ? base64Encode(attachmentContent!) : null,
      'CreatedBy': createdBy,
    };
  }
}

// نموذج إنشاء طلب إضافة بصمة
class ManualPunchRequestCreateModel {
  final String requestType;
  final int employeeID;
  final String employeeName;
  final String manualPunchDateString;
  final String manualPunchTimeString;
  final String manualPunchType; // "in" أو "out"
  final String manualPunchReason;
  final String? attachmentFileName;
  final Uint8List? attachmentContent;
  final int? createdBy;

  ManualPunchRequestCreateModel({
    required this.requestType,
    required this.employeeID,
    required this.employeeName,
    required this.manualPunchDateString,
    required this.manualPunchTimeString,
    required this.manualPunchType,
    required this.manualPunchReason,
    this.attachmentFileName,
    this.attachmentContent,
    this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'RequestType': requestType,
      'EmployeeID': employeeID,
      'EmployeeName': employeeName,
      'ManualPunchDateString': manualPunchDateString,
      'ManualPunchTimeString': manualPunchTimeString,
      'ManualPunchType': manualPunchType,
      'ManualPunchReason': manualPunchReason,
      'AttachmentFileName': attachmentFileName,
      'AttachmentContent':
          attachmentContent != null ? base64Encode(attachmentContent!) : null,
      'CreatedBy': createdBy,
    };
  }
}

// نموذج استجابة إنشاء الطلب
class RequestCreateResponse {
  final bool success;
  final String message;
  final int? requestId;

  RequestCreateResponse({
    required this.success,
    required this.message,
    this.requestId,
  });

  factory RequestCreateResponse.fromJson(Map<String, dynamic> json) {
    return RequestCreateResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      requestId: json['RequestId'],
    );
  }
}

// نموذج نوع السلفة
class LoanType {
  final String value;
  final String text;

  LoanType({
    required this.value,
    required this.text,
  });

  factory LoanType.fromJson(Map<String, dynamic> json) {
    return LoanType(
      value: json['Value'] ?? '',
      text: json['Text'] ?? '',
    );
  }
}

// نموذج نوع الإجازة
class LeaveType {
  final int value;
  final String text;

  LeaveType({
    required this.value,
    required this.text,
  });

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      value: json['Value'] ?? 0,
      text: json['Text'] ?? '',
    );
  }
}

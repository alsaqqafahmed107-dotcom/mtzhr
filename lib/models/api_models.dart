class EmployeeLoginRequest {
  final String email;
  final String password;
  final bool rememberMe;

  EmployeeLoginRequest({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'rememberMe': rememberMe,
    };
  }
}

class EmployeeLoginResponse {
  final bool success;
  final String message;
  final EmployeeData? employee;

  EmployeeLoginResponse({
    required this.success,
    required this.message,
    this.employee,
  });

  factory EmployeeLoginResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeLoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      employee: json['employee'] != null
          ? EmployeeData.fromJson(json['employee'])
          : null,
    );
  }
}

class EmployeeData {
  final int employeeID;
  final String employeeNumber;
  final String name;
  final String email;
  final String rules;
  final int clientID;
  final String databaseName;
  final String clientName;

  EmployeeData({
    required this.employeeID,
    required this.employeeNumber,
    required this.name,
    required this.email,
    required this.rules,
    required this.clientID,
    required this.databaseName,
    required this.clientName,
  });

  factory EmployeeData.fromJson(Map<String, dynamic> json) {
    return EmployeeData(
      employeeID: json['employeeID'] ?? 0,
      employeeNumber: json['employeeNumber'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      rules: json['rules'] ?? '',
      clientID: json['clientID'] ?? 0,
      databaseName: json['databaseName'] ?? '',
      clientName: json['clientName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeID': employeeID,
      'employeeNumber': employeeNumber,
      'name': name,
      'email': email,
      'rules': rules,
      'clientID': clientID,
      'databaseName': databaseName,
      'clientName': clientName,
    };
  }
}

class LogoutResponse {
  final bool success;
  final String message;

  LogoutResponse({
    required this.success,
    required this.message,
  });

  factory LogoutResponse.fromJson(Map<String, dynamic> json) {
    return LogoutResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

// أنواع الطلبات
class RequestType {
  final String value;
  final String text;
  final int requestTypeID;

  RequestType({
    required this.value,
    required this.text,
    required this.requestTypeID,
  });

  factory RequestType.fromJson(Map<String, dynamic> json) {
    return RequestType(
      value: json['Value'] ?? '',
      text: json['Text'] ?? '',
      requestTypeID: json['RequestTypeID'] ?? 0,
    );
  }
}

// خطوة في المسار
class WorkflowStep {
  final int stepOrder;
  final String stepName;
  final String approverType;
  final String approverName;
  final String actualApproverName;

  WorkflowStep({
    required this.stepOrder,
    required this.stepName,
    required this.approverType,
    required this.approverName,
    required this.actualApproverName,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      stepOrder: json['StepOrder'] ?? 0,
      stepName: json['StepName'] ?? '',
      approverType: json['ApproverType'] ?? '',
      approverName: json['ApproverName'] ?? '',
      actualApproverName: json['ActualApproverName'] ?? '',
    );
  }
}

// بيانات المسار
class WorkflowData {
  final int workflowID;
  final String workflowName;
  final List<WorkflowStep> steps;

  WorkflowData({
    required this.workflowID,
    required this.workflowName,
    required this.steps,
  });

  factory WorkflowData.fromJson(Map<String, dynamic> json) {
    return WorkflowData(
      workflowID: json['WorkflowID'] ?? 0,
      workflowName: json['WorkflowName'] ?? '',
      steps: (json['Steps'] as List<dynamic>?)
              ?.map((step) => WorkflowStep.fromJson(step))
              .toList() ??
          [],
    );
  }
}

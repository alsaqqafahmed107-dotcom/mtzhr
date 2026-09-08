class UserTaskAttachment {
  final int attachmentId;
  final String fileName;
  final String? contentType;
  final String? fileType;
  final int fileSize;
  final String? createdDate;
  final String? downloadUrl;

  const UserTaskAttachment({
    required this.attachmentId,
    required this.fileName,
    this.contentType,
    this.fileType,
    required this.fileSize,
    this.createdDate,
    this.downloadUrl,
  });

  factory UserTaskAttachment.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return UserTaskAttachment(
      attachmentId: toInt(json['AttachmentID'] ?? json['attachmentId']),
      fileName: (json['FileName'] ?? json['fileName'] ?? '') as String,
      contentType: json['ContentType']?.toString(),
      fileType: json['FileType']?.toString(),
      fileSize: toInt(json['FileSize']),
      createdDate: json['CreatedDate']?.toString(),
      downloadUrl: json['DownloadUrl']?.toString(),
    );
  }
}

class UserTask {
  final int taskId;
  final int? assignedEmployeeId;
  final String? employeeName;
  final String title;
  final String? description;
  final String? dueDateTime;
  final String status;
  final String? completedDate;
  final int attachmentsCount;
  final List<UserTaskAttachment> attachments;

  const UserTask({
    required this.taskId,
    required this.assignedEmployeeId,
    required this.employeeName,
    required this.title,
    required this.description,
    required this.dueDateTime,
    required this.status,
    required this.completedDate,
    required this.attachmentsCount,
    required this.attachments,
  });

  factory UserTask.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final attachmentsJson = (json['Attachments'] as List?) ?? const [];
    return UserTask(
      taskId: toInt(json['TaskID']),
      assignedEmployeeId: json['AssignedEmployeeID'] == null
          ? null
          : toInt(json['AssignedEmployeeID']),
      employeeName: json['EmployeeName']?.toString(),
      title: (json['Title'] ?? '') as String,
      description: json['Description']?.toString(),
      dueDateTime: json['DueDateTime']?.toString(),
      status: (json['Status'] ?? 'Pending') as String,
      completedDate: json['CompletedDate']?.toString(),
      attachmentsCount: toInt(json['AttachmentsCount']),
      attachments: attachmentsJson
          .whereType<Map<String, dynamic>>()
          .map(UserTaskAttachment.fromJson)
          .toList(),
    );
  }
}

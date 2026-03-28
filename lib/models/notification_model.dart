class NotificationModel {
  final int id;
  final String? type;
  final String title;
  final String message;
  final int? requestId;
  final String? requestType;
  final String? relatedLink;
  final bool isRead;
  final String createdDate;
  final String? readAt;
  final String? createdBy;
  final String? metadata;

  NotificationModel({
    required this.id,
    this.type,
    required this.title,
    required this.message,
    this.requestId,
    this.requestType,
    this.relatedLink,
    required this.isRead,
    required this.createdDate,
    this.readAt,
    this.createdBy,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['NotificationID'] ?? 0,
      type: json['Type'] ?? json['type'],
      title: json['Title'] ?? '',
      message: json['Message'] ?? '',
      requestId: json['RequestID'],
      requestType: json['RequestType'],
      relatedLink: json['RelatedLink'] ?? json['related_link'],
      isRead: json['IsRead'] ?? false,
      createdDate: json['CreatedDate'] ?? '',
      readAt: json['ReadAt'] ?? json['read_at'],
      createdBy: json['CreatedBy'] ?? json['created_by'],
      metadata: json['Metadata'] ?? json['metadata'],
    );
  }
}
